//go:build linux

// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package host

import (
	"context"
	"os"
	"path/filepath"
	"testing"
)

func TestPinnedRunnerAndPluginSurvivePathReplacement(t *testing.T) {
	dir := t.TempDir()
	runnerPath := filepath.Join(dir, "runner")
	pluginPath := filepath.Join(dir, "plugin")
	if err := writeRunnerFixture(runnerPath); err != nil {
		t.Fatal(err)
	}
	executableFixture(t, pluginPath, "verified")
	plugin, _, err := openBinary(pluginPath)
	if err != nil {
		t.Fatal(err)
	}
	defer plugin.Close()
	cmd, closeCommand, err := containedCommand(context.Background(), runnerPath, plugin, dir)
	if err != nil {
		t.Fatal(err)
	}
	defer closeCommand()
	replaceExecutable(t, runnerPath, "replacement-runner")
	replaceExecutable(t, pluginPath, "replacement-plugin")
	out, err := cmd.Output()
	if err != nil || string(out) != "verified" {
		t.Fatal("verified runner/plugin inodes were not executed", string(out), err)
	}
}

func writeRunnerFixture(path string) error {
	return os.WriteFile(path, []byte("#!/bin/sh\nexec \"$1\"\n"), 0700)
}
