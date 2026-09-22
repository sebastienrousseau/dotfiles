//go:build darwin || linux

// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package transaction

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func terminalFixture(t *testing.T, stage, rollback bool) (*Engine, Plan, [][]byte, string) {
	t.Helper()
	e, p, data := setup(t)
	if stage {
		if err := e.Root.Mkdir(".dot-stage", 0700); err != nil {
			t.Fatal(err)
		}
		r, err := privateRoot(e.Root, ".dot-stage")
		if err != nil {
			t.Fatal(err)
		}
		defer r.Close()
		for i, o := range p.Operations {
			if err = write(r, o.Name, data[i], 0600); err != nil {
				t.Fatal(err)
			}
		}
	}
	id, err := e.Prepare(p, data)
	if err != nil {
		t.Fatal(err)
	}
	if err = e.Commit(); err != nil {
		t.Fatal(err)
	}
	if rollback {
		if err = e.Recover(true); err != nil {
			t.Fatal(err)
		}
	}
	return e, p, data, id
}

func TestArchiveGenerations(t *testing.T) {
	for _, rollback := range []bool{false, true} {
		t.Run(fmt.Sprint(rollback), func(t *testing.T) {
			e, p, data, id := terminalFixture(t, true, rollback)
			if got, err := e.PlanID(); err != nil || got != id {
				t.Fatal(got, err)
			}
			if err := e.Ready(); err == nil {
				t.Fatal("silently discarded terminal transaction")
			}
			if err := e.Archive(id); err != nil {
				t.Fatal(err)
			}
			if err := e.Archive(id); err != nil {
				t.Fatal("not idempotent", err)
			}
			if state, err := e.Status(); err != nil || state != "IDLE" {
				t.Fatal(state, err)
			}
			if _, err := os.Stat(filepath.Join(e.Root.Name(), ".dot-history", id, "stage", "hello.txt")); err != nil {
				t.Fatal("stage evidence lost", err)
			}
			p.Nonce = strings.Repeat("d", 64)
			for i, o := range p.Operations {
				var err error
				p.Operations[i].Before, err = e.Observe(o.Name)
				if err != nil {
					t.Fatal(err)
				}
			}
			second, err := e.Prepare(p, data)
			if err != nil || second == id {
				t.Fatal(second, err)
			}
			if err = e.Archive(id); err == nil {
				t.Fatal("old ID selected a new active transaction")
			}
			if err = e.Commit(); err != nil {
				t.Fatal(err)
			}
			if err = e.Archive(second); err != nil {
				t.Fatal(err)
			}
		})
	}
}

func TestArchiveCrashBoundaries(t *testing.T) {
	for _, stage := range []bool{false, true} {
		for _, rollback := range []bool{false, true} {
			for _, point := range []string{"archive-intent", "archive-stage", "archive-rename", "archive-durable", "archive-finished"} {
				t.Run(fmt.Sprintf("stage=%t/rollback=%t/%s", stage, rollback, point), func(t *testing.T) {
					e, _, _, id := terminalFixture(t, stage, rollback)
					e.Fault = func(where string) error {
						if where == point {
							return errors.New("interruption")
						}
						return nil
					}
					if err := e.Archive(id); err == nil {
						t.Fatal("fault not reached")
					}
					e.Close()
					r, err := Open(e.Root.Name())
					if err != nil {
						t.Fatal(err)
					}
					defer r.Close()
					for i := 0; i < 2; i++ {
						if err = r.Recover(false); err != nil {
							t.Fatal(err)
						}
					}
					if err = r.Ready(); err != nil {
						t.Fatal(err)
					}
					if rollback {
						restored(t, r)
					}
					if err = r.Archive(id); err != nil {
						t.Fatal("evidence not reusable", err)
					}
				})
			}
		}
	}
}

func TestArchiveRefusals(t *testing.T) {
	for _, kind := range []string{"wrong-id", "target-edit", "stage-edit", "extra-stage", "stage-symlink", "history-symlink", "history-full", "destination", "backup", "intent"} {
		t.Run(kind, func(t *testing.T) {
			e, _, _, id := terminalFixture(t, true, false)
			root := e.Root.Name()
			var err error
			switch kind {
			case "wrong-id":
				id = strings.Repeat("f", 64)
			case "target-edit":
				err = os.WriteFile(filepath.Join(root, "hello.txt"), []byte("user edit"), 0600)
			case "stage-edit":
				err = os.WriteFile(filepath.Join(root, ".dot-stage/hello.txt"), []byte("changed"), 0600)
			case "extra-stage":
				err = write(e.Root, ".dot-stage/extra.txt", []byte("extra"), 0600)
			case "stage-symlink":
				err = e.Root.Rename(".dot-stage", "original-stage")
				if err == nil {
					err = e.Root.Symlink("original-stage", ".dot-stage")
				}
			case "history-symlink":
				err = e.Root.Symlink(".dot-stage", ".dot-history")
			case "history-full", "destination":
				err = e.Root.Mkdir(".dot-history", 0700)
				if err == nil && kind == "destination" {
					err = e.Root.Mkdir(".dot-history/"+id, 0700)
				} else if err == nil {
					for i := 0; i < MaxHistory && err == nil; i++ {
						err = e.Root.Mkdir(fmt.Sprintf(".dot-history/%064x", i), 0700)
					}
				}
			case "backup":
				err = os.WriteFile(filepath.Join(root, ".dot-txn/backup-0"), []byte("changed"), 0600)
			case "intent":
				err = write(e.Root, ".dot-archive", []byte(`{"plan_id":"broken"}`), 0600)
			}
			if err != nil {
				t.Fatal(err)
			}
			if err = e.Archive(id); err == nil {
				t.Fatal("unsafe archive accepted")
			}
			if _, err = e.Root.Lstat(".dot-txn"); err != nil {
				t.Fatal("active evidence lost", err)
			}
		})
	}
}

func TestArchiveBlocksIncompleteTransaction(t *testing.T) {
	e, p, data := setup(t)
	id, err := e.Prepare(p, data)
	if err != nil {
		t.Fatal(err)
	}
	if err = e.Archive(id); err == nil {
		t.Fatal("archived PREPARED transaction")
	}
	if err = e.Recover(false); err != nil {
		t.Fatal(err)
	}
	if err = e.Archive(id); err != nil {
		t.Fatal(err)
	}
}

func TestInterruptedArchiveConflicts(t *testing.T) {
	for _, point := range []string{"archive-intent", "archive-stage", "archive-rename"} {
		t.Run(point, func(t *testing.T) {
			e, _, _, id := terminalFixture(t, true, false)
			e.Fault = func(where string) error {
				if where == point {
					return errors.New("interruption")
				}
				return nil
			}
			if err := e.Archive(id); err == nil {
				t.Fatal("fault not reached")
			}
			e.Fault = nil
			if state, err := e.Status(); err != nil || state != "ARCHIVING" {
				t.Fatal(state, err)
			}
			if e.Ready() == nil || e.Recover(true) == nil {
				t.Fatal("pending archive allowed apply/rollback")
			}
			if err := os.WriteFile(filepath.Join(e.Root.Name(), "hello.txt"), []byte("user edit"), 0600); err != nil {
				t.Fatal(err)
			}
			if err := e.Recover(false); err == nil {
				t.Fatal("concurrent edit not detected")
			}
			got, err := os.ReadFile(filepath.Join(e.Root.Name(), "hello.txt"))
			if err != nil || string(got) != "user edit" {
				t.Fatal("user edit overwritten", err)
			}
		})
	}
}

func TestArchiveProcessCrash(t *testing.T) {
	if root := os.Getenv("DOT_TEST_ARCHIVE_ROOT"); root != "" {
		e, err := Open(root)
		if err != nil {
			os.Exit(90)
		}
		id, err := e.PlanID()
		if err != nil {
			os.Exit(91)
		}
		e.Fault = func(point string) error {
			if point == "archive-rename" {
				os.Exit(77)
			}
			return nil
		}
		e.Archive(id)
		os.Exit(92)
	}
	e, _, _, _ := terminalFixture(t, true, false)
	root := e.Root.Name()
	e.Close()
	cmd := exec.Command(os.Args[0], "-test.run=^TestArchiveProcessCrash$")
	cmd.Env = append(os.Environ(), "DOT_TEST_ARCHIVE_ROOT="+root)
	err := cmd.Run()
	var exit *exec.ExitError
	if !errors.As(err, &exit) || exit.ExitCode() != 77 {
		t.Fatal(err)
	}
	r, err := Open(root)
	if err != nil {
		t.Fatal(err)
	}
	defer r.Close()
	if err = r.Recover(false); err != nil {
		t.Fatal(err)
	}
	if err = r.Ready(); err != nil {
		t.Fatal(err)
	}
}
