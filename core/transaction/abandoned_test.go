//go:build darwin || linux

// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package transaction

import (
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

func addAbandonedStage(t *testing.T, e *Engine) {
	t.Helper()
	if err := e.Root.Mkdir(".dot-stage", 0700); err != nil {
		t.Fatal(err)
	}
	r, err := privateRoot(e.Root, ".dot-stage")
	if err != nil {
		t.Fatal(err)
	}
	defer r.Close()
	if err = write(r, "hello.txt", []byte("staged\n"), 0600); err != nil {
		t.Fatal(err)
	}
}

func abandonPrepare(t *testing.T, point string) *Engine {
	t.Helper()
	e, p, data := setup(t)
	addAbandonedStage(t, e)
	e.Fault = func(where string) error {
		if where == point {
			return errors.New("power loss before durable prepare")
		}
		return nil
	}
	if _, err := e.Prepare(p, data); err == nil {
		t.Fatal("fault not reached")
	}
	e.Fault = nil
	return e
}

func TestDiscardAbandonedPrepareBoundaries(t *testing.T) {
	for _, point := range []string{"prepare-created", "prepare-artifact-0", "prepare-artifact-1", "prepare-sealed"} {
		t.Run(point, func(t *testing.T) {
			e := abandonPrepare(t, point)
			if state, err := e.Status(); err != nil || state != "ABANDONED" {
				t.Fatal(state, err)
			}
			if err := os.WriteFile(filepath.Join(e.Root.Name(), "hello.txt"), []byte("user edit\n"), 0600); err != nil {
				t.Fatal(err)
			}
			if err := e.DiscardAbandoned(); err != nil {
				t.Fatal(err)
			}
			if err := e.DiscardAbandoned(); err != nil {
				t.Fatal("discard is not idempotent", err)
			}
			if state, err := e.Status(); err != nil || state != "IDLE" {
				t.Fatal(state, err)
			}
			got, err := os.ReadFile(filepath.Join(e.Root.Name(), "hello.txt"))
			if err != nil || string(got) != "user edit\n" {
				t.Fatal("managed target changed", string(got), err)
			}
			for _, name := range []string{".dot-stage", ".dot-txn"} {
				if _, err = e.Root.Lstat(name); !os.IsNotExist(err) {
					t.Fatal("abandoned directory retained", name, err)
				}
			}
		})
	}
}

func TestDiscardAbandonedStageOnly(t *testing.T) {
	e, _, _ := setup(t)
	addAbandonedStage(t, e)
	if state, err := e.Status(); err != nil || state != "ABANDONED" {
		t.Fatal(state, err)
	}
	if err := e.DiscardAbandoned(); err != nil {
		t.Fatal(err)
	}
	if err := e.Ready(); err != nil {
		t.Fatal(err)
	}
}

func TestDiscardAbandonedPartialJournal(t *testing.T) {
	e, _, _ := setup(t)
	if err := e.Root.Mkdir(".dot-txn", 0700); err != nil {
		t.Fatal(err)
	}
	if err := write(e.Root, ".dot-txn/wal", []byte(`{"state":"PREP`), 0600); err != nil {
		t.Fatal(err)
	}
	if state, err := e.Status(); err != nil || state != "ABANDONED" {
		t.Fatal(state, err)
	}
	if err := e.DiscardAbandoned(); err != nil {
		t.Fatal(err)
	}
	if state, err := e.Status(); err != nil || state != "IDLE" {
		t.Fatal(state, err)
	}
	restored(t, e)
}

func TestDiscardAbandonedResumesAfterEveryBoundary(t *testing.T) {
	for _, point := range []string{"discard-stage-entries", "discard-stage", "discard-transaction-entries", "discard-transaction"} {
		t.Run(point, func(t *testing.T) {
			e := abandonPrepare(t, "prepare-sealed")
			e.Fault = func(where string) error {
				if where == point {
					return errors.New("power loss during discard")
				}
				return nil
			}
			if err := e.DiscardAbandoned(); err == nil {
				t.Fatal("fault not reached")
			}
			e.Fault = nil
			if err := e.DiscardAbandoned(); err != nil {
				t.Fatal("discard did not resume", err)
			}
			if state, err := e.Status(); err != nil || state != "IDLE" {
				t.Fatal(state, err)
			}
			restored(t, e)
		})
	}
}

func TestDiscardAbandonedProcessCrash(t *testing.T) {
	if root := os.Getenv("DOT_TEST_DISCARD_ROOT"); root != "" {
		e, err := Open(root)
		if err != nil {
			os.Exit(90)
		}
		point := os.Getenv("DOT_TEST_DISCARD_POINT")
		e.Fault = func(where string) error {
			if where == point {
				os.Exit(77)
			}
			return nil
		}
		e.DiscardAbandoned()
		os.Exit(91)
	}
	for _, point := range []string{"discard-stage-entries", "discard-stage", "discard-transaction-entries", "discard-transaction"} {
		t.Run(point, func(t *testing.T) {
			e := abandonPrepare(t, "prepare-sealed")
			root := e.Root.Name()
			e.Close()
			cmd := exec.Command(os.Args[0], "-test.run=^TestDiscardAbandonedProcessCrash$/"+point+"$")
			cmd.Env = append(os.Environ(), "DOT_TEST_DISCARD_ROOT="+root, "DOT_TEST_DISCARD_POINT="+point)
			err := cmd.Run()
			var exit *exec.ExitError
			if !errors.As(err, &exit) || exit.ExitCode() != 77 {
				t.Fatal("unexpected child result", err)
			}
			reopened, err := Open(root)
			if err != nil {
				t.Fatal(err)
			}
			defer reopened.Close()
			if err = reopened.DiscardAbandoned(); err != nil {
				t.Fatal("discard did not recover after process exit", err)
			}
			if state, err := reopened.Status(); err != nil || state != "IDLE" {
				t.Fatal(state, err)
			}
			restored(t, reopened)
		})
	}
}

func TestDiscardAbandonedPreservesRecoveryAndUnknownEvidence(t *testing.T) {
	t.Run("prepared", func(t *testing.T) {
		e, p, data := setup(t)
		addAbandonedStage(t, e)
		if _, err := e.Prepare(p, data); err != nil {
			t.Fatal(err)
		}
		if err := e.DiscardAbandoned(); err == nil {
			t.Fatal("durable PREPARED evidence discarded")
		}
		if _, err := e.Root.Lstat(".dot-txn"); err != nil {
			t.Fatal("transaction evidence lost", err)
		}
		if err := e.Recover(false); err != nil {
			t.Fatal(err)
		}
	})
	t.Run("archive-intent", func(t *testing.T) {
		e, _, _, id := terminalFixture(t, true, false)
		e.Fault = func(where string) error {
			if where == "archive-intent" {
				return errors.New("power loss during archive")
			}
			return nil
		}
		if err := e.Archive(id); err == nil {
			t.Fatal("archive fault not reached")
		}
		e.Fault = nil
		if err := e.DiscardAbandoned(); err == nil {
			t.Fatal("archive evidence discarded")
		}
		if _, err := e.Root.Lstat(".dot-archive"); err != nil {
			t.Fatal("archive intent lost", err)
		}
		if err := e.Recover(false); err != nil {
			t.Fatal(err)
		}
	})

	for _, kind := range []string{"complete-unknown-wal", "unexpected-stage", "stage-symlink", "unexpected-transaction"} {
		t.Run(kind, func(t *testing.T) {
			e, _, _ := setup(t)
			var err error
			switch kind {
			case "complete-unknown-wal":
				err = e.Root.Mkdir(".dot-txn", 0700)
				if err == nil {
					err = write(e.Root, ".dot-txn/wal", []byte("{\"state\":\"UNKNOWN\"}\n"), 0600)
				}
			case "unexpected-stage":
				err = e.Root.Mkdir(".dot-stage", 0700)
				if err == nil {
					err = write(e.Root, ".dot-stage/not-allowed", []byte("evidence"), 0600)
				}
			case "stage-symlink":
				err = e.Root.Symlink(".dot-root", ".dot-stage")
			case "unexpected-transaction":
				err = e.Root.Mkdir(".dot-txn", 0700)
				if err == nil {
					err = e.Root.Mkdir(".dot-txn/nested", 0700)
				}
			}
			if err != nil {
				t.Fatal(err)
			}
			if err = e.DiscardAbandoned(); err == nil {
				t.Fatal("unknown evidence discarded")
			}
			name := ".dot-stage"
			if kind == "complete-unknown-wal" || kind == "unexpected-transaction" {
				name = ".dot-txn"
			}
			if _, err = e.Root.Lstat(name); err != nil {
				t.Fatal("unknown evidence lost", err)
			}
		})
	}
}
