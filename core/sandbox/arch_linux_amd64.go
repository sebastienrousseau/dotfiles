//go:build linux && amd64

// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package sandbox

import "golang.org/x/sys/unix"

func nativeAuditArch() (uint32, error) { return unix.AUDIT_ARCH_X86_64, nil }

func architectureDeniedSyscalls() []uint32 {
	return []uint32{
		unix.SYS_FORK, unix.SYS_VFORK,
		unix.SYS_CHMOD, unix.SYS_CHOWN, unix.SYS_LCHOWN,
		unix.SYS_UTIME, unix.SYS_UTIMES, unix.SYS_FUTIMESAT,
	}
}
