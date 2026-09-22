//go:build linux

// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package host

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"dotfiles.local/core/protocol"
)

func executableFixture(t *testing.T, path, output string) {
	t.Helper()
	if err := os.WriteFile(path, []byte("#!/bin/sh\nprintf '%s' '"+output+"'\n"), 0700); err != nil {
		t.Fatal(err)
	}
}

func replaceExecutable(t *testing.T, path, output string) {
	t.Helper()
	replacement := path + ".replacement"
	executableFixture(t, replacement, output)
	if err := os.Rename(replacement, path); err != nil {
		t.Fatal(err)
	}
}

func TestPinnedAuditPluginSurvivesPathReplacement(t *testing.T) {
	path := filepath.Join(t.TempDir(), "plugin")
	executableFixture(t, path, "verified")
	plugin, _, err := openBinary(path)
	if err != nil {
		t.Fatal(err)
	}
	defer plugin.Close()
	cmd, closeCommand, err := pluginCommand(context.Background(), plugin, t.TempDir(), protocol.AssuranceAudit)
	if err != nil {
		t.Fatal(err)
	}
	defer closeCommand()
	replaceExecutable(t, path, "replacement")
	out, err := cmd.Output()
	if err != nil || string(out) != "verified" {
		t.Fatal("verified inode was not executed", string(out), err)
	}
}
