// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// TestToolActionsRunDeclaredDotCommands: every Control Centre action that
// runs `dot` names a command the CLI declares (lib/dot/data/commands.txt).
// The cockpit used to run `dot ai mcp doctor`, which is not a command:
// dot ai handed "mcp doctor" to Claude as a prompt.
func TestToolActionsRunDeclaredDotCommands(t *testing.T) {
	table, err := os.ReadFile(filepath.Join("..", "..", "..", "..", "lib", "dot", "data", "commands.txt"))
	if err != nil {
		t.Skipf("command table not reachable from this module: %v", err)
	}
	declared := map[string]bool{}
	for _, line := range strings.Split(string(table), "\n") {
		if f := strings.Split(line, "|"); len(f) > 1 && f[0] == "cmd" {
			declared[f[1]] = true
		}
	}
	for _, tl := range []tool{{name: "corralctl"}, {name: "passmcp"}, {name: "draft"}, {name: "claude", bin: "claude"}} {
		for _, act := range toolActions(tl) {
			if act.bin != "dot" {
				continue
			}
			words := []string{}
			for _, a := range act.args {
				if strings.HasPrefix(a, "-") || a == tl.name {
					break
				}
				words = append(words, a)
			}
			spelling := strings.Join(words, " ")
			// corralctl's own words pass through `dot ai corral` unchanged.
			if strings.HasPrefix(spelling, "ai corral") {
				continue
			}
			if !declared[spelling] {
				t.Errorf("%s action %q runs `dot %s`, which is not a declared command", tl.name, act.label, spelling)
			}
		}
	}
}
