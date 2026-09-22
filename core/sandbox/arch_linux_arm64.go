//go:build linux && arm64

// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package sandbox

import "golang.org/x/sys/unix"

func nativeAuditArch() (uint32, error) { return unix.AUDIT_ARCH_AARCH64, nil }

func architectureDeniedSyscalls() []uint32 { return nil }

func architectureSyscallGuard() []unix.SockFilter { return nil }
