//go:build linux && amd64

// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package sandbox

import "golang.org/x/sys/unix"

// x32Bit marks x32 ABI system call numbers, which also report
// AUDIT_ARCH_X86_64 and would otherwise miss every exact-number rule.
const x32Bit = 0x40000000

func nativeAuditArch() (uint32, error) { return unix.AUDIT_ARCH_X86_64, nil }

// architectureSyscallGuard kills any x32 system call. It runs straight after
// the architecture check and before the number is compared to the denylist.
func architectureSyscallGuard() []unix.SockFilter {
	return []unix.SockFilter{
		{Code: uint16(unix.BPF_LD | unix.BPF_W | unix.BPF_ABS), K: 0},
		{Code: uint16(unix.BPF_JMP | unix.BPF_JGE | unix.BPF_K), Jf: 1, K: x32Bit},
		{Code: uint16(unix.BPF_RET | unix.BPF_K), K: uint32(unix.SECCOMP_RET_KILL_PROCESS)},
	}
}

func architectureDeniedSyscalls() []uint32 {
	return []uint32{
		unix.SYS_FORK, unix.SYS_VFORK,
		unix.SYS_CHMOD, unix.SYS_CHOWN, unix.SYS_LCHOWN,
		unix.SYS_UTIME, unix.SYS_UTIMES, unix.SYS_FUTIMESAT,
	}
}
