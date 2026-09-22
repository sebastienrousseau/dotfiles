//go:build linux

// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package sandbox

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestLinuxContainment(t *testing.T) {
	parent := t.TempDir()
	stage := filepath.Join(parent, "stage")
	if err := os.Mkdir(stage, 0700); err != nil {
		t.Fatal(err)
	}
	outside := filepath.Join(parent, "outside")
	if err := os.WriteFile(outside, []byte("original\n"), 0600); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(stage, "outside-path"), []byte(outside+"\n"), 0600); err != nil {
		t.Fatal(err)
	}
	probe := filepath.Join(parent, "probe")
	runner := filepath.Join(parent, "dot-sandbox")
	for output, source := range map[string]string{probe: "./testdata/probe", runner: "../cmd/dot-sandbox"} {
		build := exec.Command("go", "build", "-o", output, source)
		build.Env = append(os.Environ(), "CGO_ENABLED=0")
		if b, err := build.CombinedOutput(); err != nil {
			t.Fatalf("build %s: %s %v", source, b, err)
		}
	}
	cmd := exec.Command(runner, probe, stage)
	cmd.Env = []string{"LANG=C", "DOT_STAGE_ROOT=" + stage}
	if b, err := cmd.CombinedOutput(); err != nil || strings.TrimSpace(string(b)) != "contained" {
		t.Fatalf("sandbox: %s %v", b, err)
	}
	if b, err := os.ReadFile(outside); err != nil || string(b) != "original\n" {
		t.Fatal("outside target changed", string(b), err)
	}
	if b, err := os.ReadFile(filepath.Join(stage, "contained")); err != nil || string(b) != "ok\n" {
		t.Fatal("stage write missing", string(b), err)
	}
}

func TestValidationFailsClosed(t *testing.T) {
	parent := t.TempDir()
	plugin := filepath.Join(parent, "plugin")
	stage := filepath.Join(parent, "stage")
	if err := os.WriteFile(plugin, []byte("binary"), 0500); err != nil {
		t.Fatal(err)
	}
	if err := os.Mkdir(stage, 0700); err != nil {
		t.Fatal(err)
	}
	t.Setenv("DOT_STAGE_ROOT", stage)

	if err := validate("relative", stage); err == nil || !strings.Contains(err.Error(), "DOT_E_POLICY") {
		t.Fatal("relative plugin accepted", err)
	}
	t.Setenv("DOT_STAGE_ROOT", parent)
	if err := validate(plugin, stage); err == nil || !strings.Contains(err.Error(), "DOT_E_POLICY") {
		t.Fatal("stage environment mismatch accepted", err)
	}
	t.Setenv("DOT_STAGE_ROOT", stage)
	if err := os.Chmod(plugin, 0722); err != nil {
		t.Fatal(err)
	}
	if err := validate(plugin, stage); err == nil || !strings.Contains(err.Error(), "DOT_E_PLUGIN_IDENTITY") {
		t.Fatal("writable plugin accepted", err)
	}
	if err := os.Chmod(plugin, 0500); err != nil {
		t.Fatal(err)
	}
	if err := os.Chmod(stage, 0755); err != nil {
		t.Fatal(err)
	}
	if err := validate(plugin, stage); err == nil || !strings.Contains(err.Error(), "DOT_E_PATH_ESCAPE") {
		t.Fatal("non-private stage accepted", err)
	}
	if err := os.Chmod(stage, 0700); err != nil {
		t.Fatal(err)
	}
	if err := validate(plugin, stage); err == nil || !strings.Contains(err.Error(), "must be an ELF executable") {
		t.Fatal("non-ELF plugin accepted", err)
	}
}
