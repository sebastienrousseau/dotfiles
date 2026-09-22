//go:build linux

// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package host

import (
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"dotfiles.local/core/protocol"
)

func pluginCommand(ctx context.Context, plugin, stage, assurance string) (*exec.Cmd, error) {
	if assurance == protocol.AssuranceAudit {
		return exec.CommandContext(ctx, plugin), nil
	}
	if assurance != protocol.AssuranceProcess {
		return nil, fmt.Errorf("DOT_E_POLICY: unsupported assurance")
	}
	core, err := os.Executable()
	if err != nil {
		return nil, err
	}
	runner := filepath.Join(filepath.Dir(core), "dot-sandbox")
	if _, err = binary(runner); err != nil {
		return nil, fmt.Errorf("DOT_E_SANDBOX_UNAVAILABLE: trusted runner: %w", err)
	}
	return exec.CommandContext(ctx, runner, plugin, stage), nil
}
