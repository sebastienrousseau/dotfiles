//go:build darwin || linux

// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package transaction

import (
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func setup(t *testing.T) (*Engine, Plan, [][]byte) {
	t.Helper()
	path := filepath.Join(t.TempDir(), "managed")
	if err := Init(path); err != nil {
		t.Fatal(err)
	}
	e, err := Open(path)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(e.Close)
	if err = write(e.Root, "hello.txt", []byte("old\n"), 0600); err != nil {
		t.Fatal(err)
	}
	p := Plan{Version: 1, RootID: e.ID, Nonce: strings.Repeat("a", 64), PluginDigest: strings.Repeat("b", 64), ProposalID: strings.Repeat("c", 64)}
	data := [][]byte{[]byte("new\n"), []byte("welcome\n")}
	initial, err := e.Observe("hello.txt")
	if err != nil {
		t.Fatal(err)
	}
	for i, name := range []string{"hello.txt", "welcome.txt"} {
		before, err := e.Observe(name)
		if err != nil {
			t.Fatal(err)
		}
		p.Operations = append(p.Operations, Operation{Name: name, Before: before, After: Snapshot{true, Digest(data[i]), 0600, initial.UID, initial.GID}})
	}
	return e, p, data
}
func restored(t *testing.T, e *Engine) {
	t.Helper()
	b, s, err := read(e.Root, "hello.txt")
	if err != nil || string(b) != "old\n" || s.Mode != 0600 {
		t.Fatalf("old state lost: %q %v", b, err)
	}
	_, s, err = read(e.Root, "welcome.txt")
	if err != nil || s.Exists {
		t.Fatalf("created target not removed: %v", err)
	}
}

func TestCommitRollback(t *testing.T) {
	e, p, b := setup(t)
	if _, err := e.Prepare(p, b); err != nil {
		t.Fatal(err)
	}
	if err := e.Commit(); err != nil {
		t.Fatal(err)
	}
	s, err := e.Status()
	if err != nil || s != "COMMITTED" {
		t.Fatal(s, err)
	}
	if err = e.Recover(false); err != nil {
		t.Fatal(err)
	}
	if err = e.Recover(true); err != nil {
		t.Fatal(err)
	}
	restored(t, e)
	if err = e.Recover(true); err != nil {
		t.Fatal(err)
	}
}

func TestCrossRootPlanRejected(t *testing.T) {
	e, p, b := setup(t)
	other, _, _ := setup(t)
	p.RootID = other.ID
	if _, err := e.Prepare(p, b); err == nil {
		t.Fatal("accepted a plan bound to another root")
	}
	restored(t, e)
}

func TestModePolicy(t *testing.T) {
	for _, mode := range []os.FileMode{0500, os.ModeSetuid | 0600, os.ModeSetgid | 0600, os.ModeSticky | 0600, 0300} {
		t.Run(mode.String(), func(t *testing.T) {
			e, p, data := setup(t)
			if err := e.Root.Chmod("hello.txt", mode); err != nil {
				if errors.Is(err, os.ErrPermission) && mode&(os.ModeSetuid|os.ModeSetgid) != 0 {
					t.Skip("filesystem already refuses privilege bits")
				}
				t.Fatal(err)
			}
			s, err := e.Observe("hello.txt")
			if mode != 0500 {
				if err == nil {
					t.Fatal("unsafe file mode accepted")
				}
				return
			}
			if err != nil {
				t.Fatal(err)
			}
			p.Operations[0].Before = s
			if _, err = e.Prepare(p, data); err != nil {
				t.Fatal(err)
			}
		})
	}
}

func TestCrashBoundaries(t *testing.T) {
	for _, point := range []string{"prepared", "committing", "flushed-0", "renamed-0", "flushed-1", "renamed-1", "committed"} {
		t.Run(point, func(t *testing.T) {
			e, p, b := setup(t)
			e.Fault = func(where string) error {
				if where == point {
					return errors.New("power-loss simulation")
				}
				return nil
			}
			_, err := e.Prepare(p, b)
			if err == nil {
				err = e.Commit()
			}
			if err == nil {
				t.Fatal("fault not reached")
			}
			e.Fault = nil
			e.Close()
			reopened, err := Open(e.Root.Name())
			if err != nil {
				t.Fatal(err)
			}
			defer reopened.Close()
			if err = reopened.Recover(false); err != nil {
				t.Fatal(err)
			}
			if point == "committed" {
				state, _ := reopened.Status()
				if state != "COMMITTED" {
					t.Fatal(state)
				}
			} else {
				restored(t, reopened)
			}
		})
	}
}

func TestConflictAndTamper(t *testing.T) {
	for _, kind := range []string{"precondition", "artifact", "plan", "symlink", "hardlink", "mode", "disk-full"} {
		t.Run(kind, func(t *testing.T) {
			e, p, b := setup(t)
			if _, err := e.Prepare(p, b); err != nil {
				t.Fatal(err)
			}
			switch kind {
			case "precondition":
				os.WriteFile(filepath.Join(e.Root.Name(), "hello.txt"), []byte("user edit"), 0600)
			case "artifact":
				os.WriteFile(filepath.Join(e.Root.Name(), ".dot-txn/artifact-0"), []byte("tampered"), 0600)
			case "plan":
				os.WriteFile(filepath.Join(e.Root.Name(), ".dot-txn/plan.json"), []byte(`{}`), 0600)
			case "symlink":
				e.Root.Remove("hello.txt")
				e.Root.Symlink(".dot-root", "hello.txt")
			case "hardlink":
				e.Root.Link("hello.txt", "extra")
			case "mode":
				e.Root.Chmod("hello.txt", 0644)
			case "disk-full":
				e.Fault = func(point string) error {
					if point == "flushed-0" {
						return errors.New("ENOSPC")
					}
					return nil
				}
			}
			if err := e.Commit(); err == nil {
				t.Fatal("unsafe commit succeeded")
			}
		})
	}
}

func TestRecoveryPreservesConcurrentEdit(t *testing.T) {
	e, p, b := setup(t)
	e.Prepare(p, b)
	e.Fault = func(s string) error {
		if s == "renamed-0" {
			return errors.New("crash")
		}
		return nil
	}
	e.Commit()
	e.Fault = nil
	os.WriteFile(filepath.Join(e.Root.Name(), "hello.txt"), []byte("user edit"), 0600)
	if err := e.Recover(false); err == nil {
		t.Fatal("overwrote user change")
	}
	data, _, _ := read(e.Root, "hello.txt")
	if string(data) != "user edit" {
		t.Fatal("lost edit")
	}
}

func TestRollbackCrashAndTruncatedWAL(t *testing.T) {
	e, p, b := setup(t)
	e.Prepare(p, b)
	if err := e.Commit(); err != nil {
		t.Fatal(err)
	}
	e.Fault = func(s string) error {
		if s == "restored-1" {
			return errors.New("crash")
		}
		return nil
	}
	if err := e.Recover(true); err == nil {
		t.Fatal("expected interruption")
	}
	e.Fault = nil
	f, err := e.Root.OpenFile(".dot-txn/wal", os.O_APPEND|os.O_WRONLY, 0600)
	if err != nil {
		t.Fatal(err)
	}
	f.WriteString(`{"sta`)
	f.Close()
	if err = e.Recover(false); err != nil {
		t.Fatal(err)
	}
	restored(t, e)
	if _, err = e.Status(); err != nil {
		t.Fatal(err)
	}
}

func TestPolicy(t *testing.T) {
	e, p, b := setup(t)
	if other, err := Open(e.Root.Name()); err == nil {
		other.Close()
		t.Fatal("concurrent lock")
	}
	for _, name := range []string{"../escape", "/absolute", "a/b.txt", ".dot-root", "hello.txt/child"} {
		p.Operations[0].Name = name
		if _, err := e.Prepare(p, b); err == nil {
			t.Fatal(name)
		}
	}
	if err := Init(e.Root.Name()); err == nil {
		t.Fatal("reused existing directory")
	}
}

func TestCanonicalProfile(t *testing.T) {
	b, err := Canonical(map[string]any{"z": "<>&", "a": uint64(42)})
	if err != nil || string(b) != `{"a":42,"z":"<>&"}` {
		t.Fatal(string(b), err)
	}
	for _, v := range []any{1.2, -1, "\u2028", uint64(1 << 53)} {
		if _, err := Canonical(v); err == nil {
			t.Fatalf("accepted %v", v)
		}
	}
}

// A real process exit, not just a returned error, proves no deferred cleanup is required.
func TestProcessCrash(t *testing.T) {
	if root := os.Getenv("DOT_TEST_CRASH_ROOT"); root != "" {
		e, err := Open(root)
		if err != nil {
			os.Exit(90)
		}
		e.Fault = func(p string) error {
			if p == "renamed-0" {
				os.Exit(77)
			}
			return nil
		}
		e.Commit()
		os.Exit(91)
	}
	e, p, b := setup(t)
	if _, err := e.Prepare(p, b); err != nil {
		t.Fatal(err)
	}
	root := e.Root.Name()
	e.Close()
	cmd := exec.Command(os.Args[0], "-test.run=^TestProcessCrash$")
	cmd.Env = append(os.Environ(), "DOT_TEST_CRASH_ROOT="+root)
	err := cmd.Run()
	var exit *exec.ExitError
	if !errors.As(err, &exit) || exit.ExitCode() != 77 {
		t.Fatalf("crash helper: %v", err)
	}
	r, err := Open(root)
	if err != nil {
		t.Fatal(err)
	}
	defer r.Close()
	if err = r.Recover(false); err != nil {
		t.Fatal(err)
	}
	restored(t, r)
}
