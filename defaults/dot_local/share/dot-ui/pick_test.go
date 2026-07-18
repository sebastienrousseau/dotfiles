// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
package main

import (
	"io"
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

func TestCmdPickSnapshotFallsBack(t *testing.T) {
	t.Setenv("DOT_UI_SNAPSHOT", "1")
	code := cmdPick(NewStyles(LoadPalette()), []string{"--header", "H", "--prompt", "P"}, io.Discard)
	if code != 2 {
		t.Errorf("snapshot pick should exit 2 (no-tty → fallback), got %d", code)
	}
}
