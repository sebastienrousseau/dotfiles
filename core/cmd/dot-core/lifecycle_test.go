//go:build darwin || linux

// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package main

import (
	"os/exec"
	"path/filepath"
	"testing"

	"dotfiles.local/core/transaction"
)

func TestCommandLifecycle(t *testing.T) {
	parent := t.TempDir()
	root, plugin := filepath.Join(parent, "demo"), filepath.Join(parent, "hello")
	if b, err := exec.Command("go", "build", "-o", plugin, "../dot-hello").CombinedOutput(); err != nil {
		t.Fatalf("build: %s %v", b, err)
	}
	command := func(name string, extra ...string) {
		t.Helper()
		if err := run(append([]string{name, "--root", root}, extra...)); err != nil {
			t.Fatalf("%s: %v", name, err)
		}
	}
	command("init")
	command("register", "--plugin", plugin)
	for i := 0; i < 2; i++ {
		command("apply", "--allow-audit-plugin")
		command("status")
		command("retry-effects")
		command("plan-id")
		command("recover")
		if i == 0 {
			command("rollback")
		}
		e, err := transaction.Open(root)
		if err != nil {
			t.Fatal(err)
		}
		id, err := e.PlanID()
		e.Close()
		if err != nil {
			t.Fatal(err)
		}
		command("archive", "--plan-id", id)
		command("status")
		command("recover")
	}
}
