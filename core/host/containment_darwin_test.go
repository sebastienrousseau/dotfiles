//go:build darwin

// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package host

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"

	"dotfiles.local/core/protocol"
	"dotfiles.local/core/transaction"
)

func TestProcessAssuranceFailsClosedOnDarwin(t *testing.T) {
	plugin := filepath.Join(t.TempDir(), "hello")
	if b, err := exec.Command("go", "build", "-o", plugin, "../cmd/dot-hello").CombinedOutput(); err != nil {
		t.Fatalf("build: %s %v", b, err)
	}
	root := filepath.Join(t.TempDir(), "demo")
	if err := transaction.Init(root); err != nil {
		t.Fatal(err)
	}
	e, err := transaction.Open(root)
	if err != nil {
		t.Fatal(err)
	}
	defer e.Close()
	if err = RegisterWithAssurance(e, plugin, protocol.AssuranceProcess); err != nil {
		t.Fatal(err)
	}
	if err = ApplyContained(context.Background(), e); err == nil || !strings.Contains(err.Error(), "DOT_E_SANDBOX_UNAVAILABLE") {
		t.Fatal("process assurance did not fail closed", err)
	}
	if _, err = os.Stat(filepath.Join(root, "hello.txt")); !os.IsNotExist(err) {
		t.Fatal("failed containment mutated production", err)
	}
}
