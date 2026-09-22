// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package host

import (
	"time"

	"golang.org/x/sys/unix"
)

// Darwin killpg returns EPERM when a group contains only zombies. The leader
// remains unreaped until cleanup finishes, preventing process-group ID reuse.
// Query only our group; unknown/live states and query errors fail closed.
func exitedGroup(pid int) bool {
	return settledGroup(func() ([]unix.KinfoProc, error) {
		return unix.SysctlKinfoProcSlice("kern.proc.pgrp", pid)
	}, func() { time.Sleep(2 * time.Millisecond) })
}

// EOF and a failed group signal may precede Darwin publishing the final zombie
// state. Observe that transition for at most 50 samples, without reaping or
// signalling another PID. Persistent live/unknown states and query errors remain
// failures; elapsed time by itself NEVER grants cleanup success.
func settledGroup(query func() ([]unix.KinfoProc, error), pause func()) bool {
	for attempt := 0; attempt < 50; attempt++ {
		group, err := query()
		if err != nil {
			return false
		}
		if onlyZombies(group) {
			return true
		}
		if attempt < 49 {
			pause()
		}
	}
	return false
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
