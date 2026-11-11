// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestDefaultCostRootsFollowTheEnvironment(t *testing.T) {
	t.Setenv("CLAUDE_CONFIG_DIR", "/c")
	t.Setenv("CODEX_HOME", "/x")
	t.Setenv("XDG_STATE_HOME", "/s")
	t.Setenv("XDG_CACHE_HOME", "/k")
	rt := defaultCostRoots()
	got := [4]string{rt.claude, rt.codex, rt.gateway, rt.cache}
	want := [4]string{"/c/projects", "/x/sessions", "/s/dot/ai/serve", "/k/dot/ai/cost-index.json"}
	if got != want {
		t.Fatalf("%v", got)
	}
}

// The gateway log's tokens, cache writes and reads apart; the CLI's own
// cost prices a model the table does not know.
func TestGatewayLogTokensAndCost(t *testing.T) {
	rt := testRoots(t)
	writeFile(t, filepath.Join(rt.gateway, "usage.jsonl"),
		`{"time":"2026-11-09T10:00:00Z","model":"claude-new","tokens":{"input":1,"cache_write_5m":2,"cache_write_1h":3,"cache_read":4,"output":5},"cost_usd":0.25}`)
	r := rowOf(t, fileRows(loadCostIndex(rt, costNow, 30, time.UTC), "gateway", "gateway"), "2026-11-09|claude-new")
	if r.Use != (tokenUse{1, 2, 3, 4, 5}) || r.USD != 0.25 || r.Unpriced != 0 {
		t.Fatalf("%+v", r)
	}
}

// A later run uses what the cache says, and reads only what was appended.
func TestTheCacheIsUsed(t *testing.T) {
	rt := testRoots(t)
	writeFile(t, filepath.Join(rt.claude, "p", "s.jsonl"),
		claudeLine("s", "m1", "claude-opus-5-5", "2026-11-09T10:00:00Z", 1e6, 0, 0, 0, 0))
	if err := loadCostIndex(rt, costNow, 30, time.UTC).save(rt.cache); err != nil {
		t.Fatal(err)
	}
	b, err := os.ReadFile(rt.cache)
	if err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(rt.cache, []byte(strings.ReplaceAll(string(b), `"usd":4`, `"usd":99`)), 0o600); err != nil {
		t.Fatal(err)
	}
	r := rowOf(t, fileRows(loadCostIndex(rt, costNow, 30, time.UTC), "claude", "s"), "2026-11-09|claude-opus-5-5")
	if r.USD != 99 {
		t.Fatalf("the file was read again instead: %+v", r)
	}
	// A cache of another version is not.
	if err := os.WriteFile(rt.cache, []byte(strings.Replace(string(b), `"version":1`, `"version":9`, 1)), 0o600); err != nil {
		t.Fatal(err)
	}
	r = rowOf(t, fileRows(loadCostIndex(rt, costNow, 30, time.UTC), "claude", "s"), "2026-11-09|claude-opus-5-5")
	if r.USD != 4 {
		t.Fatalf("%+v", r)
	}
}

// A repeated message with cache writes replaces them too; a file nested
// deeper than a subagent's is not a transcript.
func TestRepeatedCacheWritesAndDepth(t *testing.T) {
	rt := testRoots(t)
	writeFile(t, filepath.Join(rt.claude, "p", "s.jsonl"),
		claudeLine("s", "m1", "claude-opus-5-5", "2026-11-09T10:00:00Z", 0, 100, 0, 0, 0),
		claudeLine("s", "m1", "claude-opus-5-5", "2026-11-09T10:00:01Z", 0, 300, 0, 0, 0))
	writeFile(t, filepath.Join(rt.claude, "p", "s", "subagents", "deeper", "x.jsonl"),
		claudeLine("s", "m9", "claude-opus-5-5", "2026-11-09T10:00:00Z", 1e6, 0, 0, 0, 0))
	rows := fileRows(loadCostIndex(rt, costNow, 30, time.UTC), "claude", "s")
	if r := rowOf(t, rows, "2026-11-09|claude-opus-5-5"); r.Use.CacheWrite5m != 300 || r.Requests != 1 {
		t.Fatalf("%+v", r)
	}
}

// A request at the very second the run began is part of the run.
func TestCostStateAtTheRunsStart(t *testing.T) {
	rt := testRoots(t)
	writeFile(t, filepath.Join(rt.claude, "p", "s1.jsonl"),
		claudeLine("s1", "m1", "claude-opus-5-5", "2026-11-09T10:00:00Z", 1e6, 0, 0, 0, 0),
		costState(runStart, `"claude-opus-5-5":{"costUSD":4.5}`))
	usd, _ := totalUSD(sessionOf(t, loadCostIndex(rt, costNow, 30, time.UTC), "claude", "s1"))
	near(t, 4.5, usd, "$4 logged at the start, $0.50 not")
}

func TestEveryCodexModelIsPriced(t *testing.T) {
	want := map[string]float64{ // a million each of input, cached input and output
		"gpt-5.6-sol": 24.4, "gpt-5.6-terra": 14.2, "gpt-5.6-luna": 1.42, "gpt-5.4": 17.75,
		"gpt-5.4-mini": 5.325, "gpt-5.4-nano": 1.47, "gpt-5.3-codex": 15.925, "gpt-5.2": 15.925,
		"gpt-5.1": 11.375, "gpt-5": 11.375, "gpt-5-mini": 2.275, "gpt-5-nano": 0.455,
	}
	for m, usd := range want {
		// Under 272K so the short price applies where there is a long one.
		got, ok := priceUse("codex", m, tokenUse{Input: 100_000, CacheRead: 100_000, Output: 100_000}, 1)
		if !ok {
			t.Errorf("%s: not priced", m)
		}
		near(t, usd/10, got, m)
	}
}

func TestReportTotalsCacheTokensAndOrdersDays(t *testing.T) {
	rt := testRoots(t)
	writeFile(t, filepath.Join(rt.claude, "p", "s.jsonl"),
		claudeLine("s", "m1", "claude-opus-5-5", "2026-11-07T10:00:00Z", 0, 0, 0, 0, 1e6),
		claudeLine("s", "m2", "claude-opus-5-5", "2026-11-09T10:00:00Z", 1, 2, 3, 4, 0))
	out, _ := runReport(t, rt, "--json", "--by", "day")
	var rep costReportJSON
	if err := json.Unmarshal([]byte(out), &rep); err != nil {
		t.Fatal(err)
	}
	if rep.Rows[0].Key != "2026-11-09" || rep.Total.CacheRead != 4 || rep.Total.CacheWrite != 5 || rep.Total.InputTokens != 10 {
		t.Fatalf("%+v", rep)
	}
	text, _ := runReport(t, rt)
	if !strings.Contains(text, "DAY") && !strings.HasPrefix(text, "AGENT                SESSIONS  REQUESTS     INPUT    OUTPUT        COST\n") {
		t.Fatalf("header:\n%s", text)
	}
	if strings.Contains(text, "no price") {
		t.Fatalf("no unpriced line when every model is priced:\n%s", text)
	}
}
