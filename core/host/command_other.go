//go:build !darwin && !linux

// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package host

import (
	"context"
	"fmt"
	"os/exec"
)

func pluginCommand(context.Context, string, string, string) (*exec.Cmd, error) {
	return nil, fmt.Errorf("DOT_E_SANDBOX_UNAVAILABLE: platform plugin driver unavailable")
}
