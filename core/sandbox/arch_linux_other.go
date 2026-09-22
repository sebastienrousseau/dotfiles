//go:build linux && !amd64 && !arm64

// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package sandbox

import (
	"fmt"

	"golang.org/x/sys/unix"
)

func nativeAuditArch() (uint32, error) {
	return 0, fmt.Errorf("DOT_E_SANDBOX_UNAVAILABLE: unsupported seccomp architecture")
}

func architectureDeniedSyscalls() []uint32 { return nil }

func architectureSyscallGuard() []unix.SockFilter { return nil }
