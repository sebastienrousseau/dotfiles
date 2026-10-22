// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
package main

import (
	"errors"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"unicode/utf8"
)

func TestBrailleSparkline(t *testing.T) {
	if renderBrailleSparkline([]float64{1, 2}, 0) != "" {
		t.Fatal("width 0 must yield empty string")
	}
	blank := renderBrailleSparkline(nil, 4)
	if utf8.RuneCountInString(blank) != 4 || blank != strings.Repeat(string(rune(0x2800)), 4) {
		t.Fatalf("empty samples: %q", blank)
	}
	flatZero := renderBrailleSparkline([]float64{0, 0, 0, 0}, 2)
	if flatZero != strings.Repeat(string(rune(0x2800)), 2) {
		t.Fatalf("flat zero: %q", flatZero)
	}
	flatPos := renderBrailleSparkline([]float64{5, 5, 5, 5}, 2)
	if utf8.RuneCountInString(flatPos) != 2 || flatPos == flatZero {
		t.Fatalf("flat positive should render mid-level dots: %q", flatPos)
	}
	ramp := renderBrailleSparkline([]float64{math.NaN(), 0, 25, 50, 75, 100, math.Inf(1)}, 4)
	if utf8.RuneCountInString(ramp) != 4 {
		t.Fatalf("ramp width mismatch: %q", ramp)
	}
	short := renderBrailleSparkline([]float64{10, 20}, 4)
	if utf8.RuneCountInString(short) != 4 {
		t.Fatalf("short samples width mismatch: %q", short)
	}
}

func TestMeterBar(t *testing.T) {
	if renderMeterBar(50, 0) != "" {
		t.Fatal("width 0")
	}
	if got := renderMeterBar(-10, 4); got != "░░░░" {
		t.Fatalf("negative pct: %q", got)
	}
	if got := renderMeterBar(math.NaN(), 4); got != "░░░░" {
		t.Fatalf("NaN pct: %q", got)
	}
	if got := renderMeterBar(150, 4); got != "████" {
		t.Fatalf(">100 pct: %q", got)
	}
	if got := renderMeterBar(50, 4); got != "██░░" {
		t.Fatalf("50 pct: %q", got)
	}
}

func TestComputeActionEntropy(t *testing.T) {
	if h, loop := computeActionEntropy(nil); h != 0 || loop {
		t.Fatalf("empty actions: h=%v loop=%v", h, loop)
	}
	if _, loop := computeActionEntropy([]string{"bash", "bash", "bash"}); !loop {
		t.Fatal("3 identical consecutive actions must trigger loop")
	}
	if h, loop := computeActionEntropy([]string{"a", "a", "a", "a", "a", "b", "a", "a", "a", "a", "a", "a", "a", "a", "a", "a"}); !loop || h >= 0.35 {
		t.Fatalf("low-entropy actions should trigger loop: h=%v loop=%v", h, loop)
	}
	if h, loop := computeActionEntropy([]string{"read", "grep", "edit", "test", "lint", "git"}); loop || h <= 1.5 {
		t.Fatalf("diverse actions should not trigger loop: h=%v loop=%v", h, loop)
	}
}

func TestLogEventCLI(t *testing.T) {
	orig := execCommand
	defer func() { execCommand = orig }()
	execCommand = func(string, ...string) *exec.Cmd { return exec.Command("true") }

	if err := logEventCLI([]string{"only-one"}); err == nil {
		t.Fatal("short args must return error")
	}
	var stmt string
	execCommand = func(_ string, args ...string) *exec.Cmd {
		stmt = args[len(args)-1]
		return exec.Command("true")
	}
	if err := logEventCLI([]string{"claude", "dotfiles", "0", "1.5", "42", "2026-10-17T18:00:00Z"}); err != nil {
		t.Fatalf("logEventCLI failed: %v", err)
	}
	// Energy is not measured: the run is stored with NULL joules and gco2eq.
	if !strings.Contains(stmt, ",42,NULL,NULL);") {
		t.Fatalf("energy must be stored as NULL, got: %s", stmt)
	}
	execCommand = func(string, ...string) *exec.Cmd { return exec.Command("true") }
	oldArgs := os.Args
	defer func() { os.Args = oldArgs }()
	os.Args = []string{"dot-ai-tui", "--log-event", "claude", "dotfiles", "0", "1.2", "10", "2026-10-17T18:00:00Z"}
	if err := run(); err != nil {
		t.Fatalf("run --log-event failed: %v", err)
	}
}

func TestParseCorralState(t *testing.T) {
	if got := parseCorralState(nil); got.TotalRepos != 0 {
		t.Fatalf("nil data: %+v", got)
	}
	if got := parseCorralState([]byte("{bad")); got.TotalRepos != 0 {
		t.Fatalf("malformed JSON: %+v", got)
	}
	payload := []byte(`{
		"r1": {"status": "ok"},
		"r2": {"status": "needs_fix"},
		"r3": {"worktree": true},
		"r4": {"dirty": true},
		"r5": {"archived": true}
	}`)
	got := parseCorralState(payload)
	if got.TotalRepos != 5 || got.Pristine != 1 || got.NeedsFix != 1 || got.Worktree != 1 || got.InFlight != 1 || got.Dormant != 1 {
		t.Fatalf("parseCorralState mismatch: %+v", got)
	}
}

func TestParsePassMCPReport(t *testing.T) {
	if got := parsePassMCPReport(nil); got.Grade != "N/A" {
		t.Fatalf("nil report: %+v", got)
	}
	for _, tc := range []struct {
		score int
		grade string
	}{
		{99, "A+"}, {92, "A"}, {85, "B"}, {72, "C"}, {40, "F"},
	} {
		if g := scoreToGrade(tc.score); g != tc.grade {
			t.Fatalf("scoreToGrade(%d)=%q want %q", tc.score, g, tc.grade)
		}
	}
	payload := []byte(`{
		"server": "corralctl-mcp",
		"score": 98,
		"phases_passed": 9,
		"attested": true,
		"tools": [
			{"destructiveHint": true, "openWorldHint": true},
			{"destructiveHint": false, "openWorldHint": true}
		]
	}`)
	got := parsePassMCPReport(payload)
	if got.ServerName != "corralctl-mcp" || got.Score != 98 || got.Grade != "A+" || got.PhasesPassed != 9 || got.ToxicPairs != 1 || !got.Attested {
		t.Fatalf("parsePassMCPReport mismatch: %+v", got)
	}
}

func TestParseDraftProvenance(t *testing.T) {
	if got := parseDraftProvenance(nil); got.ClaimsVerified != 0 {
		t.Fatalf("nil provenance: %+v", got)
	}
	got := parseDraftProvenance([]byte(`{"claims_verified": 14, "cache_hit_pct": 120.5, "c2pa_valid": true, "extract_engine": "ollama"}`))
	if got.ClaimsVerified != 14 || got.CacheHitPct != 100 || !got.C2PAValid || !got.GreenSplit {
		t.Fatalf("parseDraftProvenance high clamp: %+v", got)
	}
	neg := parseDraftProvenance([]byte(`{"claims_verified": -3, "cache_hit_pct": -10, "c2pa_valid": false, "extract_engine": "claude"}`))
	if neg.ClaimsVerified != 0 || neg.CacheHitPct != 0 || neg.GreenSplit {
		t.Fatalf("parseDraftProvenance low clamp: %+v", neg)
	}
}

func TestSampleEcosystemAndFormatBtopBar(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	t.Setenv("XDG_CONFIG_HOME", filepath.Join(home, ".config"))
	_ = os.MkdirAll(filepath.Join(home, "Code"), 0o700)
	_ = os.WriteFile(filepath.Join(home, "Code", ".corral-state.json"), []byte(`{"a":{"status":"ok"}}`), 0o600)
	_ = os.MkdirAll(filepath.Join(home, ".config", "claude"), 0o700)
	_ = os.WriteFile(filepath.Join(home, ".config", "claude", "mcp_servers.json"), []byte(`{"mcpServers":{"git":{},"corral":{}}}`), 0o600)

	snap := sampleEcosystem()
	if snap.Corral.TotalRepos != 1 || snap.MCPServers != 2 || snap.NumCPU < 1 {
		t.Fatalf("sampleEcosystem mismatch: %+v", snap)
	}
	_ = os.Remove(filepath.Join(home, "Code", ".corral-state.json"))
	_ = os.MkdirAll(filepath.Join(home, "Code", "Public", "repo1", ".git"), 0o700)
	_ = os.MkdirAll(filepath.Join(home, "Code", "Public", "repo2"), 0o700)
	_ = os.WriteFile(filepath.Join(home, "Code", "Public", "repo2", ".git"), []byte("gitdir: /tmp/wt"), 0o600)
	_ = os.MkdirAll(filepath.Join(home, "Code", "Public", "not-a-repo"), 0o700)
	snapScan := sampleEcosystem()
	if snapScan.Corral.TotalRepos != 2 || snapScan.Corral.Pristine != 1 || snapScan.Corral.Worktree != 1 {
		t.Fatalf("scanCodeDirs mismatch: %+v", snapScan.Corral)
	}
	if bar := formatBtopBar(snap); !strings.Contains(bar, "CPU:") || !strings.Contains(bar, "SCI:n/a") {
		t.Fatalf("formatBtopBar: %q", bar)
	}

	orig := execCommand
	defer func() { execCommand = orig }()
	execCommand = func(string, ...string) *exec.Cmd { return exec.Command("true") }

	m := sized()
	for _, cmd := range []string{"/eco", "/top", "/corral status", "/mcp check", "/draft topic.md"} {
		mm, _ := m.handleSlash(cmd)
		m = mm.(model)
	}
}

func TestBtopDeckAndControlCentre(t *testing.T) {
	orig := execCommand
	defer func() { execCommand = orig }()
	execCommand = func(string, ...string) *exec.Cmd { return exec.Command("printf", "action-ok") }

	m := sized()
	// Fallback when ecoSnap and cpuHist are zeroed
	m.ecoSnap = EcosystemSnapshot{}
	m.cpuHist = nil
	deck := m.renderBtopDeck()
	if !strings.Contains(deck, "CPU") || !strings.Contains(deck, "SCI n/a") {
		t.Fatalf("btop deck missing gauges: %q", deck)
	}
	m = upd(m, btopTickMsg{})
	if got := m.renderEcosystemControlCentre(80, 0); strings.Count(got, "\n") != 0 {
		t.Fatal("h<1 clamp failed")
	}

	// Jump to corralctl ('c'), passmcp ('v'), draft ('d') and render their Control Centres
	for _, tc := range []struct {
		k, want string
	}{
		{"c", "CORRALCTL"},
		{"v", "PASSMCP"},
		{"d", "DRAFT"},
	} {
		m = upd(m, key(tc.k))
		view := m.View()
		if !strings.Contains(view, tc.want) {
			t.Fatalf("key %q view missing %q:\n%s", tc.k, tc.want, view)
		}
		// Also test squeezed height truncation on ecosystem control centre
		_ = m.renderEcosystemControlCentre(60, 3)
	}

	// Action navigation (h/l/left/right), btop toggle (b), and console clear (0)
	m = upd(m, key("l"))
	if m.actionIdx != 1 {
		t.Fatalf("l should advance actionIdx, got %d", m.actionIdx)
	}
	m = upd(m, key("h"))
	if m.actionIdx != 0 {
		t.Fatalf("h should decrement actionIdx, got %d", m.actionIdx)
	}
	m = upd(m, key("b"))
	if !m.hideBtop {
		t.Fatal("b should hide btop deck")
	}
	_ = m.View()
	m = upd(m, key("b"))
	if m.hideBtop {
		t.Fatal("b again should show btop deck")
	}

	// Trigger action '1' on draft -> executes startActionCmd and handles actionResultMsg
	mm, cmd := m.Update(key("1"))
	m = mm.(model)
	if !m.running || cmd == nil {
		t.Fatal("pressing 1 should start Control Centre action")
	}
	actMsg := startActionCmd("draft", toolActions(tool{name: "draft"})[0])()
	m = upd(m, actMsg)
	if m.running || len(m.transcript) == 0 {
		t.Fatal("actionResultMsg should populate transcript and stop running")
	}
	// Error and empty branches of handleActionResult
	m = upd(m, actionResultMsg{tool: "draft", label: "Verify", output: "", err: errors.New("verify failed")})
	m = upd(m, actionResultMsg{tool: "draft", label: "Empty", output: "", err: nil})
	m = upd(m, key("0"))
	if len(m.transcript) != 0 {
		t.Fatal("key 0 should clear console transcript")
	}

	// Agent actions: '5' (interactive session) and '6' (focus input) on claude
	m.cursor = 0
	if _, c := m.Update(key("5")); c == nil {
		t.Fatal("agent action 5 should return dotExec cmd")
	}
	m = upd(m, key("6"))
	if m.focus != "input" {
		t.Fatal("agent action 6 should focus input")
	}
	m = upd(m, key("esc"))

	// Process table parsing, rendering, and [x] termination
	if parsePsProcesses(nil) != nil {
		t.Fatal("nil ps output should return nil")
	}
	psSample := []byte("  PID %CPU   RSS ELAPSED COMM\n" +
		"41002  4.5 262144   18:40 /opt/homebrew/bin/ollama\n" +
		"48210 12.4 327680   04:12 /opt/ai/bin/claude\n" +
		"48255  1.8  28672   04:11 /opt/ai/bin/dot-mcp\n" +
		"48260  1.8  16384   04:10 /opt/ai/bin/passmcp\n" +
		"99999  0.1   1024   00:01 /sbin/launchd\n" +
		"badpid 0.0      0   00:00 claude\n")
	procs := parsePsProcesses(psSample)
	if len(procs) != 4 || procs[0].Name != "claude" || procs[0].PID != 48210 {
		t.Fatalf("parsePsProcesses mismatch: %+v", procs)
	}

	// Render agent control centre + active process table with >6 processes and kill ('x')
	m.refreshed = true
	m.ecoSnap.ActiveProcs = append(procs,
		AIProcess{PID: 50001, Name: "codex", Role: "agent", CPUPct: 0.5, MemMB: 40, Elapsed: "01:00"},
		AIProcess{PID: 50002, Name: "goose", Role: "agent", CPUPct: 0.4, MemMB: 35, Elapsed: "01:00"},
		AIProcess{PID: 50003, Name: "aider", Role: "coding", CPUPct: 0.2, MemMB: 30, Elapsed: "01:00"},
	)
	m.ecoSnap.ToolProcs = map[string]int{"claude": 1, "ollama": 1}
	if v := m.View(); !strings.Contains(v, "agent control centre") || !strings.Contains(v, "48210") {
		t.Fatalf("agent control centre or PID missing in View:\n%s", v)
	}

	// x / kill behaviour is covered in kill_test.go.

	// Snapshot with DOT_AI_TOOL=corralctl
	t.Setenv("DOT_AI_SNAPSHOT", "1")
	t.Setenv("DOT_AI_TOOL", "corralctl")
	t.Setenv("DOT_AI_HOST", "127.0.0.1")
	t.Setenv("DOT_AI_PORT", "1")
	renderSnapshot()
}
