//go:build !linux

// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package sandbox

import "fmt"

func Run(string, string) error {
	return fmt.Errorf("DOT_E_SANDBOX_UNAVAILABLE: process assurance is currently Linux-only")
}
