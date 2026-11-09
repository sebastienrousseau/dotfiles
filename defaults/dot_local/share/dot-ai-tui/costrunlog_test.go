// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
package main

import (
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func runLogDB(t *testing.T, rt *costRoots, rows ...string) {
	t.Helper()
	if _, err := exec.LookPath("sqlite3"); err != nil {
		t.Skip("sqlite3 is not installed")
	}
	rt.runlog = filepath.Join(t.TempDir(), "dotfiles-ai.db")
	sql := "CREATE TABLE runs (id INTEGER PRIMARY KEY AUTOINCREMENT, ts TEXT NOT NULL DEFAULT '', delegate TEXT NOT NULL DEFAULT '', " +
		"model TEXT NOT NULL DEFAULT '', tokens_in INTEGER DEFAULT 0, tokens_out INTEGER DEFAULT 0, cost_usd REAL DEFAULT 0);"
	for _, r := range rows {
		sql += "INSERT INTO runs (ts, delegate, model, tokens_in, tokens_out, cost_usd) VALUES (" + r + ");"
	}
	if out, err := exec.Command("sqlite3", "-batch", "-init", "/dev/null", rt.runlog, sql).CombinedOutput(); err != nil {
		t.Fatalf("%v: %s", err, out)
	}
}

func TestRunLogDelegatesAreCounted(t *testing.T) {
	rt := testRoots(t)
	runLogDB(t, &rt,
		"'2026-11-09T09:00:00Z', 'vibe', 'mistral-medium-3.5', 1000, 200, 0.25",
		"'2026-11-09T09:30:00Z', 'vibe', 'mistral-medium-3.5', 10, 2, 0.05",
		// Claude and Codex runs are read from their transcripts instead.
		"'2026-11-09T09:00:00Z', 'claude', 'claude', 0, 0, 9",
		"'2026-11-09T09:00:00Z', 'codex', 'gpt-5.5', 0, 0, 9",
		// Outside the window.
		"'2026-09-01T09:00:00Z', 'vibe', 'mistral-medium-3.5', 0, 0, 7",
		// A name that is not a plain id is not an agent.
		"'2026-11-09T09:00:00Z', 'a''b', 'm', 0, 0, 1")
	out, err := runReport(t, rt, "--by", "agent")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(out, "vibe") || !strings.Contains(out, "$0.30") {
		t.Errorf("vibe runs:\n%s", out)
	}
	if strings.Contains(out, "$9") || strings.Contains(out, "$7") || strings.Contains(out, "$1.") {
		t.Errorf("a run counted that should not be:\n%s", out)
	}
	out, _ = runReport(t, rt, "--by", "session", "--json")
	if strings.Count(out, `"key":"vibe/run-`) != 2 {
		t.Errorf("each run is a session of its own:\n%s", out)
	}
}

func TestNoRunLogIsNoRows(t *testing.T) {
	rt := testRoots(t)
	rt.runlog = filepath.Join(t.TempDir(), "missing.db")
	if got := runLogSessions(rt.runlog, "2026-11-01", nil); len(got) != 0 {
		t.Fatalf("%+v", got)
	}
}

func TestSinceIsDays(t *testing.T) {
	o, err := parseCostArgs([]string{"--since", "7"})
	if err != nil || o.days != 7 {
		t.Fatalf("%+v %v", o, err)
	}
}

func TestRunLogRowsThatAreNotRuns(t *testing.T) {
	for _, ln := range []string{"", "1|not a time|vibe|m|0|0|1", "1|2026-11-09T09:00:00Z|vibe|m|0|0"} {
		if sc := runLogSession(ln, "2026-11-01", time.UTC); sc != nil {
			t.Errorf("%q: %+v", ln, sc)
		}
	}
	if got := runLogSessions("/nonexistent.db", "not a day", nil); got != nil {
		t.Errorf("a bad from: %+v", got)
	}
}

// The window's first day counts; the day before does not.
func TestRunLogWindowEdges(t *testing.T) {
	rt := testRoots(t)
	runLogDB(t, &rt,
		"'2026-10-11T12:00:00Z', 'vibe', 'm', 0, 0, 0.01",
		"'2026-10-10T12:00:00Z', 'vibe', 'm', 0, 0, 0.02")
	out, err := runReport(t, rt, "--json")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(out, `"cost_usd":0.01`) || strings.Contains(out, "0.03") || strings.Contains(out, "0.02") {
		t.Fatalf("%s", out)
	}
}
