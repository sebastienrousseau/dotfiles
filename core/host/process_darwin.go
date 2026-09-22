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
		group, err := query()
		if err != nil {
			return err
		}
		if onlyZombies(group) {
			return nil
		}
		if errors.Is(signalErr, syscall.EPERM) {
			return signalErr
		}
		if attempt < 49 {
			pause()
		}
	}
	return fmt.Errorf("DOT_E_POLICY: plugin process group remained live")
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
