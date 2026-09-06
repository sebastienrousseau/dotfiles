// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// Benchmarks — one per function in the module (the model's Update/View,
// every renderer, parser and helper). CI runs them with -benchtime=1x as a
// smoke job; run `go test -bench . -run ^$` for numbers.
package main

import (
	"os/exec"
	"testing"

	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
)

func benchModel() model {
	m := sized()
	m = upd(m, refreshMsg{tools: fleet, costToday: "$1.23", gatewayUp: true, gatewayMsg: "127.0.0.1:3456", recent: []string{"18:00  claude  dotfiles"}})
	m.transcript = []line{
		{who: "you", text: "show me a typed fetch wrapper"},
		{who: "claude", text: "Here:\n```ts\nexport async function getJSON<T>(url: string): Promise<T> {\n  return (await fetch(url)).json();\n}\n```"},
		{who: "sys", text: "model → opus"},
	}
	return m
}

// ── helpers ─────────────────────────────────────────────────────────────────

func BenchmarkClampi(b *testing.B) {
	for i := 0; i < b.N; i++ {
		_ = clampi(i, 0, 10)
	}
}

func BenchmarkGatewayURL(b *testing.B) {
	for i := 0; i < b.N; i++ {
		_ = gatewayURL("127.0.0.1", "3456")
	}
}

func BenchmarkGatewayBase(b *testing.B) {
	b.Setenv("DOT_AI_HOST", "127.0.0.1")
	b.Setenv("DOT_AI_PORT", "3456")
	for i := 0; i < b.N; i++ {
		_ = gatewayBase()
	}
}

func BenchmarkEnvOr(b *testing.B) {
	b.Setenv("DOT_AI_BENCH", "x")
	for i := 0; i < b.N; i++ {
		_ = envOr("DOT_AI_BENCH", "d")
	}
}

func BenchmarkDbPath(b *testing.B) {
	b.Setenv("XDG_DATA_HOME", b.TempDir())
	for i := 0; i < b.N; i++ {
		_ = dbPath()
	}
}

func BenchmarkSessionPath(b *testing.B) {
	b.Setenv("XDG_STATE_HOME", b.TempDir())
	for i := 0; i < b.N; i++ {
		_ = sessionPath()
	}
}

func BenchmarkFilterSqliteOutput(b *testing.B) {
	in := []byte("Run Time: real 0.001\n18:00  claude  dotfiles\n.timer off\n18:01  codex  api\n")
	for i := 0; i < b.N; i++ {
		_ = filterSqliteOutput(in)
	}
}

func BenchmarkSqliteMissingDB(b *testing.B) {
	for i := 0; i < b.N; i++ {
		_ = sqlite("/no/such/db.sqlite", "SELECT 1")
	}
}

func BenchmarkBuildPrompt(b *testing.B) {
	history := benchModel().transcript
	for i := 0; i < b.N; i++ {
		_ = buildPrompt(history, "and now in Go")
	}
}

func BenchmarkModelLabel(b *testing.B) {
	for i := 0; i < b.N; i++ {
		_ = modelLabel("")
		_ = modelLabel("opus")
	}
}

func BenchmarkNextModel(b *testing.B) {
	cur := ""
	for i := 0; i < b.N; i++ {
		cur = nextModel(cur)
	}
}

func BenchmarkNowUnix(b *testing.B) {
	for i := 0; i < b.N; i++ {
		_ = nowUnix()
	}
}

// ── session persistence ─────────────────────────────────────────────────────

func BenchmarkParseSession(b *testing.B) {
	data := []byte(`[{"Who":"you","Text":"hi"},{"Who":"claude","Text":"yo\nthere"}]`)
	for i := 0; i < b.N; i++ {
		_ = parseSession(data)
	}
}

func BenchmarkSaveSession(b *testing.B) {
	b.Setenv("XDG_STATE_HOME", b.TempDir())
	lines := benchModel().transcript
	for i := 0; i < b.N; i++ {
		saveSession(lines)
	}
}

func BenchmarkLoadSession(b *testing.B) {
	b.Setenv("XDG_STATE_HOME", b.TempDir())
	saveSession(benchModel().transcript)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		_ = loadSession()
	}
}

// ── shell-outs (stubbed) ────────────────────────────────────────────────────

func BenchmarkNotifyCmd(b *testing.B) {
	orig := execCommand
	execCommand = func(string, ...string) *exec.Cmd { return exec.Command("true") }
	defer func() { execCommand = orig }()
	for i := 0; i < b.N; i++ {
		_ = notifyCmd("darwin", "dot ai", "reply ready")
		_ = notifyCmd("linux", "dot ai", "reply ready")
	}
}

func BenchmarkNotify(b *testing.B) {
	orig := execCommand
	execCommand = func(string, ...string) *exec.Cmd { return exec.Command("true") }
	defer func() { execCommand = orig }()
	for i := 0; i < b.N; i++ {
		notify("dot ai", "reply ready")
	}
}

func BenchmarkDotExec(b *testing.B) {
	orig := execCommand
	execCommand = func(string, ...string) *exec.Cmd { return exec.Command("true") }
	defer func() { execCommand = orig }()
	for i := 0; i < b.N; i++ {
		_ = dotExec("chat", "claude")
	}
}

func BenchmarkStartStream(b *testing.B) {
	orig := execCommand
	execCommand = func(string, ...string) *exec.Cmd { return exec.Command("printf", "ok") }
	defer func() { execCommand = orig }()
	for i := 0; i < b.N; i++ {
		ch, _ := startStream("claude", "architect", "opus", nil, "hi")
		drain(ch)
	}
}

func BenchmarkWaitForChunk(b *testing.B) {
	ch := make(chan streamMsg, 1)
	for i := 0; i < b.N; i++ {
		ch <- streamMsg{done: true}
		_ = waitForChunk(ch)()
	}
}

func BenchmarkExecDone(b *testing.B) {
	b.Setenv("DOT_AI_HOST", "127.0.0.1")
	b.Setenv("DOT_AI_PORT", "1")
	b.Setenv("XDG_DATA_HOME", b.TempDir())
	for i := 0; i < b.N; i++ {
		_ = execDone(nil)
	}
}

func BenchmarkRefresh(b *testing.B) {
	b.Setenv("DOT_AI_HOST", "127.0.0.1")
	b.Setenv("DOT_AI_PORT", "1")
	b.Setenv("XDG_DATA_HOME", b.TempDir())
	for i := 0; i < b.N; i++ {
		_ = refresh()
	}
}

// ── highlighting ────────────────────────────────────────────────────────────

func BenchmarkHighlight(b *testing.B) {
	text := benchModel().transcript[1].text
	for i := 0; i < b.N; i++ {
		_ = highlight(text)
	}
}

func BenchmarkHighlightProse(b *testing.B) {
	for i := 0; i < b.N; i++ {
		_ = highlight("no fences here, just a sentence of prose")
	}
}

// ── model lifecycle ─────────────────────────────────────────────────────────

func BenchmarkNewModel(b *testing.B) {
	for i := 0; i < b.N; i++ {
		_ = newModel()
	}
}

func BenchmarkModelInit(b *testing.B) {
	m := newModel()
	for i := 0; i < b.N; i++ {
		_ = m.Init()
	}
}

func BenchmarkModelUpdateResize(b *testing.B) {
	m := newModel()
	for i := 0; i < b.N; i++ {
		_, _ = m.Update(tea.WindowSizeMsg{Width: 100 + i%3, Height: 30})
	}
}

func BenchmarkModelUpdateRefresh(b *testing.B) {
	m := sized()
	msg := refreshMsg{tools: fleet, costToday: "$0.00"}
	for i := 0; i < b.N; i++ {
		_, _ = m.Update(msg)
	}
}

func BenchmarkModelUpdateSpinner(b *testing.B) {
	m := sized()
	m.running = true
	for i := 0; i < b.N; i++ {
		_, _ = m.Update(spinner.TickMsg{})
	}
}

func BenchmarkModelUpdateStream(b *testing.B) {
	b.Setenv("XDG_STATE_HOME", b.TempDir())
	m := benchModel()
	m.transcript = append(m.transcript, line{who: "claude"})
	for i := 0; i < b.N; i++ {
		mm := upd(m, streamMsg{chunk: "hello "})
		_ = upd(mm, streamMsg{done: true})
	}
}

func BenchmarkModelUpdateKeyFleet(b *testing.B) {
	m := sized()
	keys := []tea.Msg{key("j"), key("k"), key("m"), key("down"), key("up")}
	for i := 0; i < b.N; i++ {
		for _, k := range keys {
			m = upd(m, k)
		}
	}
}

func BenchmarkModelUpdateKeyInput(b *testing.B) {
	m := upd(sized(), key("tab"))
	keys := []tea.Msg{key("h"), key("i"), key("/"), key("down"), key("esc"), key("esc"), key("tab")}
	for i := 0; i < b.N; i++ {
		mm := m
		for _, k := range keys {
			mm = upd(mm, k)
		}
	}
}

func BenchmarkUpdateFleet(b *testing.B) {
	m := sized()
	for i := 0; i < b.N; i++ {
		_, _ = m.updateFleet(key("j"))
	}
}

func BenchmarkUpdateInput(b *testing.B) {
	m := upd(sized(), key("tab"))
	for i := 0; i < b.N; i++ {
		_, _ = m.updateInput(key("x"))
	}
}

func BenchmarkHandleSlash(b *testing.B) {
	m := sized()
	for i := 0; i < b.N; i++ {
		_, _ = m.handleSlash("/model opus")
		_, _ = m.handleSlash("/help")
	}
}

func BenchmarkPalette(b *testing.B) {
	m := upd(sized(), key("tab"))
	m.input.SetValue("/m")
	for i := 0; i < b.N; i++ {
		_ = m.palette()
	}
}

func BenchmarkRenderPalette(b *testing.B) {
	m := upd(sized(), key("tab"))
	m.input.SetValue("/")
	pal := m.palette()
	for i := 0; i < b.N; i++ {
		_ = m.renderPalette(pal, 60)
	}
}

func BenchmarkLeftWidth(b *testing.B) {
	m := sized()
	for i := 0; i < b.N; i++ {
		_ = m.leftWidth()
	}
}

func BenchmarkRightWidth(b *testing.B) {
	m := sized()
	for i := 0; i < b.N; i++ {
		_ = m.rightWidth()
	}
}

func BenchmarkModelView(b *testing.B) {
	m := benchModel()
	for i := 0; i < b.N; i++ {
		_ = m.View()
	}
}

func BenchmarkModelViewPalette(b *testing.B) {
	m := upd(benchModel(), key("tab"))
	m.input.SetValue("/")
	for i := 0; i < b.N; i++ {
		_ = m.View()
	}
}

func BenchmarkWindowRows(b *testing.B) {
	rows := make([]string, 40)
	for i := 0; i < b.N; i++ {
		_ = windowRows(rows, 25, 12)
	}
}

func BenchmarkSplash(b *testing.B) {
	m := sized()
	for i := 0; i < b.N; i++ {
		_ = m.splash(60, 20)
	}
}

func BenchmarkRenderTranscript(b *testing.B) {
	m := benchModel()
	for i := 0; i < b.N; i++ {
		_ = m.renderTranscript(70, 18)
	}
}

func BenchmarkRenderTranscriptSplash(b *testing.B) {
	m := sized()
	m.recent = []string{"18:00  claude  dotfiles"}
	for i := 0; i < b.N; i++ {
		_ = m.renderTranscript(70, 18)
	}
}

func BenchmarkRenderSnapshot(b *testing.B) {
	b.Setenv("DOT_AI_HOST", "127.0.0.1")
	b.Setenv("DOT_AI_PORT", "1")
	b.Setenv("XDG_DATA_HOME", b.TempDir())
	b.Setenv("DOT_AI_SPLASH", "")
	for i := 0; i < b.N; i++ {
		renderSnapshot()
	}
}

func BenchmarkRunSnapshot(b *testing.B) {
	b.Setenv("DOT_AI_SNAPSHOT", "1")
	b.Setenv("DOT_AI_HOST", "127.0.0.1")
	b.Setenv("DOT_AI_PORT", "1")
	b.Setenv("XDG_DATA_HOME", b.TempDir())
	for i := 0; i < b.N; i++ {
		_ = run()
	}
}

func BenchmarkMainSnapshot(b *testing.B) {
	b.Setenv("DOT_AI_SNAPSHOT", "1")
	b.Setenv("DOT_AI_HOST", "127.0.0.1")
	b.Setenv("DOT_AI_PORT", "1")
	b.Setenv("XDG_DATA_HOME", b.TempDir())
	for i := 0; i < b.N; i++ {
		main()
	}
}

func BenchmarkResolveLang(b *testing.B) {
	for i := 0; i < b.N; i++ {
		_ = resolveLang("ts")
		_ = resolveLang("no-such-lang")
	}
}
