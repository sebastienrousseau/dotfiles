//go:build !darwin && !linux

// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package host

import (
	"fmt"
	"os/exec"
)

func configureProcess(*exec.Cmd) (func() error, error) {
	return nil, fmt.Errorf("DOT_E_POLICY: plugin process driver unavailable")
}
