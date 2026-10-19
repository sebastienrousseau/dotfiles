// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// newTestScanner points a scanner at empty Claude and Codex trees under a
// temp dir and returns it with the two session directories it reads.
func newTestScanner(t *testing.T) (sc *sessionScanner, claudeProj, codexDay string) {
	t.Helper()
	root := t.TempDir()
	sc = &sessionScanner{
		claudeRoot: filepath.Join(root, "claude", "projects"),
		codexRoot:  filepath.Join(root, "codex", "sessions"),
		now:        time.Now,
		files:      map[string]*tailedFile{},
	}
	claudeProj = filepath.Join(sc.claudeRoot, "-Users-me-proj")
	codexDay = filepath.Join(sc.codexRoot, time.Now().Format("2006/01/02"))
	for _, d := range []string{claudeProj, codexDay} {
		if err := os.MkdirAll(d, 0o755); err != nil {
			t.Fatal(err)
		}
	}
	return sc, claudeProj, codexDay
}

func writeLines(t *testing.T, path string, lines ...string) {
	t.Helper()
	f, err := os.OpenFile(path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = f.Close() }()
	for _, l := range lines {
		if _, err := f.WriteString(l + "\n"); err != nil {
			t.Fatal(err)
		}
	}
}

func onlySession(t *testing.T, got []AgentSession) AgentSession {
	t.Helper()
	if len(got) != 1 {
		t.Fatalf("want 1 session, got %d: %+v", len(got), got)
	}
	return got[0]
}

const (
	claudePrompt  = `{"type":"user","cwd":"/work/proj","gitBranch":"main","message":{"role":"user","content":"fix the bug"}}`
	claudeThink   = `{"type":"assistant","cwd":"/work/proj","gitBranch":"main","message":{"id":"m1","model":"claude-opus-5-5","stop_reason":null,"usage":{"input_tokens":10,"cache_creation_input_tokens":100,"cache_read_input_tokens":1000,"output_tokens":50},"content":[{"type":"thinking","thinking":"secret"}]}}`
	claudeToolUse = `{"type":"assistant","cwd":"/work/proj","gitBranch":"main","message":{"id":"m1","model":"claude-opus-5-5","stop_reason":"tool_use","usage":{"input_tokens":10,"cache_creation_input_tokens":100,"cache_read_input_tokens":1000,"output_tokens":50},"content":[{"type":"tool_use","name":"Bash","input":{"command":"make"}}]}}`
	claudeResult  = `{"type":"user","cwd":"/work/proj","message":{"role":"user","content":[{"type":"tool_result","content":"ok"}]}}`
	claudeDone    = `{"type":"assistant","cwd":"/work/proj","message":{"id":"m2","model":"claude-opus-5-5","stop_reason":"end_turn","usage":{"input_tokens":5,"cache_creation_input_tokens":20,"cache_read_input_tokens":1110,"output_tokens":30},"content":[{"type":"text","text":"done"}]}}`
	claudeTitle   = `{"type":"ai-title","aiTitle":"Fix the parser bug","sessionId":"s1"}`
	claudeSide    = `{"type":"assistant","isSidechain":true,"message":{"id":"x9","model":"claude-haiku-5-5","stop_reason":"tool_use","usage":{"input_tokens":999999,"output_tokens":999999},"content":[{"type":"tool_use","name":"Grep"}]}}`
)

func TestScanClaudeSessionFoldsMetadataAndTokens(t *testing.T) {
	sc, proj, _ := newTestScanner(t)
	writeLines(t, filepath.Join(proj, "s1.jsonl"),
		claudePrompt, claudeThink, claudeToolUse, claudeSide, claudeResult, claudeDone, claudeTitle, `{not json`)

	s := onlySession(t, sc.Scan())
	if s.Agent != "claude" || s.ID != "s1" || s.CWD != "/work/proj" || s.Branch != "main" {
		t.Fatalf("identity: %+v", s)
	}
	if s.Model != "claude-opus-5-5" || s.Title != "Fix the parser bug" {
		t.Fatalf("model/title: %+v", s)
	}
	if s.State != stateIdle || s.Tool != "" {
		t.Fatalf("finished turn must be idle, got %q/%q", s.State, s.Tool)
	}
	// m1 is logged twice with the same usage and must count once; the sidechain is ignored.
	if s.InTok != 10+100+5+20 || s.CacheTok != 1000+1110 || s.OutTok != 50+30 {
		t.Fatalf("tokens in=%d cache=%d out=%d", s.InTok, s.CacheTok, s.OutTok)
	}
	if s.CtxTok != 5+20+1110 {
		t.Fatalf("context = latest prompt size, got %d", s.CtxTok)
	}
	if s.Partial {
		t.Fatal("whole file was read; totals are not partial")
	}
}

func TestScanClaudeStateFollowsTheTurn(t *testing.T) {
	sc, proj, _ := newTestScanner(t)
	path := filepath.Join(proj, "s2.jsonl")
	steps := []struct {
		line, state, tool string
	}{
		{claudePrompt, stateWorking, ""},
		{claudeToolUse, stateTool, "Bash"},
		{claudeResult, stateWorking, ""},
		{`{"type":"user","message":{"content":[{"type":"text","text":"[Request interrupted by user]"}]}}`, stateIdle, ""},
		{claudePrompt, stateWorking, ""},
		{`{"type":"system","subtype":"turn_duration","durationMs":5}`, stateIdle, ""},
	}
	for i, st := range steps {
		writeLines(t, path, st.line)
		s := onlySession(t, sc.Scan())
		if s.State != st.state || s.Tool != st.tool {
			t.Fatalf("step %d: got %q/%q, want %q/%q", i, s.State, s.Tool, st.state, st.tool)
		}
	}
}

const (
	codexMeta    = `{"timestamp":"t","type":"session_meta","payload":{"id":"cx-1","cwd":"/work/rust","git":{"branch":"feat/x"},"base_instructions":"long"}}`
	codexTurn    = `{"type":"turn_context","payload":{"model":"gpt-5.5-codex","cwd":"/work/rust"}}`
	codexStart   = `{"type":"event_msg","payload":{"type":"task_started"}}`
	codexCall    = `{"type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{}"}}`
	codexTokens  = `{"type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":5000,"cached_input_tokens":4000,"output_tokens":300,"total_tokens":5300},"last_token_usage":{"input_tokens":900,"cached_input_tokens":800,"output_tokens":100,"total_tokens":1000},"model_context_window":10000}}}`
	codexOutput  = `{"type":"response_item","payload":{"type":"function_call_output","output":"secret"}}`
	codexDoneEvt = `{"type":"event_msg","payload":{"type":"task_complete"}}`
)

func TestScanCodexSessionTailsAppendedLines(t *testing.T) {
	sc, _, day := newTestScanner(t)
	path := filepath.Join(day, "rollout-2026-10-18T09-00-00-cx-1.jsonl")
	writeLines(t, path, codexMeta, codexTurn, codexStart, codexCall, codexTokens)

	s := onlySession(t, sc.Scan())
	if s.Agent != "codex" || s.ID != "cx-1" || s.CWD != "/work/rust" || s.Branch != "feat/x" || s.Model != "gpt-5.5-codex" {
		t.Fatalf("identity: %+v", s)
	}
	if s.State != stateTool || s.Tool != "exec_command" {
		t.Fatalf("pending call: %q/%q", s.State, s.Tool)
	}
	if s.InTok != 1000 || s.CacheTok != 4000 || s.OutTok != 300 || s.CtxTok != 1000 || s.CtxWin != 10000 {
		t.Fatalf("tokens: %+v", s)
	}
	offset := sc.files[path].offset

	writeLines(t, path, codexOutput)
	if s = onlySession(t, sc.Scan()); s.State != stateWorking || s.Tool != "" {
		t.Fatalf("after call output: %q/%q", s.State, s.Tool)
	}
	writeLines(t, path, codexDoneEvt)
	s = onlySession(t, sc.Scan())
	if s.State != stateIdle || s.Tool != "" {
		t.Fatalf("after task_complete: %q/%q", s.State, s.Tool)
	}
	if got := sc.files[path].offset; got <= offset {
		t.Fatalf("offset did not advance: %d -> %d", offset, got)
	}
	if s.ID != "cx-1" || s.Model != "gpt-5.5-codex" {
		t.Fatal("state from earlier reads must persist across scans")
	}
}

func TestScanHoldsAnUnterminatedLineUntilItCompletes(t *testing.T) {
	sc, proj, _ := newTestScanner(t)
	path := filepath.Join(proj, "s3.jsonl")
	half := len(claudeToolUse) / 2
	writeLines(t, path, claudePrompt)
	f, err := os.OpenFile(path, os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		t.Fatal(err)
	}
	_, _ = f.WriteString(claudeToolUse[:half])
	_ = f.Close()

	if s := onlySession(t, sc.Scan()); s.State != stateWorking {
		t.Fatalf("half a line must not be parsed: %q", s.State)
	}
	writeLines(t, path, claudeToolUse[half:])
	if s := onlySession(t, sc.Scan()); s.State != stateTool || s.OutTok != 50 {
		t.Fatalf("completed line: %+v", s)
	}
}

func TestScanRereadsATruncatedFile(t *testing.T) {
	sc, proj, _ := newTestScanner(t)
	path := filepath.Join(proj, "s4.jsonl")
	writeLines(t, path, claudePrompt, claudeToolUse, claudeResult, claudeDone)
	if s := onlySession(t, sc.Scan()); s.OutTok != 80 {
		t.Fatalf("first read: %d", s.OutTok)
	}
	if err := os.WriteFile(path, []byte(claudeToolUse+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	s := onlySession(t, sc.Scan())
	if s.OutTok != 50 || s.State != stateTool {
		t.Fatalf("rewritten file must be re-read from scratch: %+v", s)
	}
}

func TestScanTailReadsLargeFiles(t *testing.T) {
	orig := sessionTailCap
	sessionTailCap = int64(len(claudeDone)) + 10
	defer func() { sessionTailCap = orig }()

	sc, proj, day := newTestScanner(t)
	writeLines(t, filepath.Join(proj, "big.jsonl"), claudePrompt, claudeToolUse, claudeResult, claudeDone)
	writeLines(t, filepath.Join(day, "rollout-big.jsonl"), codexMeta, codexTurn, codexStart, codexDoneEvt)

	for _, s := range sc.Scan() {
		switch s.Agent {
		case "claude":
			if !s.Partial || s.OutTok != 30 || s.State != stateIdle {
				t.Fatalf("claude tail: %+v", s)
			}
		case "codex":
			// session_meta is read from the head even when the body is tailed.
			if s.ID != "cx-1" || s.Branch != "feat/x" || s.State != stateIdle || s.Partial {
				t.Fatalf("codex tail: %+v", s)
			}
		}
	}
}

func TestScanSkipsOldFilesSubagentsAndMissingRoots(t *testing.T) {
	sc, proj, _ := newTestScanner(t)
	old := filepath.Join(proj, "old.jsonl")
	writeLines(t, old, claudePrompt)
	past := time.Now().Add(-2 * sessionWindow)
	if err := os.Chtimes(old, past, past); err != nil {
		t.Fatal(err)
	}
	sub := filepath.Join(proj, "s1", "subagents")
	if err := os.MkdirAll(sub, 0o755); err != nil {
		t.Fatal(err)
	}
	writeLines(t, filepath.Join(sub, "agent-1.jsonl"), claudePrompt)
	if got := sc.Scan(); len(got) != 0 {
		t.Fatalf("want no sessions, got %+v", got)
	}

	gone := &sessionScanner{claudeRoot: "/nonexistent/a", codexRoot: "/nonexistent/b", now: time.Now, files: map[string]*tailedFile{}}
	if got := gone.Scan(); len(got) != 0 {
		t.Fatalf("missing roots: %+v", got)
	}
}

func TestScanDropsFilesThatLeaveTheWindow(t *testing.T) {
	sc, proj, _ := newTestScanner(t)
	path := filepath.Join(proj, "s5.jsonl")
	writeLines(t, path, claudePrompt)
	onlySession(t, sc.Scan())
	sc.now = func() time.Time { return time.Now().Add(2 * sessionWindow) }
	if got := sc.Scan(); len(got) != 0 || len(sc.files) != 0 {
		t.Fatalf("stale file must be forgotten: %d rows, %d tracked", len(got), len(sc.files))
	}
}

func TestScanListsDirectoriesOnlyEveryRelist(t *testing.T) {
	sc, proj, _ := newTestScanner(t)
	writeLines(t, filepath.Join(proj, "a.jsonl"), claudePrompt)
	onlySession(t, sc.Scan())
	writeLines(t, filepath.Join(proj, "b.jsonl"), claudePrompt)
	writeLines(t, filepath.Join(proj, "a.jsonl"), claudeToolUse)
	if s := onlySession(t, sc.Scan()); s.State != stateTool {
		t.Fatalf("tracked file must still be tailed between listings: %q", s.State)
	}
	sc.now = func() time.Time { return time.Now().Add(sessionRelist) }
	if got := sc.Scan(); len(got) != 2 {
		t.Fatalf("new file must appear at the next listing, got %d", len(got))
	}
}

func TestNewSessionScannerHonoursConfigDirs(t *testing.T) {
	t.Setenv("CLAUDE_CONFIG_DIR", "/x/claude")
	t.Setenv("CODEX_HOME", "/x/codex")
	sc := newSessionScanner()
	if sc.claudeRoot != "/x/claude/projects" || sc.codexRoot != "/x/codex/sessions" {
		t.Fatalf("roots: %q %q", sc.claudeRoot, sc.codexRoot)
	}
}

func TestRenderSessionRowsFiltersAndSanitises(t *testing.T) {
	now := time.Now()
	sessions := []AgentSession{
		{Agent: "claude", CWD: "/work/proj", Branch: "main", Model: "claude-opus-5-5", State: stateTool, Tool: "Bash",
			Title: "evil\x1b]52;c;aGk=\x07title\nnext", CtxTok: 70_000, OutTok: 1500, Last: now.Add(-3 * time.Second)},
		{Agent: "codex", CWD: "/work/rust", State: stateIdle, CtxTok: 1000, CtxWin: 10000, Last: now.Add(-2 * time.Hour)},
	}
	rows := renderSessionRows(sessions, "claude", now)
	out := strings.Join(rows, "\n")
	if !strings.Contains(out, "proj") || strings.Contains(out, "rust") {
		t.Fatalf("claude filter: %q", out)
	}
	if strings.Contains(out, "\x1b]52") || strings.Contains(out, "\x07") || strings.Contains(out, "title\nnext") {
		t.Fatalf("title not sanitised: %q", out)
	}
	if !strings.Contains(out, "tool:Bash") || !strings.Contains(out, "70k") || !strings.Contains(out, "3s") {
		t.Fatalf("columns: %q", out)
	}

	out = strings.Join(renderSessionRows(sessions, "codex", now), "\n")
	if !strings.Contains(out, "1k/10k 10%") || !strings.Contains(out, "2h") {
		t.Fatalf("codex context: %q", out)
	}
	if out := strings.Join(renderSessionRows(nil, "claude", now), "\n"); !strings.Contains(out, "no claude sessions") {
		t.Fatalf("empty state: %q", out)
	}
}

func TestSessionsMsgStoresAndRearmsTheTick(t *testing.T) {
	m := sized()
	mm, cmd := m.Update(sessionsMsg{{Agent: "claude", ID: "a"}})
	m = mm.(model)
	if len(m.sessions) != 1 || cmd == nil {
		t.Fatalf("sessions=%d cmd=%v", len(m.sessions), cmd)
	}
}

func TestCPUHistoryIsBounded(t *testing.T) {
	m := sized()
	for range 3 * cpuHistMax {
		m = upd(m, ecoMsg(EcosystemSnapshot{NumCPU: 4, TotalAICPU: 9}))
	}
	if len(m.cpuHist) != cpuHistMax {
		t.Fatalf("cpuHist len %d", len(m.cpuHist))
	}
}
