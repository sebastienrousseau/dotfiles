// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
package main

import (
	"testing"

	"github.com/charmbracelet/lipgloss"
)

func TestEnvColor(t *testing.T) {
	fb := lipgloss.Color("#ffffff")
	cases := []struct {
		name, env, val string
		want           lipgloss.Color
	}{
		{"valid 6-hex", "DOT_UI_TEST_A", "#1a7f7a", "#1a7f7a"},
		{"valid 3-hex", "DOT_UI_TEST_B", "#abc", "#abc"},
		{"invalid no-hash", "DOT_UI_TEST_C", "1a7f7a", fb},
		{"invalid word", "DOT_UI_TEST_D", "teal", fb},
		{"invalid length", "DOT_UI_TEST_E", "#12345", fb},
		{"empty", "DOT_UI_TEST_F", "", fb},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if c.val != "" {
				t.Setenv(c.env, c.val)
			}
			if got := envColor(c.env, fb); got != c.want {
				t.Fatalf("envColor(%q)=%q want %q", c.val, got, c.want)
			}
		})
	}
}

func TestLoadPaletteFallback(t *testing.T) {
	// No DOT_UI_* set (unset the ones that matter) → all fallback.
	for _, k := range []string{"DOT_UI_ACCENT", "DOT_UI_SUCCESS", "DOT_UI_ERROR", "DOT_UI_INFO", "DOT_UI_PANEL", "DOT_UI_BORDER", "DOT_UI_FG", "DOT_UI_BG", "DOT_UI_WARNING"} {
		t.Setenv(k, "")
	}
	p := LoadPalette()
	if p.Accent != fallback.Accent {
		t.Errorf("Accent=%q want fallback %q", p.Accent, fallback.Accent)
	}
	if p.Success != fallback.Success {
		t.Errorf("Success=%q want fallback %q", p.Success, fallback.Success)
	}
}

func TestLoadPaletteFromEnv(t *testing.T) {
	t.Setenv("DOT_UI_ACCENT", "#1a7f7a")
	t.Setenv("DOT_UI_ERROR", "#e01010")
	p := LoadPalette()
	if p.Accent != "#1a7f7a" {
		t.Errorf("Accent=%q want #1a7f7a", p.Accent)
	}
	if p.Error != "#e01010" {
		t.Errorf("Error=%q want #e01010", p.Error)
	}
	// Unset one stays fallback.
	if p.Success != fallback.Success {
		t.Errorf("Success=%q want fallback", p.Success)
	}
}

func TestNewStyles(t *testing.T) {
	// Smoke: styles build and render without panicking.
	st := NewStyles(LoadPalette())
	if got := st.Ok.Render("✓"); got == "" {
		t.Fatal("Ok style rendered empty")
	}
	if got := st.Logo.Render("dot"); got == "" {
		t.Fatal("Logo style rendered empty")
	}
}
