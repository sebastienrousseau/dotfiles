// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
package main

import (
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"

	tea "github.com/charmbracelet/bubbletea"
)

// writeAgentState writes a session's state file where the hook does.
func writeAgentState(t *testing.T, state, agent, session, st string, at time.Time) {
	t.Helper()
	dir := filepath.Join(state, "dot", "cli", "agents", agent)
	if err := os.MkdirAll(dir, 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, session+".json"), record(agent, session, st, "e", at), 0o600); err != nil {
		t.Fatal(err)
	}
}

func TestLoadAgentsCountsTheSessionsDotAiStatusLists(t *testing.T) {
	state := t.TempDir()
	t.Setenv("XDG_STATE_HOME", state)
	now := time.Now()
	writeAgentState(t, state, "claude", "a", "running", now)
	writeAgentState(t, state, "claude", "b", "blocked", now)
	writeAgentState(t, state, "codex", "c", "idle", now)
	writeAgentState(t, state, "codex", "d", "gone", now)
	writeAgentState(t, state, "codex", "e", "blocked", now.Add(-25*time.Hour))
	if got := loadAgents(); got != (agentsMsg{live: 3, blocked: 1}) {
		t.Fatalf("loadAgents() = %+v, want 3 live, 1 blocked", got)
	}
}

func TestHeaderShowsTheAgentCountAndNamesBlocked(t *testing.T) {
	m := newModel()
	m.width = 160
	if h := m.renderHeader(); strings.Contains(h, "agent") {
		t.Fatalf("no sessions: header names agents: %q", h)
	}
	cases := []struct {
		msg  agentsMsg
		want string
	}{
		{agentsMsg{live: 1}, "1 agent"},
		{agentsMsg{live: 2}, "2 agents"},
		{agentsMsg{live: 3, blocked: 1}, "3 agents · 1 blocked"},
	}
	for _, c := range cases {
		h := upd(m, c.msg).renderHeader()
		if !strings.Contains(h, c.want) {
			t.Errorf("%+v: header %q lacks %q", c.msg, h, c.want)
		}
		if c.msg.blocked == 0 && strings.Contains(h, "blocked") {
			t.Errorf("%+v: header %q names blocked", c.msg, h)
		}
	}
	if h := upd(m, agentsMsg{live: 2}).renderHeader(); strings.Contains(h, "2 agents ·") {
		t.Errorf("header %q adds a blocked part with none blocked", h)
	}
}

func TestTheSessionTickReloadsTheAgentCount(t *testing.T) {
	state := t.TempDir()
	t.Setenv("XDG_STATE_HOME", state)
	writeAgentState(t, state, "claude", "a", "blocked", time.Now())
	m := newModel()
	_, cmd := m.Update(btopTickMsg{})
	if !batchYields(cmd, agentsMsg{live: 1, blocked: 1}) {
		t.Fatal("the session tick does not reload the agent count")
	}
	if !batchYields(m.Init(), agentsMsg{live: 1, blocked: 1}) {
		t.Fatal("Init does not load the agent count")
	}
}

// batchYields: whether cmd is a batch holding loadAgents (found by function
// identity, so the other commands, which probe the network and the process
// table, are not run) and that command returns want.
func batchYields(cmd tea.Cmd, want agentsMsg) bool {
	if cmd == nil {
		return false
	}
	batch, ok := cmd().(tea.BatchMsg)
	if !ok {
		return false
	}
	target := reflect.ValueOf(tea.Cmd(loadAgents)).Pointer()
	for _, c := range batch {
		if c != nil && reflect.ValueOf(c).Pointer() == target {
			return c() == want
		}
	}
	return false
}
