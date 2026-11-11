// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// agents.go — the cockpit header's agent count: the sessions dot ai status
// lists, read from the state files the hook writes (watch.go), so it needs
// no daemon. Loaded at start and on every session tick.
package main

import (
	"fmt"
	"time"

	tea "github.com/charmbracelet/bubbletea"
)

// agentsMsg: how many agent sessions are live, and how many of them blocked.
type agentsMsg struct{ live, blocked int }

func loadAgents() tea.Msg {
	var out agentsMsg
	for _, e := range loadAgentStates(agentStateDir(), time.Now()) {
		out.live++
		if e.State == "blocked" {
			out.blocked++
		}
	}
	return out
}

// label: "3 agents · 1 blocked"; "" with none live.
func (a agentsMsg) label() string {
	if a.live == 0 {
		return ""
	}
	s := fmt.Sprintf("%d agent", a.live)
	if a.live != 1 {
		s += "s"
	}
	if a.blocked > 0 {
		s += fmt.Sprintf(" · %d blocked", a.blocked)
	}
	return s
}
