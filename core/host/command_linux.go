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

func pluginCommand(ctx context.Context, plugin *os.File, stage, assurance string) (*exec.Cmd, func(), error) {
	if assurance == protocol.AssuranceAudit {
		return descriptorCommand(ctx, plugin, nil), func() {}, nil
	}
	if assurance != protocol.AssuranceProcess {
		return nil, nil, fmt.Errorf("DOT_E_POLICY: unsupported assurance")
	}
	core, err := os.Executable()
	if err != nil {
		return nil, nil, err
	}
	return containedCommand(ctx, filepath.Join(filepath.Dir(core), "dot-sandbox"), plugin, stage)
}

func containedCommand(ctx context.Context, runnerPath string, plugin *os.File, stage string) (*exec.Cmd, func(), error) {
	runner, _, err := openBinary(runnerPath)
	if err != nil {
		return nil, nil, fmt.Errorf("DOT_E_SANDBOX_UNAVAILABLE: trusted runner: %w", err)
	}
	closeRunner := func() { runner.Close() }
	return descriptorCommand(ctx, runner, []*os.File{plugin}, descriptorPath(4), stage), closeRunner, nil
}
