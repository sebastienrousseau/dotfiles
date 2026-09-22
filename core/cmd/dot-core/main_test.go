// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestInvalidCommandPolicy(t *testing.T) {
	for _, args := range [][]string{
		{}, {"unknown"}, {"init", "--allow-audit-plugin"},
		{"apply", "--plugin", "/unreviewed"}, {"apply", "--plan-id", "ignored"},
		{"status", "--allow-audit-plugin"}, {"recover", "--plugin", "/unreviewed"},
		{"rollback", "--plan-id", "ignored"}, {"archive", "--allow-audit-plugin"},
		{"register"}, {"archive"}, {"apply"}, {"apply", "--allow-audit-plugin=false"},
		{"init", "extra-positional"}, {"init", "--unknown"},
	} {
		t.Run(strings.Join(args, " "), func(t *testing.T) {
			root := filepath.Join(t.TempDir(), "must-not-exist")
			call := append([]string{}, args...)
			if len(call) > 0 {
				call = append(call, "--root", root)
			}
			if err := run(call); err == nil {
				t.Fatal("invalid request accepted")
			} else if os.IsNotExist(err) {
				t.Fatal("invalid command reached filesystem access", err)
			}
			if _, err := os.Lstat(root); !os.IsNotExist(err) {
				t.Fatal("invalid command mutated root", err)
			}
		})
	}
	if err := run([]string{"init"}); err == nil {
		t.Fatal("missing root accepted")
	}
}
