// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// Palette + lipgloss styles for dot-ui.
//
// Colors are sourced from the active wallpaper theme via DOT_UI_* environment
// variables (exported by lib/dot/ui.sh from .chezmoidata/themes.toml). When a
// variable is unset or not a valid hex color, a fixed "signature" fallback is
// used so the binary still renders correctly in CI and on first install. The
// fallback deliberately matches dot-ai-tui's palette for cross-binary
// consistency.
package main

import (
	"os"
	"regexp"

	"github.com/charmbracelet/lipgloss"
)

// hexRe matches #rgb and #rrggbb.
var hexRe = regexp.MustCompile(`^#[0-9a-fA-F]{3}([0-9a-fA-F]{3})?$`)

// Palette holds the resolved colors used across every dot-ui view.
type Palette struct {
	Accent  lipgloss.Color // primary highlight: spinner, header chip, selection
	Success lipgloss.Color // ✓
	Warning lipgloss.Color // ⚠
	Error   lipgloss.Color // ✗
	Info    lipgloss.Color // · / muted detail
	Panel   lipgloss.Color // panel background
	Border  lipgloss.Color // borders
	Fg      lipgloss.Color // foreground text
	Bg      lipgloss.Color // background ("" = terminal default)
}

// fallback is the fixed signature palette (violet family), used per-field
// whenever the matching DOT_UI_* env var is missing or invalid.
var fallback = Palette{
	Accent:  "#7D56F4",
	Success: "#56D364",
	Warning: "#F2C14E",
	Error:   "#FF6E6E",
	Info:    "#8A8AA8",
	Panel:   "#322A4A",
	Border:  "#322A4A",
	Fg:      "#EDEDFB",
	Bg:      "",
}

// envColor returns a validated hex color from env, or the fallback.
func envColor(key string, fb lipgloss.Color) lipgloss.Color {
	v := os.Getenv(key)
	if v != "" && hexRe.MatchString(v) {
		return lipgloss.Color(v)
	}
	return fb
}

// LoadPalette resolves the palette from DOT_UI_* env vars with per-field
// fallback. Bg is allowed to be empty (terminal default) even in fallback.
func LoadPalette() Palette {
	return Palette{
		Accent:  envColor("DOT_UI_ACCENT", fallback.Accent),
		Success: envColor("DOT_UI_SUCCESS", fallback.Success),
		Warning: envColor("DOT_UI_WARNING", fallback.Warning),
		Error:   envColor("DOT_UI_ERROR", fallback.Error),
		Info:    envColor("DOT_UI_INFO", fallback.Info),
		Panel:   envColor("DOT_UI_PANEL", fallback.Panel),
		Border:  envColor("DOT_UI_BORDER", fallback.Border),
		Fg:      envColor("DOT_UI_FG", fallback.Fg),
		Bg:      envColor("DOT_UI_BG", fallback.Bg),
	}
}

// Styles bundles the lipgloss styles derived from a Palette.
type Styles struct {
	Logo    lipgloss.Style // logo chip (fg on accent)
	Title   lipgloss.Style // header title
	Sub     lipgloss.Style // header subtitle
	Ok      lipgloss.Style // ✓ symbol
	Skip    lipgloss.Style // · symbol
	Fail    lipgloss.Style // ✗ symbol
	Warn    lipgloss.Style // ⚠ symbol
	Spin    lipgloss.Style // spinner frame
	Label   lipgloss.Style // step label
	Detail  lipgloss.Style // step detail (dim)
	Summary lipgloss.Style // final summary line
	BarFull lipgloss.Style // progress bar filled
	BarRest lipgloss.Style // progress bar empty
}

// NewStyles builds the style set for a palette.
func NewStyles(p Palette) Styles {
	return Styles{
		Logo:    lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("#FFFFFF")).Background(p.Accent).Padding(0, 1),
		Title:   lipgloss.NewStyle().Bold(true).Foreground(p.Fg),
		Sub:     lipgloss.NewStyle().Foreground(p.Info),
		Ok:      lipgloss.NewStyle().Bold(true).Foreground(p.Success),
		Skip:    lipgloss.NewStyle().Foreground(p.Info),
		Fail:    lipgloss.NewStyle().Bold(true).Foreground(p.Error),
		Warn:    lipgloss.NewStyle().Bold(true).Foreground(p.Warning),
		Spin:    lipgloss.NewStyle().Foreground(p.Accent),
		Label:   lipgloss.NewStyle().Foreground(p.Fg),
		Detail:  lipgloss.NewStyle().Foreground(p.Info),
		Summary: lipgloss.NewStyle().Bold(true).Foreground(p.Success),
		BarFull: lipgloss.NewStyle().Foreground(p.Accent),
		BarRest: lipgloss.NewStyle().Foreground(p.Border),
	}
}