// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package host

import (
	"errors"
	"fmt"
	"syscall"
	"time"

	"golang.org/x/sys/unix"
)

func stopProcessGroup(pid int) error {
	return settleGroup(
		func() ([]unix.KinfoProc, error) { return unix.SysctlKinfoProcSlice("kern.proc.pgrp", pid) },
		func() error { return syscall.Kill(-pid, syscall.SIGKILL) },
		func() { time.Sleep(2 * time.Millisecond) },
	)
}

// Signal delivery and EOF may precede Darwin publishing final zombie states.
// The leader remains unreaped, preventing group-ID reuse while cleanup repeats.
// Query only that group. Time, query failure, and persistent live/unknown state
// never grant success.
func settleGroup(query func() ([]unix.KinfoProc, error), signal func() error, pause func()) error {
	for attempt := 0; attempt < 50; attempt++ {
		signalErr := signal()
		if errors.Is(signalErr, syscall.ESRCH) {
			return nil
		}
		if signalErr != nil && !errors.Is(signalErr, syscall.EPERM) {
			return signalErr
		}
		if errors.Is(signalErr, syscall.EPERM) {
			// XNU may filter an exiting member from killpg before sysctl has
			// published SZOMB. Do not re-signal an EPERM group; observe the
			// transition for up to two seconds, then preserve the permission
			// failure. The unreaped leader prevents process-group ID reuse.
			return awaitTerminal(query, pause, 1000, signalErr)
		}
		group, err := query()
		if err != nil {
			return err
		}
		if onlyZombies(group) {
			return nil
		}
		if attempt < 49 {
			pause()
		}
	}
	return fmt.Errorf("DOT_E_POLICY: plugin process group remained live")
}

func awaitTerminal(query func() ([]unix.KinfoProc, error), pause func(), attempts int, timeout error) error {
	for attempt := 0; attempt < attempts; attempt++ {
		group, err := query()
		if err != nil {
			return err
		}
		if onlyZombies(group) {
			return nil
		}
		if attempt < attempts-1 {
			pause()
		}
	}
	return timeout
}

func onlyZombies(group []unix.KinfoProc) bool {
	const zombie = 5 // XNU sys/proc.h: SZOMB.
	for _, member := range group {
		if member.Proc.P_stat != zombie {
			return false
		}
	}
	return true
}
