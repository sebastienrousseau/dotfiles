// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// Benchmarks — one per function in the module (every exported function,
// every model's Update/View, and each parser/renderer). CI runs them with
// -benchtime=1x as a smoke job; run `go test -bench . -run ^$` for numbers.
package main

import (
	"io"
	"os"
	"strings"
	"testing"

	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
)

const benchStream = `{"t":"header","title":"dot theme","subtitle":"pulse"}
{"t":"step","id":"ghostty","label":"Ghostty","state":"run","detail":"reloading…"}
{"t":"step","id":"ghostty","state":"ok","detail":"reloaded"}
{"t":"step","id":"tmux","label":"tmux","state":"skip"}
{"t":"step","id":"nvim","label":"Neovim","state":"fail","detail":"boom"}
{"t":"progress","cur":3,"total":12}
{"t":"wait","label":"refreshing all Spaces…"}
{"t":"done","elapsed_ms":1618,"summary":"reloaded desktop, wallpaper"}`

func benchItems() []string {
	items := make([]string, 0, 200)
	for i := 0; i < 200; i++ {
		items = append(items, strings.Repeat("theme-", i%5)+"variant-dark")
	}
	return items
}

// ── theme.go ────────────────────────────────────────────────────────────────

func BenchmarkLoadPalette(b *testing.B) {
	b.Setenv("DOT_UI_ACCENT", "#1a7f7a")
	for i := 0; i < b.N; i++ {
		_ = LoadPalette()
	}
}

func BenchmarkNewStyles(b *testing.B) {
	p := LoadPalette()
	for i := 0; i < b.N; i++ {
		_ = NewStyles(p)
	}
}

func BenchmarkParseColor(b *testing.B) {
	for i := 0; i < b.N; i++ {
		_ = parseColor("#7D56F4", fallback.Accent)
		_ = parseColor("teal", fallback.Accent)
	}
}

func BenchmarkEnvColor(b *testing.B) {
	b.Setenv("DOT_UI_BENCH", "#7D56F4")
	for i := 0; i < b.N; i++ {
		_ = envColor("DOT_UI_BENCH", fallback.Accent)
	}
}

// ── run.go ──────────────────────────────────────────────────────────────────

func BenchmarkParseEvent(b *testing.B) {
	line := `{"t":"step","id":"ghostty","label":"Ghostty","state":"ok","detail":"reloaded"}`
	for i := 0; i < b.N; i++ {
		_, _ = parseEvent(line)
	}
}

func BenchmarkNewStepModel(b *testing.B) {
	st := NewStyles(LoadPalette())
	for i := 0; i < b.N; i++ {
		_ = newStepModel(st)
	}
}

func BenchmarkStepInit(b *testing.B) {
	m := newTestModel()
	for i := 0; i < b.N; i++ {
		_ = m.Init()
	}
}

func BenchmarkStepApply(b *testing.B) {
	var events []Event
	for _, ln := range strings.Split(benchStream, "\n") {
		if e, ok := parseEvent(ln); ok {
			events = append(events, e)
		}
	}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		m := newTestModel()
		for _, e := range events {
			m.apply(e)
		}
	}
}

func BenchmarkStepUpdate(b *testing.B) {
	m := newTestModel()
	msgs := []tea.Msg{
		eventMsg{T: "step", ID: "a", Label: "A", State: "run"},
		eventMsg{T: "step", ID: "a", State: "ok"},
		m.sp.Tick(),
		tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'x'}},
	}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		var mm tea.Model = m
		for _, msg := range msgs {
			mm, _ = mm.Update(msg)
		}
	}
}

func BenchmarkStepUpdateSpinnerTick(b *testing.B) {
	m := newTestModel()
	tick := m.sp.Tick().(spinner.TickMsg)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_, _ = m.Update(tick)
	}
}

func BenchmarkStepView(b *testing.B) {
	m := newTestModel()
	for _, ln := range strings.Split(benchStream, "\n") {
		if e, ok := parseEvent(ln); ok && e.T != "done" {
			m.apply(e)
		}
	}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = m.View()
	}
}

func BenchmarkRenderStep(b *testing.B) {
	m := newTestModel()
	m.labelW = 8
	s := step{id: "a", label: "Ghostty", state: "ok", detail: "reloaded"}
	for i := 0; i < b.N; i++ {
		_ = m.renderStep(s)
	}
}

func BenchmarkRenderBar(b *testing.B) {
	m := newTestModel()
	m.cur, m.total = 7, 12
	for i := 0; i < b.N; i++ {
		_ = m.renderBar()
	}
}

func BenchmarkSnapshotStep(b *testing.B) {
	st := NewStyles(LoadPalette())
	for i := 0; i < b.N; i++ {
		_ = snapshotStep(st, strings.NewReader(benchStream), io.Discard)
	}
}

func BenchmarkRunStepNonInteractive(b *testing.B) {
	st := NewStyles(LoadPalette())
	for i := 0; i < b.N; i++ {
		_ = runStep(st, strings.NewReader(benchStream), nil, io.Discard, false)
	}
}

// ── pick.go ─────────────────────────────────────────────────────────────────

func BenchmarkFuzzyMatch(b *testing.B) {
	for i := 0; i < b.N; i++ {
		_ = fuzzyMatch("altai-dark-variant-with-long-name", "advl")
	}
}

func BenchmarkNewPickModel(b *testing.B) {
	st := NewStyles(LoadPalette())
	items := benchItems()
	for i := 0; i < b.N; i++ {
		_ = newPickModel(st, "h", "p", items)
	}
}

func BenchmarkPickRefilter(b *testing.B) {
	m := newPickModel(NewStyles(LoadPalette()), "h", "p", benchItems())
	m.query = "vd"
	for i := 0; i < b.N; i++ {
		m.refilter()
	}
}

func BenchmarkPickInit(b *testing.B) {
	m := newTestPick()
	for i := 0; i < b.N; i++ {
		_ = m.Init()
	}
}

func BenchmarkPickUpdate(b *testing.B) {
	m := newPickModel(NewStyles(LoadPalette()), "h", "p", benchItems())
	keys := []tea.Msg{key("d"), key("down"), key("down"), key("up"), key("backspace"), tea.WindowSizeMsg{Width: 80, Height: 24}}
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		var mm tea.Model = m
		for _, k := range keys {
			mm, _ = mm.Update(k)
		}
	}
}

func BenchmarkPickView(b *testing.B) {
	m := newPickModel(NewStyles(LoadPalette()), "Pick a theme", "Theme >", benchItems())
	m.height = 24
	for i := 0; i < b.N; i++ {
		_ = m.View()
	}
}

func BenchmarkPickVisibleRows(b *testing.B) {
	m := newTestPick()
	for i := 0; i < b.N; i++ {
		_ = m.visibleRows()
	}
}

func BenchmarkPickClampScroll(b *testing.B) {
	m := newPickModel(NewStyles(LoadPalette()), "", "", benchItems())
	m.cursor = 150
	for i := 0; i < b.N; i++ {
		m.offset = 0
		m.clampScroll()
	}
}

func BenchmarkReadItems(b *testing.B) {
	in := strings.Join(benchItems(), "\n") + "\n"
	for i := 0; i < b.N; i++ {
		_ = readItems(strings.NewReader(in))
	}
}

func BenchmarkRunPickNonInteractive(b *testing.B) {
	st := NewStyles(LoadPalette())
	in := strings.Join(benchItems(), "\n")
	for i := 0; i < b.N; i++ {
		_, _ = runPick(st, "h", "p", strings.NewReader(in), nil, true)
	}
}

// ── table.go ────────────────────────────────────────────────────────────────

func BenchmarkRunTable(b *testing.B) {
	var sb strings.Builder
	sb.WriteString("Alias\x1fExpands\x1fTier\n")
	for i := 0; i < 50; i++ {
		sb.WriteString("ll\x1fls -alFh\x1fcore\n")
	}
	in := sb.String()
	p := LoadPalette()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = runTable(p, strings.NewReader(in), io.Discard)
	}
}

// ── main.go ─────────────────────────────────────────────────────────────────

func BenchmarkDispatchVersion(b *testing.B) {
	for i := 0; i < b.N; i++ {
		_ = dispatch([]string{"--version"}, strings.NewReader(""), io.Discard, io.Discard)
	}
}

func BenchmarkDispatchRunSnapshot(b *testing.B) {
	b.Setenv("DOT_UI_SNAPSHOT", "1")
	for i := 0; i < b.N; i++ {
		_ = dispatch([]string{"run"}, strings.NewReader(benchStream), io.Discard, io.Discard)
	}
}

func BenchmarkDispatchTable(b *testing.B) {
	for i := 0; i < b.N; i++ {
		_ = dispatch([]string{"table"}, strings.NewReader("H\x1fI\nv\x1fw\n"), io.Discard, io.Discard)
	}
}

func BenchmarkCmdRunSnapshot(b *testing.B) {
	b.Setenv("DOT_UI_SNAPSHOT", "1")
	st := NewStyles(LoadPalette())
	for i := 0; i < b.N; i++ {
		_ = cmdRun(st, strings.NewReader(benchStream), io.Discard)
	}
}

func BenchmarkCmdPickSnapshot(b *testing.B) {
	b.Setenv("DOT_UI_SNAPSHOT", "1")
	st := NewStyles(LoadPalette())
	for i := 0; i < b.N; i++ {
		_ = cmdPick(st, []string{"--header", "H"}, strings.NewReader("a\nb\n"), io.Discard)
	}
}

func BenchmarkParsePickArgs(b *testing.B) {
	args := []string{"--header", "Pick a theme", "--prompt", "Theme >"}
	for i := 0; i < b.N; i++ {
		_, _ = parsePickArgs(args)
	}
}

func BenchmarkSnapshotMode(b *testing.B) {
	b.Setenv("DOT_UI_SNAPSHOT", "1")
	for i := 0; i < b.N; i++ {
		_ = snapshotMode()
	}
}

func BenchmarkIsTTY(b *testing.B) {
	r, w, err := os.Pipe()
	if err != nil {
		b.Fatal(err)
	}
	defer r.Close()
	defer w.Close()
	for i := 0; i < b.N; i++ {
		_ = isTTY(r)
	}
}
