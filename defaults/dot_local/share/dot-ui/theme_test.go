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

// TestParseColor covers the pure hex validator behind envColor.
func TestParseColor(t *testing.T) {
	fb := lipgloss.Color("#000000")
	cases := []struct {
		in   string
		want lipgloss.Color
	}{
		{"#abc", "#abc"}, {"#ABCDEF", "#ABCDEF"}, {"#1a2b3c", "#1a2b3c"},
		{"", fb}, {"abc", fb}, {"#ab", fb}, {"#abcd", fb}, {"#abcdefg", fb},
		{"#ggg", fb}, {" #abc", fb}, {"#abc\n", fb},
	}
	for _, c := range cases {
		if got := parseColor(c.in, fb); got != c.want {
			t.Errorf("parseColor(%q)=%q want %q", c.in, got, c.want)
		}
	}
}

// TestLoadPaletteAllFields covers every DOT_UI_* variable, including Bg.
func TestLoadPaletteAllFields(t *testing.T) {
	vars := map[string]string{
		"DOT_UI_ACCENT": "#111111", "DOT_UI_SUCCESS": "#222222", "DOT_UI_WARNING": "#333333",
		"DOT_UI_ERROR": "#444444", "DOT_UI_INFO": "#555555", "DOT_UI_PANEL": "#666666",
		"DOT_UI_BORDER": "#777777", "DOT_UI_FG": "#888888", "DOT_UI_BG": "#999999",
	}
	for k, v := range vars {
		t.Setenv(k, v)
	}
	p := LoadPalette()
	got := []lipgloss.Color{p.Accent, p.Success, p.Warning, p.Error, p.Info, p.Panel, p.Border, p.Fg, p.Bg}
	want := []lipgloss.Color{"#111111", "#222222", "#333333", "#444444", "#555555", "#666666", "#777777", "#888888", "#999999"}
	for i := range want {
		if got[i] != want[i] {
			t.Errorf("field %d = %q want %q", i, got[i], want[i])
		}
	}
	// Invalid Bg falls back to the terminal default (empty).
	t.Setenv("DOT_UI_BG", "nope")
	if p := LoadPalette(); p.Bg != "" {
		t.Errorf("invalid Bg should fall back to empty, got %q", p.Bg)
	}
}

// TestNewStylesUsesPalette covers that each style is derived from its
// palette field (render output differs when the palette changes).
func TestNewStylesUsesPalette(t *testing.T) {
	a := NewStyles(fallback)
	p := fallback
	p.Accent, p.Success, p.Error, p.Info, p.Fg, p.Border, p.Warning = "#010101", "#020202", "#030303", "#040404", "#050505", "#060606", "#070707"
	b := NewStyles(p)
	pairs := [][2]lipgloss.Style{
		{a.Logo, b.Logo}, {a.Title, b.Title}, {a.Sub, b.Sub}, {a.Ok, b.Ok}, {a.Skip, b.Skip}, {a.Fail, b.Fail},
		{a.Warn, b.Warn}, {a.Spin, b.Spin}, {a.Label, b.Label}, {a.Detail, b.Detail}, {a.Summary, b.Summary},
		{a.BarFull, b.BarFull}, {a.BarRest, b.BarRest},
	}
	for i, pr := range pairs {
		if pr[0].GetForeground() == pr[1].GetForeground() && pr[0].GetBackground() == pr[1].GetBackground() {
			t.Errorf("style %d does not derive from the palette", i)
		}
	}
}
