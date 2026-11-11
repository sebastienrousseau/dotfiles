// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
package main

import (
	"path/filepath"
	"testing"
	"time"
)

func costState(startMs int64, models string) string {
	return `{"type":"cost-state","sessionId":"s1","totalCostUSD":0,"startTime":` + itoa(int(startMs)) +
		`,"modelUsage":{` + models + `}}`
}

func sessionOf(t *testing.T, ix *costIndex, agent, session string) *sessionCost {
	t.Helper()
	for _, sc := range ix.sessions() {
		if sc.Agent == agent && sc.Session == session {
			return sc
		}
	}
	t.Fatalf("no session %s/%s", agent, session)
	return nil
}

func totalUSD(sc *sessionCost) (usd float64, reqs int64) {
	for _, r := range sc.Rows {
		usd += r.USD
		reqs += r.Requests
	}
	return usd, reqs
}

// 2026-11-09T10:00:00Z in milliseconds.
const runStart = int64(1794218400000)

func TestCostStateAddsWhatTheTranscriptDidNotLog(t *testing.T) {
	rt := testRoots(t)
	p := filepath.Join(rt.claude, "p", "s1.jsonl")
	writeFile(t, p,
		// Before the run began: not part of its cost-state.
		claudeLine("s1", "m0", "claude-opus-5-5", "2026-11-09T09:00:00Z", 1e6, 0, 0, 0, 0),
		claudeLine("s1", "m1", "claude-opus-5-5", "2026-11-09T10:00:05Z", 1e6, 0, 0, 0, 0),
		// The run reports $10 on Opus 5.5 (the transcript shows $4) and $1 on
		// a model it never logged.
		costState(runStart, `"claude-opus-5-5":{"costUSD":10},"claude-haiku-4-5-20251001":{"costUSD":1}`),
	)
	sc := sessionOf(t, loadCostIndex(rt, costNow, 30, time.UTC), "claude", "s1")
	usd, reqs := totalUSD(sc)
	near(t, 4+10+1, usd, "session total")
	if reqs != 2 {
		t.Fatalf("unlogged cost is no request: %d", reqs)
	}
	if r := sc.Rows["2026-11-09|claude-haiku-4-5-20251001"]; r == nil || r.USD != 1 {
		t.Fatalf("unlogged model row: %+v", r)
	}
}

func TestCostStateCoveredByTheTranscriptAddsNothing(t *testing.T) {
	rt := testRoots(t)
	p := filepath.Join(rt.claude, "p", "s1.jsonl")
	writeFile(t, p,
		claudeLine("s1", "m1", "claude-opus-5-5", "2026-11-09T10:00:05Z", 1e6, 0, 0, 0, 0),
		costState(runStart, `"claude-opus-5-5":{"costUSD":2}`),
		// A later cost-state of the same run replaces the earlier one.
		claudeLine("s1", "m2", "claude-opus-5-5", "2026-11-09T10:01:00Z", 1e6, 0, 0, 0, 0),
		costState(runStart, `"claude-opus-5-5":{"costUSD":8}`),
	)
	// A subagent's requests count toward its parent's run.
	writeFile(t, filepath.Join(rt.claude, "p", "s1", "subagents", "agent-1.jsonl"),
		claudeLine("s1", "m3", "claude-opus-5-5", "2026-11-09T10:00:30Z", 0, 0, 0, 0, 0))
	sc := sessionOf(t, loadCostIndex(rt, costNow, 30, time.UTC), "claude", "s1")
	usd, _ := totalUSD(sc)
	near(t, 8, usd, "8 logged, 8 reported")
}

func TestARepeatedMessageIsStampedOnce(t *testing.T) {
	rt := testRoots(t)
	p := filepath.Join(rt.claude, "p", "s1.jsonl")
	writeFile(t, p,
		claudeLine("s1", "m1", "claude-opus-5-5", "2026-11-09T10:00:05Z", 1e6, 0, 0, 0, 0),
		claudeLine("s1", "m1", "claude-opus-5-5", "2026-11-09T10:00:06Z", 1e6, 0, 0, 0, 0),
		costState(runStart, `"claude-opus-5-5":{"costUSD":4}`),
	)
	ix := loadCostIndex(rt, costNow, 30, time.UTC)
	if n := len(ix.Files[p].Stamps); n != 1 {
		t.Fatalf("stamps: %d", n)
	}
	usd, _ := totalUSD(sessionOf(t, ix, "claude", "s1"))
	near(t, 4, usd, "one request")
}

func TestABadCostStateIsIgnored(t *testing.T) {
	rt := testRoots(t)
	p := filepath.Join(rt.claude, "p", "s1.jsonl")
	writeFile(t, p,
		claudeLine("s1", "m1", "claude-opus-5-5", "2026-11-09T10:00:05Z", 1e6, 0, 0, 0, 0),
		`{"type":"cost-state","startTime":0,"modelUsage":{"claude-opus-5-5":{"costUSD":99}}}`,
		`{"type":"cost-state", broken`,
	)
	usd, _ := totalUSD(sessionOf(t, loadCostIndex(rt, costNow, 30, time.UTC), "claude", "s1"))
	near(t, 4, usd, "no cost-state")
}
