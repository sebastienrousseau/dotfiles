// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// claudeLine: one assistant entry as Claude Code writes it.
func claudeLine(session, id, model, ts string, in, w5, w1, rd, out int) string {
	r := strings.NewReplacer("SID", session, "MID", id, "MODEL", model, "TS", ts,
		"IN", itoa(in), "W5", itoa(w5), "W1", itoa(w1), "WT", itoa(w5+w1), "RD", itoa(rd), "OUT", itoa(out))
	return r.Replace(`{"type":"assistant","sessionId":"SID","timestamp":"TS","message":{"id":"MID","model":"MODEL",` +
		`"content":[{"type":"text","text":"never read"}],"usage":{"input_tokens":IN,"cache_creation_input_tokens":WT,` +
		`"cache_read_input_tokens":RD,"output_tokens":OUT,"cache_creation":{"ephemeral_5m_input_tokens":W5,"ephemeral_1h_input_tokens":W1},"speed":"standard"}}}`)
}

func writeFile(t *testing.T, path string, lines ...string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, []byte(strings.Join(lines, "\n")+"\n"), 0o600); err != nil {
		t.Fatal(err)
	}
}

func appendFile(t *testing.T, path, text string) {
	t.Helper()
	f, err := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0)
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = f.Close() }()
	if _, err := f.WriteString(text); err != nil {
		t.Fatal(err)
	}
}

func testRoots(t *testing.T) costRoots {
	t.Helper()
	d := t.TempDir()
	return costRoots{claude: filepath.Join(d, "claude"), codex: filepath.Join(d, "codex"),
		gateway: filepath.Join(d, "gateway"), cache: filepath.Join(d, "cache", "cost-index.json"),
		runlog: filepath.Join(d, "none.db")}
}

var costNow = time.Date(2026, 11, 9, 12, 0, 0, 0, time.UTC)

func fileRows(ix *costIndex, agent, session string) map[string]*costRow {
	out := map[string]*costRow{}
	for _, f := range ix.Files {
		if f.Agent == agent && f.Session == session {
			for k, r := range f.Rows {
				out[k] = r
			}
		}
	}
	return out
}

func TestClaudeTranscriptIsPricedPerDayAndModel(t *testing.T) {
	rt := testRoots(t)
	main := filepath.Join(rt.claude, "-home-u-shop", "s1.jsonl")
	writeFile(t, main,
		`{"type":"user","sessionId":"s1","timestamp":"2026-11-08T23:59:00Z","message":{"content":"a prompt"}}`,
		claudeLine("s1", "m1", "claude-haiku-5-5", "2026-11-08T23:59:30Z", 2, 0, 20454, 11383, 4),
		// One API message is logged once per content block, with its usage repeated: count it once.
		claudeLine("s1", "m2", "claude-sonnet-5-5", "2026-11-09T00:00:10Z", 1000, 0, 0, 0, 100),
		claudeLine("s1", "m2", "claude-sonnet-5-5", "2026-11-09T00:00:11Z", 1000, 0, 0, 0, 200),
		`{"type":"assistant","sessionId":"s1","timestamp":"2026-11-09T00:01:00Z","message":{"id":"x","model":"<synthetic>","usage":{"input_tokens":0,"output_tokens":0}}}`,
		`not json`,
	)
	// A subagent's transcript joins its parent session.
	writeFile(t, filepath.Join(rt.claude, "-home-u-shop", "s1", "subagents", "agent-a.jsonl"),
		claudeLine("s1", "m3", "claude-haiku-5-5", "2026-11-09T00:02:00Z", 1e6, 0, 0, 0, 0))
	ix := loadCostIndex(rt, costNow, 30, time.UTC)
	rows := fileRows(ix, "claude", "s1")
	h := rowOf(t, rows, "2026-11-08|claude-haiku-5-5")
	if h.Requests != 1 || h.Use != (tokenUse{Input: 2, CacheWrite1h: 20454, CacheRead: 11383, Output: 4}) {
		t.Fatalf("haiku row: %+v", h)
	}
	near(t, 0.00420683, h.USD, "haiku day 1")
	// The repeated message counts once, with its last usage.
	s := rowOf(t, rows, "2026-11-09|claude-sonnet-5-5")
	if s.Requests != 1 || s.Use != (tokenUse{Input: 1000, Output: 200}) {
		t.Fatalf("sonnet row: %+v", s)
	}
	near(t, (1000*2+200*10)/1e6, s.USD, "sonnet")
	if a := rowOf(t, rows, "2026-11-09|claude-haiku-5-5"); a.Requests != 1 {
		t.Fatalf("subagent row: %+v", a)
	}
	if len(rows) != 3 {
		t.Errorf("a synthetic message is not a request: %v", rows)
	}
}

func rowOf(t *testing.T, rows map[string]*costRow, key string) *costRow {
	t.Helper()
	r := rows[key]
	if r == nil {
		t.Fatalf("no row %s in %v", key, rows)
	}
	return r
}

// A line with no session id or time takes the file's name and mtime; fast
// mode and US-only inference cost more.
func TestClaudeLineDefaultsAndSurcharges(t *testing.T) {
	rt := testRoots(t)
	p := filepath.Join(rt.claude, "p", "named.jsonl")
	writeFile(t, p, `{"type":"assistant","message":{"id":"m1","model":"claude-opus-5-5",`+
		`"usage":{"input_tokens":1000000,"output_tokens":0,"speed":"fast","inference_geo":"us"}}}`)
	at := costNow.Add(-26 * time.Hour)
	if err := os.Chtimes(p, at, at); err != nil {
		t.Fatal(err)
	}
	ix := loadCostIndex(rt, costNow, 30, time.UTC)
	r := rowOf(t, fileRows(ix, "claude", "named"), "2026-11-08|claude-opus-5-5")
	near(t, 4*2*1.1, r.USD, "fast and US-only")
}

func TestASaveThatFailsIsAnError(t *testing.T) {
	rt := testRoots(t)
	writeFile(t, rt.cache+"/blocker", "")
	if err := loadCostIndex(rt, costNow, 30, time.UTC).save(filepath.Join(rt.cache, "blocker", "y")); err == nil {
		t.Fatal("saving under a file must fail")
	}
}

func TestCodexRolloutIsPricedFromItsTotals(t *testing.T) {
	rt := testRoots(t)
	p := filepath.Join(rt.codex, "2026", "11", "09", "rollout-2026-11-09T08-00-00-th-9.jsonl")
	tok := func(ts string, in, cached, out int) string {
		return `{"timestamp":"` + ts + `","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":` +
			itoa(in) + `,"cached_input_tokens":` + itoa(cached) + `,"output_tokens":` + itoa(out) + `,"total_tokens":0},"last_token_usage":{"input_tokens":1}}}}`
	}
	writeFile(t, p,
		`{"timestamp":"2026-11-09T08:00:00Z","type":"session_meta","payload":{"id":"th-9","cwd":"/w/shop"}}`,
		`{"timestamp":"2026-11-09T08:00:01Z","type":"turn_context","payload":{"model":"gpt-5.5"}}`,
		tok("2026-11-09T08:00:05Z", 100_000, 40_000, 1000),
		// The same totals again add nothing.
		tok("2026-11-09T08:00:06Z", 100_000, 40_000, 1000),
		`{"timestamp":"2026-11-09T08:01:00Z","type":"event_msg","payload":{"type":"token_count","info":null}}`,
		tok("2026-11-09T08:02:00Z", 150_000, 90_000, 3000),
	)
	ix := loadCostIndex(rt, costNow, 30, time.UTC)
	r := fileRows(ix, "codex", "th-9")["2026-11-09|gpt-5.5"]
	if r == nil || r.Requests != 2 {
		t.Fatalf("codex row: %+v", r)
	}
	want := tokenUse{Input: 60_000, CacheRead: 90_000, Output: 3000}
	if r.Use != want {
		t.Fatalf("tokens: want %+v, got %+v", want, r.Use)
	}
	near(t, (60_000*5+90_000*0.5+3000*30)/1e6, r.USD, "codex cost")
}

func TestIndexReadsOnlyWhatWasAppended(t *testing.T) {
	rt := testRoots(t)
	p := filepath.Join(rt.claude, "p", "s2.jsonl")
	writeFile(t, p, claudeLine("s2", "m1", "claude-opus-5-5", "2026-11-09T10:00:00Z", 1e6, 0, 0, 0, 0))
	ix := loadCostIndex(rt, costNow, 30, time.UTC)
	if err := ix.save(rt.cache); err != nil {
		t.Fatal(err)
	}
	// Half a line: not counted until it is complete.
	line := claudeLine("s2", "m2", "claude-opus-5-5", "2026-11-09T10:01:00Z", 0, 0, 0, 0, 1e6)
	appendFile(t, p, line[:40])
	ix = loadCostIndex(rt, costNow, 30, time.UTC)
	if err := ix.save(rt.cache); err != nil {
		t.Fatal(err)
	}
	if r := fileRows(ix, "claude", "s2")["2026-11-09|claude-opus-5-5"]; r.Requests != 1 {
		t.Fatalf("half a line was counted: %+v", r)
	}
	appendFile(t, p, line[40:]+"\n")
	ix = loadCostIndex(rt, costNow, 30, time.UTC)
	r := fileRows(ix, "claude", "s2")["2026-11-09|claude-opus-5-5"]
	if r.Requests != 2 {
		t.Fatalf("after the rest of the line: %+v", r)
	}
	near(t, 4+20, r.USD, "opus 5.5 both")
}

func TestARewrittenTranscriptIsReadAgain(t *testing.T) {
	rt := testRoots(t)
	p := filepath.Join(rt.claude, "p", "s3.jsonl")
	writeFile(t, p,
		claudeLine("s3", "m1", "claude-opus-5-5", "2026-11-09T10:00:00Z", 1e6, 0, 0, 0, 0),
		claudeLine("s3", "m2", "claude-opus-5-5", "2026-11-09T10:00:01Z", 1e6, 0, 0, 0, 0))
	if err := loadCostIndex(rt, costNow, 30, time.UTC).save(rt.cache); err != nil {
		t.Fatal(err)
	}
	writeFile(t, p, claudeLine("s3", "m9", "claude-opus-5-5", "2026-11-09T11:00:00Z", 0, 0, 0, 0, 1e6))
	r := fileRows(loadCostIndex(rt, costNow, 30, time.UTC), "claude", "s3")
	if len(r) != 1 || r["2026-11-09|claude-opus-5-5"].USD != 20 {
		t.Fatalf("rewritten file: %+v", r["2026-11-09|claude-opus-5-5"])
	}
}

func TestOldAndUnreadableFilesAreLeftOut(t *testing.T) {
	rt := testRoots(t)
	old := filepath.Join(rt.claude, "p", "old.jsonl")
	writeFile(t, old, claudeLine("old", "m1", "claude-opus-5-5", "2026-09-01T10:00:00Z", 1e6, 0, 0, 0, 0))
	at := costNow.AddDate(0, 0, -40)
	if err := os.Chtimes(old, at, at); err != nil {
		t.Fatal(err)
	}
	// A corrupt cache is ignored, not fatal.
	writeFile(t, rt.cache, "{nope")
	ix := loadCostIndex(rt, costNow, 30, time.UTC)
	if len(ix.Files) != 0 {
		t.Fatalf("a file untouched for 40 days is outside a 30-day window: %+v", ix.Files)
	}
}

// The gateway's usage log (dot-ai-serve's gateway_meter.py), set-aside logs
// included: the CLI's own cost when it gave one, else the model's price.
func TestGatewayLogIsCounted(t *testing.T) {
	rt := testRoots(t)
	writeFile(t, filepath.Join(rt.gateway, "usage-20261101T000000-1.jsonl"),
		`{"time":"2026-11-08T10:00:00Z","model":"claude-haiku-5-5","tokens":{"input":1000,"output":20},"cost_usd":0.5}`)
	writeFile(t, filepath.Join(rt.gateway, "usage.jsonl"),
		`{"time":"2026-11-09T10:00:00Z","model":"claude-opus-5-5","tokens":{"input":1000000,"cache_write_5m":0,"cache_write_1h":0,"cache_read":0,"output":0},"cost_usd":null}`,
		`{"time":"2026-11-09T10:00:01Z","model":"","tokens":{}}`,
		`not json`)
	writeFile(t, filepath.Join(rt.gateway, "gateway.token.jsonl"), `{"time":"2026-11-09T10:00:00Z","model":"claude-opus-5-5","cost_usd":9}`)
	sc := sessionOf(t, loadCostIndex(rt, costNow, 30, time.UTC), "gateway", "gateway")
	usd, reqs := totalUSD(sc)
	near(t, 0.5+4, usd, "gateway")
	if reqs != 2 {
		t.Fatalf("requests: %d", reqs)
	}
	if r := sc.Rows["2026-11-08|claude-haiku-5-5"]; r == nil || r.Use.Output != 20 {
		t.Fatalf("set-aside log: %+v", r)
	}
}

// Totals that restart lower count whole; lines with no usage are skipped
// unread; a transcript with no request has no session to report.
func TestCodexRestartsAndEmptyFiles(t *testing.T) {
	rt := testRoots(t)
	tok := `{"timestamp":"2026-11-09T08:00:0%d","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":%d,"cached_input_tokens":0,"output_tokens":0}}}}`
	writeFile(t, filepath.Join(rt.codex, "2026", "11", "09", "rollout-x-th-2.jsonl"),
		`{"timestamp":"2026-11-09T08:00:00Z","type":"turn_context","payload":{"model":"gpt-5.5"}}`,
		`{"timestamp":"2026-11-09T08:00:01Z","type":"response_item","payload":{"type":"message"}}`,
		fmt.Sprintf(tok, 2, 100_000), fmt.Sprintf(tok, 3, 40_000))
	writeFile(t, filepath.Join(rt.claude, "p", "quiet.jsonl"), `{"type":"user","message":{"content":"hi"}}`)
	ix := loadCostIndex(rt, costNow, 30, time.UTC)
	r := rowOf(t, fileRows(ix, "codex", "rollout-x-th-2"), "2026-11-09|gpt-5.5")
	if r.Requests != 2 || r.Use.Input != 140_000 {
		t.Fatalf("restarted totals: %+v", r)
	}
	for _, sc := range ix.sessions() {
		if sc.Agent == "claude" {
			t.Fatalf("a transcript with no request is no session: %+v", sc)
		}
	}
}
