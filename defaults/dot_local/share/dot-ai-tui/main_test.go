// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
package main

import (
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"
)

// View must never panic across the render lifecycle: before sizing, after a
// WindowSizeMsg but before refresh, and after refresh populates the model.
// Regression for the index-out-of-range panic when m.tools was empty.
func TestViewNeverPanics(t *testing.T) {
	m := newModel()

	// 1. Fresh model (no size yet) → safe "loading" placeholder.
	if out := m.View(); out == "" {
		t.Fatal("empty view on fresh model")
	}

	// 2. Sized but not yet refreshed → must not index an empty slice.
	mm, _ := m.Update(tea.WindowSizeMsg{Width: 100, Height: 30})
	m = mm.(model)
	if out := m.View(); strings.Contains(out, "panic") {
		t.Fatal("view reported panic after sizing")
	}

	// 3. After a refresh payload → renders the fleet.
	mm, _ = m.Update(refreshMsg{tools: fleet, costToday: "$0.00"})
	m = mm.(model)
	out := m.View()
	if !strings.Contains(out, "claude") {
		t.Fatalf("view missing fleet after refresh:\n%s", out)
	}
}

// The rendered frame must carry the cockpit chrome (logo, fleet, chat input)
// once sized — guards the gorgeous layout against regressions.
func TestRenderChrome(t *testing.T) {
	m := newModel()
	mm, _ := m.Update(tea.WindowSizeMsg{Width: 94, Height: 30})
	m = mm.(model)
	mm, _ = m.Update(refreshMsg{tools: fleet, costToday: "$0.00"})
	m = mm.(model)
	out := m.View()
	for _, want := range []string{"dot ai", "claude", "❯", "gateway"} {
		if !strings.Contains(out, want) {
			t.Fatalf("rendered frame missing %q", want)
		}
	}
}

// Cursor navigation must stay in bounds at both ends.
func TestCursorBounds(t *testing.T) {
	m := newModel()
	up := tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune("k")}
	mm, _ := m.Update(up) // already at top
	if mm.(model).cursor != 0 {
		t.Fatal("cursor went below 0")
	}
	down := tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune("j")}
	for i := 0; i < len(fleet)+5; i++ {
		mm, _ = mm.(model).Update(down)
	}
	if c := mm.(model).cursor; c != len(fleet)-1 {
		t.Fatalf("cursor escaped bounds: got %d, want %d", c, len(fleet)-1)
	}
}
