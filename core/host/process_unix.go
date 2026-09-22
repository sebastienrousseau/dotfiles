//go:build darwin || linux

// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package host

import (
	"errors"
	"os/exec"
	"syscall"
)

// configureProcess isolates signals, not filesystem/network authority. Descendants
// that deliberately create another session can escape this audit-only cleanup.
func configureProcess(cmd *exec.Cmd) (func() error, error) {
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	stop := func() error {
		if cmd.Process == nil {
			return nil
		}
		err := syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL)
		if errors.Is(err, syscall.ESRCH) {
			return nil
		}
		if errors.Is(err, syscall.EPERM) && exitedGroup(cmd.Process.Pid) {
			return nil
		}
		return err
	}
	cmd.Cancel = stop
	return stop, nil
}
