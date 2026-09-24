//go:build linux && amd64

// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package sandbox

import (
	"errors"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"
	"testing"
)

// x32 system calls report AUDIT_ARCH_X86_64 with bit 30 set in the number,
// so an exact-number denylist never matches them. The filter must kill the
// process whatever the kernel's CONFIG_X86_X32_ABI setting.
func TestX32SyscallsAreKilled(t *testing.T) {
	parent := t.TempDir()
	stage := filepath.Join(parent, "stage")
	if err := os.Mkdir(stage, 0700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(stage, "x32"), nil, 0600); err != nil {
		t.Fatal(err)
	}
	probe, runner := buildProbe(t, parent)
	cmd := exec.Command(runner, probe, stage)
	cmd.Env = []string{"LANG=C", "DOT_STAGE_ROOT=" + stage}
	out, err := cmd.CombinedOutput()
	var exit *exec.ExitError
	if !errors.As(err, &exit) {
		t.Fatalf("x32 syscall was not fatal: %s %v", out, err)
	}
	status, ok := exit.Sys().(syscall.WaitStatus)
	if !ok || !status.Signaled() || status.Signal() != syscall.SIGSYS {
		t.Fatalf("x32 syscall: want SIGSYS, got %v: %s", exit, out)
	}
}
