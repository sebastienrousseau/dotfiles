// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
package main

import (
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

func TestComputeSCI(t *testing.T) {
	m := computeSCI(1000, 500, 500, 100, 10.0, 380.0)
	if m.PrefillJoules <= 0 || m.DecodeJoules <= 0 || m.CacheSavedWh <= 0 || m.TotalJoules <= 10.0 || m.GCO2eq <= 0 || m.SCIPer1kTok <= 0 {
		t.Fatalf("unexpected SCI metrics: %+v", m)
	}
	zero := computeSCI(0, 0, 0, 0, math.NaN(), -5.0)
	if zero.TotalJoules != 0 || zero.GCO2eq != 0 || zero.SCIPer1kTok != 0 {
		t.Fatalf("zero tokens SCI: %+v", zero)
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
	if err := logEventCLI([]string{"claude", "dotfiles", "0", "1.5", "42", "2026-10-17T18:00:00Z"}); err != nil {
		t.Fatalf("logEventCLI failed: %v", err)
	}
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
	sci := computeSCI(1000, 500, 200, 0, 5.0, 380.0)
	barStd := formatBtopBar(snap, sci, false)
	barGreen := formatBtopBar(snap, sci, true)
	if !strings.Contains(barStd, "[STD]") || !strings.Contains(barGreen, "[GREEN-UMA]") {
		t.Fatalf("formatBtopBar modes: std=%q green=%q", barStd, barGreen)
	}

	// Exercise fleet 'g' key and ecosystem slash commands (/eco, /green, /corral, /mcp, /draft).
	orig := execCommand
	defer func() { execCommand = orig }()
	execCommand = func(string, ...string) *exec.Cmd { return exec.Command("true") }

	m := sized()
	m = upd(m, key("g"))
	if !m.greenMode || !strings.Contains(m.View(), "green") {
		t.Fatal("g key should enable greenMode and render green indicator in header")
	}
	for _, cmd := range []string{"/eco", "/top", "/green", "/corral status", "/mcp check", "/draft topic.md"} {
		mm, _ := m.handleSlash(cmd)
		m = mm.(model)
	}
}
