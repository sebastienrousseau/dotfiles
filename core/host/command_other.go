//go:build !darwin && !linux

// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package host

import (
	"context"
	"fmt"
	"os"
	"os/exec"
)

func pluginCommand(context.Context, *os.File, string, string) (*exec.Cmd, func(), error) {
	return nil, nil, fmt.Errorf("DOT_E_SANDBOX_UNAVAILABLE: platform plugin driver unavailable")
}
