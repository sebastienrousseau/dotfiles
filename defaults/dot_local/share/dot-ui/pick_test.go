// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
package main

import (
	"io"
	"os"
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"
)

func TestFuzzyMatch(t *testing.T) {
	cases := []struct {
		s, q string
		want bool
	}{
		{"altai-dark", "", true},
		{"altai-dark", "alt", true},
		{"altai-dark", "adk", true},   // subsequence
		{"altai-dark", "ALT", true},   // case-insensitive
		{"altai-dark", "zzz", false},  // no match
		{"altai-dark", "dark", true},  // contiguous
		{"altai-dark", "kdar", false}, // out of order
	}
	for _, c := range cases {
		if got := fuzzyMatch(c.s, c.q); got != c.want {
			t.Errorf("fuzzyMatch(%q,%q)=%v want %v", c.s, c.q, got, c.want)
		}
	}
}

func newTestPick() pickModel {
	return newPickModel(NewStyles(LoadPalette()), "Pick a theme", "Theme >",
		[]string{"altai-dark", "berlin-dark", "bloom-dark", "canary-light"})
}

func TestPickRefilter(t *testing.T) {
	m := newTestPick()
	m.query = "dark"
	m.refilter()
	if len(m.filtered) != 3 {
		t.Fatalf("expected 3 dark themes, got %d: %v", len(m.filtered), m.filtered)
	}
	m.query = "canary"
	m.refilter()
	if len(m.filtered) != 1 || m.filtered[0] != "canary-light" {
		t.Fatalf("canary filter wrong: %v", m.filtered)
	}
	if m.cursor != 0 {
		t.Errorf("refilter should reset cursor")
	}
}

func key(s string) tea.KeyMsg {
	switch s {
	case "down":
		return tea.KeyMsg{Type: tea.KeyDown}
	case "up":
		return tea.KeyMsg{Type: tea.KeyUp}
	case "enter":
		return tea.KeyMsg{Type: tea.KeyEnter}
	case "esc":
		return tea.KeyMsg{Type: tea.KeyEsc}
	case "backspace":
		return tea.KeyMsg{Type: tea.KeyBackspace}
	}
	return tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune(s)}
}

func TestPickNavigateAndSelect(t *testing.T) {
	m := newTestPick()
	var mm tea.Model = m
	mm, _ = mm.Update(key("down"))
	mm, _ = mm.Update(key("down"))
	mm, cmd := mm.Update(key("enter"))
	fm := mm.(pickModel)
	if fm.selected != "bloom-dark" {
		t.Fatalf("expected bloom-dark selected, got %q", fm.selected)
	}
	if cmd == nil {
		t.Error("enter should quit")
	}
}

func TestPickFilterThenSelect(t *testing.T) {
	m := newTestPick()
	var mm tea.Model = m
	for _, r := range "berlin" {
		mm, _ = mm.Update(key(string(r)))
	}
	mm, _ = mm.Update(key("enter"))
	if got := mm.(pickModel).selected; got != "berlin-dark" {
		t.Fatalf("expected berlin-dark, got %q", got)
	}
	// Backspace widens the filter again.
	m2 := newTestPick()
	var mm2 tea.Model = m2
	mm2, _ = mm2.Update(key("z"))
	if len(mm2.(pickModel).filtered) != 0 {
		t.Error("query z should match nothing")
	}
	mm2, _ = mm2.Update(key("backspace"))
	if len(mm2.(pickModel).filtered) != 4 {
		t.Error("backspace should restore all items")
	}
}

func TestPickCancel(t *testing.T) {
	m := newTestPick()
	mm, cmd := m.Update(key("esc"))
	if !mm.(pickModel).cancelled {
		t.Error("esc should cancel")
	}
	if cmd == nil {
		t.Error("esc should quit")
	}
	// ctrl+c too
	mm2, _ := m.Update(tea.KeyMsg{Type: tea.KeyCtrlC})
	if !mm2.(pickModel).cancelled {
		t.Error("ctrl+c should cancel")
	}
}

func TestPickEnterEmptyCancels(t *testing.T) {
	m := newTestPick()
	m.query = "zzz"
	m.refilter()
	mm, _ := m.Update(key("enter"))
	if !mm.(pickModel).cancelled {
		t.Error("enter with no matches should cancel")
	}
}

func TestPickView(t *testing.T) {
	m := newTestPick()
	m = func() pickModel { mm, _ := m.Update(tea.WindowSizeMsg{Width: 80, Height: 20}); return mm.(pickModel) }()
	out := m.View()
	for _, w := range []string{"Pick a theme", "Theme >", "altai-dark", "▸", "4/4"} {
		if !strings.Contains(out, w) {
			t.Errorf("view missing %q\n%s", w, out)
		}
	}
}

func TestReadItems(t *testing.T) {
	got := readItems(strings.NewReader("a\n\n  \nb\nc\n"))
	if len(got) != 3 {
		t.Fatalf("expected 3 items (blanks skipped), got %d: %v", len(got), got)
	}
}

func TestRunPickNonInteractive(t *testing.T) {
	sel, outcome := runPick(NewStyles(LoadPalette()), "h", "p", strings.NewReader("a\nb\n"), nil, false)
	if outcome != pickNoTTY || sel != "" {
		t.Errorf("no-tty runPick should be pickNoTTY, got %q,%d", sel, outcome)
	}
}

// TestCmdPickSnapshotFallsBack covers DOT_UI_SNAPSHOT=1 → exit 2 (fallback).
func TestCmdPickSnapshotFallsBack(t *testing.T) {
	t.Setenv("DOT_UI_SNAPSHOT", "1")
	code := cmdPick(NewStyles(LoadPalette()), []string{"--header", "H", "--prompt", "P"}, strings.NewReader("a\n"), io.Discard)
	if code != 2 {
		t.Errorf("snapshot pick should exit 2 (no-tty → fallback), got %d", code)
	}
}

// TestCmdPickNoTerminal covers the piped/non-interactive case (stderr is not
// a terminal) → exit 2 without touching /dev/tty.
func TestCmdPickNoTerminal(t *testing.T) {
	t.Setenv("DOT_UI_SNAPSHOT", "")
	old := stderrIsTTY
	defer func() { stderrIsTTY = old }()
	stderrIsTTY = func() bool { return false }
	var out strings.Builder
	code := cmdPick(NewStyles(LoadPalette()), nil, strings.NewReader("a\nb\n"), &out)
	if code != 2 || out.String() != "" {
		t.Errorf("no-terminal pick: code=%d out=%q", code, out.String())
	}
}

// TestCmdPickTTYOpenFails covers a terminal session where /dev/tty cannot be
// opened: the picker degrades to the fallback code (2).
func TestCmdPickTTYOpenFails(t *testing.T) {
	t.Setenv("DOT_UI_SNAPSHOT", "")
	oldTTY, oldOpen := stderrIsTTY, openTTY
	defer func() { stderrIsTTY, openTTY = oldTTY, oldOpen }()
	stderrIsTTY = func() bool { return true }
	openTTY = func() (*os.File, error) { return nil, os.ErrNotExist }
	if code := cmdPick(NewStyles(LoadPalette()), nil, strings.NewReader("a\n"), io.Discard); code != 2 {
		t.Errorf("tty open failure should exit 2, got %d", code)
	}
}

// TestPickInit covers the (no-op) Init command.
func TestPickInit(t *testing.T) {
	if newTestPick().Init() != nil {
		t.Error("pick Init should return nil")
	}
}

// TestPickUpAndCtrlKeys covers up/ctrl+p/ctrl+n navigation and bounds.
func TestPickUpAndCtrlKeys(t *testing.T) {
	var mm tea.Model = newTestPick()
	mm, _ = mm.Update(tea.KeyMsg{Type: tea.KeyCtrlN})
	mm, _ = mm.Update(tea.KeyMsg{Type: tea.KeyCtrlN})
	if c := mm.(pickModel).cursor; c != 2 {
		t.Fatalf("ctrl+n twice → cursor=%d want 2", c)
	}
	mm, _ = mm.Update(key("up"))
	if c := mm.(pickModel).cursor; c != 1 {
		t.Fatalf("up → cursor=%d want 1", c)
	}
	mm, _ = mm.Update(tea.KeyMsg{Type: tea.KeyCtrlP})
	mm, _ = mm.Update(tea.KeyMsg{Type: tea.KeyCtrlP}) // clamps at 0
	if c := mm.(pickModel).cursor; c != 0 {
		t.Fatalf("ctrl+p → cursor=%d want 0", c)
	}
	// Multi-rune keys (e.g. paste) are ignored by the query.
	mm, _ = mm.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune("ab")})
	if q := mm.(pickModel).query; q != "" {
		t.Fatalf("multi-rune key should be ignored, query=%q", q)
	}
	// Backspace on an empty query is a no-op.
	mm, _ = mm.Update(key("backspace"))
	if len(mm.(pickModel).filtered) != 4 {
		t.Fatal("backspace on empty query must keep all items")
	}
}

// TestPickVisibleRows covers the row-window clamps (3..20).
func TestPickVisibleRows(t *testing.T) {
	cases := []struct{ height, want int }{
		{0, 3}, {5, 3}, {7, 3}, {8, 4}, {15, 11}, {24, 20}, {100, 20},
	}
	for _, c := range cases {
		m := newTestPick()
		m.height = c.height
		if got := m.visibleRows(); got != c.want {
			t.Errorf("height=%d visibleRows=%d want %d", c.height, got, c.want)
		}
	}
}

// TestPickScrollWindow covers clampScroll in both directions: the offset
// follows the cursor down past the window, then back up.
func TestPickScrollWindow(t *testing.T) {
	items := []string{"a", "b", "c", "d", "e", "f"}
	var mm tea.Model = newPickModel(NewStyles(LoadPalette()), "", "", items)
	mm, _ = mm.Update(tea.WindowSizeMsg{Width: 80, Height: 7}) // 3 rows
	for i := 0; i < 4; i++ {
		mm, _ = mm.Update(key("down"))
	}
	pm := mm.(pickModel)
	if pm.cursor != 4 || pm.offset != 2 {
		t.Fatalf("after 4×down cursor=%d offset=%d want 4/2", pm.cursor, pm.offset)
	}
	view := pm.View()
	if !strings.Contains(view, "e") || strings.Contains(view, "  a\n") {
		t.Errorf("window should show the cursor row and hide the top:\n%s", view)
	}
	for i := 0; i < 3; i++ {
		mm, _ = mm.Update(key("up"))
	}
	pm = mm.(pickModel)
	if pm.cursor != 1 || pm.offset != 1 {
		t.Fatalf("after 3×up cursor=%d offset=%d want 1/1", pm.cursor, pm.offset)
	}
}

// TestPickViewDefaults covers the default prompt glyph, the no-header layout
// and the "no matches" line.
func TestPickViewDefaults(t *testing.T) {
	m := newPickModel(NewStyles(LoadPalette()), "", "", []string{"one", "two"})
	out := m.View()
	if !strings.Contains(out, "›") {
		t.Errorf("default prompt glyph missing:\n%s", out)
	}
	if strings.HasPrefix(out, "  \n") {
		t.Errorf("empty header should not emit a blank line:\n%s", out)
	}
	m.query = "zzz"
	m.refilter()
	if out := m.View(); !strings.Contains(out, "no matches") || !strings.Contains(out, "0/2") {
		t.Errorf("no-match view wrong:\n%s", out)
	}
}

// TestFuzzyMatchNonASCII is the regression test for the byte-vs-rune
// comparison that made any non-ASCII query unmatchable (found by
// FuzzFuzzyMatch's "a string matches itself" invariant).
func TestFuzzyMatchNonASCII(t *testing.T) {
	cases := []struct {
		s, q string
		want bool
	}{
		{"é", "é", true},
		{"Épinal", "é", true},
		{"日本語", "本", true},
		{"日本語", "語本", false},
		{"Straße", "straße", true},
		{"naïve-dark", "nïd", true},
	}
	for _, c := range cases {
		if got := fuzzyMatch(c.s, c.q); got != c.want {
			t.Errorf("fuzzyMatch(%q,%q)=%v want %v", c.s, c.q, got, c.want)
		}
	}
}
