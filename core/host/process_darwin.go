// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package host

import "golang.org/x/sys/unix"

// Darwin killpg returns EPERM when a group contains only zombies. The leader
// remains unreaped until cleanup finishes, preventing process-group ID reuse.
// Query only our group; unknown/live states and query errors fail closed.
func exitedGroup(pid int) bool {
	group, err := unix.SysctlKinfoProcSlice("kern.proc.pgrp", pid)
	if err != nil {
		return false
	}
	return onlyZombies(group)
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
