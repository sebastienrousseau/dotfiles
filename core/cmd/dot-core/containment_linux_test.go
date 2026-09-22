//go:build linux

// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package main

import (
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestContainedCommandLifecycle(t *testing.T) {
	parent := t.TempDir()
	core, plugin := filepath.Join(parent, "dot-core"), filepath.Join(parent, "dot-hello")
	runner := filepath.Join(parent, "dot-sandbox")
	for output, source := range map[string]string{core: ".", plugin: "../dot-hello", runner: "../dot-sandbox"} {
		if b, err := exec.Command("go", "build", "-o", output, source).CombinedOutput(); err != nil {
			t.Fatalf("build %s: %s %v", source, b, err)
		}
	}
	root := filepath.Join(parent, "managed")
	command := func(args ...string) string {
		t.Helper()
		b, err := exec.Command(core, args...).CombinedOutput()
		if err != nil {
			t.Fatalf("%s: %s %v", strings.Join(args, " "), b, err)
		}
		return strings.TrimSpace(string(b))
	}
	command("init", "--root", root)
	command("register", "--root", root, "--plugin", plugin, "--assurance", "process")
	command("apply", "--root", root, "--require-process-sandbox")
	if state := command("status", "--root", root); state != "COMMITTED" {
		t.Fatal("unexpected state", state)
	}
}
