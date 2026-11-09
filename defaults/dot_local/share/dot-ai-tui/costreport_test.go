// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// reportFixture: two Claude sessions on two days and a Codex one.
func reportFixture(t *testing.T) costRoots {
	t.Helper()
	rt := testRoots(t)
	writeFile(t, filepath.Join(rt.claude, "p", "aaaa1111-0000.jsonl"),
		claudeLine("aaaa1111-0000", "m1", "claude-opus-5-5", "2026-11-08T10:00:00Z", 1e6, 0, 0, 0, 0),
		claudeLine("aaaa1111-0000", "m2", "claude-sonnet-5-5", "2026-11-09T10:00:00Z", 0, 0, 0, 0, 1e6))
	writeFile(t, filepath.Join(rt.claude, "q", "bbbb2222-0000.jsonl"),
		claudeLine("bbbb2222-0000", "m1", "claude-opus-5-5", "2026-11-09T11:00:00Z", 0, 0, 0, 0, 1e5),
		claudeLine("bbbb2222-0000", "m2", "claude-opus-9", "2026-11-09T11:00:01Z", 500, 0, 0, 0, 500))
	writeFile(t, filepath.Join(rt.codex, "2026", "11", "09", "rollout-x-th-1.jsonl"),
		`{"timestamp":"2026-11-09T08:00:00Z","type":"session_meta","payload":{"id":"th-1"}}`,
		`{"timestamp":"2026-11-09T08:00:01Z","type":"turn_context","payload":{"model":"gpt-5.5"}}`,
		`{"timestamp":"2026-11-09T08:00:05Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100000,"cached_input_tokens":0,"output_tokens":0}}}}`)
	return rt
}

func runReport(t *testing.T, rt costRoots, args ...string) (string, error) {
	t.Helper()
	var out bytes.Buffer
	err := costReport(rt, costNow, time.UTC, "box", args, &out)
	return out.String(), err
}

func TestCostByAgent(t *testing.T) {
	out, err := runReport(t, reportFixture(t))
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{
		"AGENT", "SESSIONS", "COST",
		// Opus 5.5: $4 + $2; Sonnet 5.5: $10.
		"claude", "$16.00",
		"codex", "$0.50",
		"total", "$16.50",
		"last 30 days",
		"1000 tokens on models with no price: claude-opus-9",
	} {
		if !strings.Contains(out, want) {
			t.Errorf("missing %q in:\n%s", want, out)
		}
	}
}

func TestCostByDayHostAndModel(t *testing.T) {
	rt := reportFixture(t)
	out, _ := runReport(t, rt, "--by", "day")
	if !strings.Contains(out, "2026-11-08") || !strings.Contains(out, "2026-11-09") {
		t.Errorf("by day:\n%s", out)
	}
	if strings.Index(out, "2026-11-09") > strings.Index(out, "2026-11-08") {
		t.Errorf("newest day first:\n%s", out)
	}
	out, _ = runReport(t, rt, "--by", "host")
	if !strings.Contains(out, "box") || !strings.Contains(out, "$16.50") {
		t.Errorf("by host:\n%s", out)
	}
	out, _ = runReport(t, rt, "--by", "model")
	if !strings.Contains(out, "claude-sonnet-5-5") || !strings.Contains(out, "gpt-5.5") {
		t.Errorf("by model:\n%s", out)
	}
	// One day only.
	out, _ = runReport(t, rt, "--by", "day", "--days", "1")
	if strings.Contains(out, "2026-11-08") || !strings.Contains(out, "last 1 day") {
		t.Errorf("--days 1:\n%s", out)
	}
}

func TestCostOfOneSession(t *testing.T) {
	rt := reportFixture(t)
	// A unique prefix names a session.
	out, err := runReport(t, rt, "--session", "aaaa1111")
	if err != nil {
		t.Fatal(err)
	}
	for _, want := range []string{"aaaa1111-0000", "claude", "claude-opus-5-5", "claude-sonnet-5-5", "$14.00"} {
		if !strings.Contains(out, want) {
			t.Errorf("missing %q in:\n%s", want, out)
		}
	}
	if strings.Contains(out, "bbbb") {
		t.Errorf("another session shown:\n%s", out)
	}
	if _, err := runReport(t, rt, "--session", "zzzz"); err == nil || !strings.Contains(err.Error(), "no session zzzz") {
		t.Errorf("unknown session: %v", err)
	}
	// A prefix two sessions share is refused.
	writeFile(t, filepath.Join(rt.claude, "p", "aaaa9999.jsonl"),
		claudeLine("aaaa9999", "m1", "claude-opus-5-5", "2026-11-09T10:00:00Z", 1, 0, 0, 0, 0))
	if _, err := runReport(t, rt, "--session", "aaaa"); err == nil || !strings.Contains(err.Error(), "matches 2 sessions") {
		t.Errorf("ambiguous session: %v", err)
	}
}

func TestCostJSON(t *testing.T) {
	out, err := runReport(t, reportFixture(t), "--by", "session", "--json")
	if err != nil {
		t.Fatal(err)
	}
	var rep costReportJSON
	if err := json.Unmarshal([]byte(out), &rep); err != nil {
		t.Fatalf("%v\n%s", err, out)
	}
	if rep.Schema != "ai/cost-report.v1" || rep.By != "session" || rep.Days != 30 || rep.Host != "box" {
		t.Fatalf("header: %+v", rep)
	}
	a := rep.Rows[0]
	got := [5]any{a.Key, a.Sessions, a.Requests, a.InputTokens, a.OutputTokens}
	if got != [5]any{"claude/aaaa1111-0000", 1, int64(2), int64(1e6), int64(1e6)} {
		t.Fatalf("the costliest session first: %+v", a)
	}
	near(t, 14, a.CostUSD, "session cost")
	near(t, 16.5, rep.Total.CostUSD, "total")
	if rep.Total.UnpricedTokens != 1000 || rep.Unpriced[0] != "claude-opus-9" {
		t.Fatalf("unpriced: %+v %v", rep.Total, rep.Unpriced)
	}
}

// Rows that cost the same are in key order; an id that is also another's
// prefix names its own session.
func TestCostTiesAndExactIDs(t *testing.T) {
	rows := []costRowJSON{{Key: "b", CostUSD: 1}, {Key: "a", CostUSD: 1}, {Key: "c", CostUSD: 2}}
	sortRows("agent", rows)
	if rows[0].Key != "c" || rows[1].Key != "a" || rows[2].Key != "b" {
		t.Fatalf("%v", rows)
	}
	all := []*sessionCost{{Session: "ab"}, {Session: "a"}}
	if sc, err := pickSession(all, "a"); err != nil || sc.Session != "a" {
		t.Fatalf("%v %v", sc, err)
	}
}

func TestCostBadUsage(t *testing.T) {
	rt := reportFixture(t)
	for _, args := range [][]string{{"--by", "planet"}, {"--days", "0"}, {"--days", "x"}, {"--frob"}, {"--session"}} {
		if _, err := runReport(t, rt, args...); err == nil || !strings.Contains(err.Error(), "usage") {
			t.Errorf("%v: %v", args, err)
		}
	}
}

func TestCostWithNoTranscripts(t *testing.T) {
	out, err := runReport(t, testRoots(t))
	if err != nil || !strings.Contains(out, "No agent usage in the last 30 days.") {
		t.Fatalf("%v\n%s", err, out)
	}
	out, _ = runReport(t, testRoots(t), "--json")
	if !strings.Contains(out, `"rows":[]`) {
		t.Fatalf("empty json: %s", out)
	}
}

func TestHumanTokCountsBillions(t *testing.T) {
	for n, want := range map[int64]string{999_999_999: "1000.0M", 1_489_300_000: "1.5B", 12_000_000_000: "12.0B"} {
		if got := humanTok(n); got != want {
			t.Errorf("%d: want %s, got %s", n, want, got)
		}
	}
}

// testdata/cost-report.json is the --json report of reportFixture, which
// tests/unit/dot-cli/test_cost_report_schema.py validates against
// schemas/cli/ai-cost-report.v1.schema.json. DOT_AI_UPDATE_GOLDEN=1 rewrites it.
func TestCostJSONGolden(t *testing.T) {
	out, err := runReport(t, reportFixture(t), "--by", "session", "--json")
	if err != nil {
		t.Fatal(err)
	}
	var v any
	if err := json.Unmarshal([]byte(out), &v); err != nil {
		t.Fatal(err)
	}
	b, _ := json.MarshalIndent(v, "", "  ")
	b = append(b, '\n')
	golden := filepath.Join("testdata", "cost-report.json")
	if os.Getenv("DOT_AI_UPDATE_GOLDEN") == "1" {
		if err := os.WriteFile(golden, b, 0o644); err != nil {
			t.Fatal(err)
		}
	}
	want, err := os.ReadFile(golden)
	if err != nil || !bytes.Equal(want, b) {
		t.Fatalf("%s is stale (DOT_AI_UPDATE_GOLDEN=1 go test -run Golden): %v\n%s", golden, err, b)
	}
}

func TestRunDispatchesCost(t *testing.T) {
	oldArgs := os.Args
	defer func() { os.Args = oldArgs }()
	os.Args = []string{"dot-ai-tui", "cost", "--by", "planet"}
	if err := run(); err == nil || !strings.Contains(err.Error(), "usage: dot ai cost show") {
		t.Errorf("run cost: %v", err)
	}
}
