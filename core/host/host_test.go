//go:build darwin || linux

// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package host

import (
	"context"
	"dotfiles.local/core/transaction"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
)

func TestLifecycle(t *testing.T) {
	bin := filepath.Join(t.TempDir(), "hello")
	cmd := exec.Command("go", "build", "-o", bin, "../cmd/dot-hello")
	if b, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("build: %s %v", b, err)
	}
	for _, kind := range []string{"success", "no-consent", "changed-executable", "stdout-noise", "nonzero", "environment", "timeout"} {
		t.Run(kind, func(t *testing.T) {
			root := filepath.Join(t.TempDir(), "demo")
			if err := transaction.Init(root); err != nil {
				t.Fatal(err)
			}
			e, err := transaction.Open(root)
			if err != nil {
				t.Fatal(err)
			}
			defer e.Close()
			source := bin
			if kind == "stdout-noise" {
				source = filepath.Join(t.TempDir(), "bad")
				os.WriteFile(source, []byte("#!/bin/sh\necho debug\n"), 0700)
			}
			if kind == "nonzero" || kind == "environment" || kind == "timeout" {
				source = filepath.Join(t.TempDir(), "fixture")
				body := "#!/bin/sh\nexit 23\n"
				if kind == "timeout" {
					body = "#!/bin/sh\nexec /bin/sleep 20\n"
				}
				if kind == "environment" {
					t.Setenv("DOT_TEST_SECRET_CANARY", "must-not-inherit")
					body = "#!/bin/sh\n[ -z \"${DOT_TEST_SECRET_CANARY:-}\" ] || exit 24\nexec '" + bin + "'\n"
				}
				if err := os.WriteFile(source, []byte(body), 0700); err != nil {
					t.Fatal(err)
				}
			}
			if err = Register(e, source); err != nil {
				t.Fatal(err)
			}
			if kind == "changed-executable" {
				os.Chmod(filepath.Join(root, ".dot-plugin"), 0700)
				os.WriteFile(filepath.Join(root, ".dot-plugin"), []byte("changed"), 0700)
			}
			err = Apply(context.Background(), e, kind != "no-consent")
			if kind != "success" && kind != "environment" {
				if err == nil {
					t.Fatal("unsafe plugin accepted")
				}
				if _, err = os.Stat(filepath.Join(root, "hello.txt")); !os.IsNotExist(err) {
					t.Fatal("production mutated")
				}
				return
			}
			if err != nil {
				t.Fatal(err)
			}
			state, err := e.Status()
			if err != nil || state != "COMMITTED" {
				t.Fatal(state, err)
			}
			if err = e.Recover(true); err != nil {
				t.Fatal(err)
			}
		})
	}
}
