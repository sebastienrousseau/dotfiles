//go:build darwin

// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package host

import (
	"context"
	"fmt"
	"os/exec"

	"dotfiles.local/core/protocol"
)

func pluginCommand(ctx context.Context, plugin, _, assurance string) (*exec.Cmd, error) {
	if assurance != protocol.AssuranceAudit {
		return nil, fmt.Errorf("DOT_E_SANDBOX_UNAVAILABLE: macOS process containment requires a signed App Sandbox helper")
	}
	return exec.CommandContext(ctx, plugin), nil
}
