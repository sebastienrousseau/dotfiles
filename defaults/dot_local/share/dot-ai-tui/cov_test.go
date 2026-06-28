// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
package main

import (
	"database/sql"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
)

// ── helpers ─────────────────────────────────────────────────────────────────
func key(s string) tea.KeyMsg {
	switch s {
	case "enter":
		return tea.KeyMsg{Type: tea.KeyEnter}
	case "tab":
		return tea.KeyMsg{Type: tea.KeyTab}
	case "esc":
		return tea.KeyMsg{Type: tea.KeyEsc}
	case "up":
		return tea.KeyMsg{Type: tea.KeyUp}
	case "down":
		return tea.KeyMsg{Type: tea.KeyDown}
	case "ctrl+c":
		return tea.KeyMsg{Type: tea.KeyCtrlC}
	case "ctrl+p":
		return tea.KeyMsg{Type: tea.KeyCtrlP}
	case "ctrl+n":
		return tea.KeyMsg{Type: tea.KeyCtrlN}
	default:
		return tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune(s)}
	}
}

func upd(m model, msg tea.Msg) model {
	mm, _ := m.Update(msg)
	return mm.(model)
}

func sized() model {
	m := newModel()
	m = upd(m, tea.WindowSizeMsg{Width: 100, Height: 30})
	return m
}

func drain(ch chan streamMsg) string {
	var s string
	for {
		m := <-ch
		s += m.chunk
		if m.done {
			return s
		}
	}
}

// ── pure helpers ────────────────────────────────────────────────────────────
func TestPureHelpers(t *testing.T) {
	if clampi(-1, 0, 5) != 0 || clampi(9, 0, 5) != 5 || clampi(3, 0, 5) != 3 {
		t.Fatal("clampi")
	}
	t.Setenv("DOT_AI_HOST", "")
	t.Setenv("DOT_AI_PORT", "")
	if gatewayBase() != "http://127.0.0.1:3456" {
		t.Fatal("gatewayBase default")
	}
	t.Setenv("DOT_AI_HOST", "h")
	t.Setenv("DOT_AI_PORT", "9")
	if gatewayBase() != "http://h:9" {
		t.Fatal("gatewayBase env")
	}
	if envOr("DOT_AI_HOST", "x") != "h" || envOr("NOPE_VAR_X", "x") != "x" {
		t.Fatal("envOr")
	}
	t.Setenv("XDG_DATA_HOME", "/tmp/xdg")
	if dbPath() != "/tmp/xdg/dotfiles-ai.db" {
		t.Fatal("dbPath xdg")
	}
	t.Setenv("XDG_DATA_HOME", "")
	if !strings.HasSuffix(dbPath(), ".local/share/dotfiles-ai.db") {
		t.Fatal("dbPath home")
	}
	m := sized()
	if m.leftWidth() < 18 || m.leftWidth() > 26 || m.rightWidth() <= 0 {
		t.Fatal("widths")
	}
	narrow := newModel()
	narrow = upd(narrow, tea.WindowSizeMsg{Width: 10, Height: 30})
	if narrow.leftWidth() != 18 {
		t.Fatal("leftWidth floor")
	}
	wide := newModel()
	wide = upd(wide, tea.WindowSizeMsg{Width: 400, Height: 30})
	if wide.leftWidth() != 26 {
		t.Fatal("leftWidth cap")
	}
	if len(windowRows([]string{"a", "b"}, 0, 5)) != 2 {
		t.Fatal("windowRows small")
	}
	if got := windowRows([]string{"a", "b", "c", "d", "e"}, 4, 2); len(got) != 2 || got[1] != "e" {
		t.Fatalf("windowRows tail: %v", got)
	}
	if len(windowRows([]string{"a", "b", "c", "d"}, 0, 0)) != 1 {
		t.Fatal("windowRows h<1")
	}
}

func TestBuildPrompt(t *testing.T) {
	if buildPrompt(nil, "hi") != "hi" {
		t.Fatal("no history → raw")
	}
	out := buildPrompt([]line{{who: "you", text: "a"}, {who: "claude", text: "b"}, {who: "sys", text: "skip"}, {who: "you", text: ""}}, "next")
	if !strings.Contains(out, "User: a") || !strings.Contains(out, "Assistant: b") || strings.Contains(out, "skip") || !strings.Contains(out, "User: next") {
		t.Fatalf("buildPrompt: %q", out)
	}
}

// ── sqlite + refresh ────────────────────────────────────────────────────────
func seedDB(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	db := filepath.Join(dir, "dotfiles-ai.db")
	d, err := sql.Open("sqlite", db)
	if err != nil { // driver not linked: create via the sqlite3 CLI instead
		out := filepath.Join(dir, "dotfiles-ai.db")
		_ = exec.Command("sqlite3", out, "CREATE TABLE runs(id INTEGER PRIMARY KEY, ts TEXT, delegate TEXT, project TEXT, cost_usd REAL); INSERT INTO runs(ts,delegate,project,cost_usd) VALUES('2026-06-27T18:00:00Z','claude','dotfiles',0.04);").Run()
		return out
	}
	defer d.Close()
	d.Exec("CREATE TABLE runs(id INTEGER PRIMARY KEY, ts TEXT, delegate TEXT, project TEXT, cost_usd REAL)")
	d.Exec("INSERT INTO runs(ts,delegate,project,cost_usd) VALUES('2026-06-27T18:00:00Z','claude','dotfiles',0.04)")
	return db
}

func TestSqlite(t *testing.T) {
	if sqlite("/no/such/db.sqlite", "SELECT 1") != "" {
		t.Fatal("missing db should yield empty")
	}
	db := seedDB(t)
	if _, err := os.Stat(db); err != nil {
		t.Skip("could not seed db")
	}
	if got := sqlite(db, "SELECT delegate FROM runs;"); got != "claude" {
		t.Fatalf("sqlite query: %q", got)
	}
}

func TestRefresh(t *testing.T) {
	// gateway down (default port unlikely to answer "healthy")
	t.Setenv("DOT_AI_HOST", "127.0.0.1")
	t.Setenv("DOT_AI_PORT", "1") // refused
	_ = refresh()

	// gateway up via a stub server + a seeded db
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, `{"status":"healthy"}`)
	}))
	defer srv.Close()
	host, port, _ := strings.Cut(strings.TrimPrefix(srv.URL, "http://"), ":")
	t.Setenv("DOT_AI_HOST", host)
	t.Setenv("DOT_AI_PORT", port)
	db := seedDB(t)
	t.Setenv("XDG_DATA_HOME", filepath.Dir(db))
	msg, ok := refresh().(refreshMsg)
	if !ok || !msg.gatewayUp {
		t.Fatalf("expected healthy gateway: %+v", msg)
	}
}

// ── streaming + commands ────────────────────────────────────────────────────
func TestStartStreamAndExec(t *testing.T) {
	orig := execCommand
	defer func() { execCommand = orig }()

	execCommand = func(name string, args ...string) *exec.Cmd { return exec.Command("printf", "hello world") }
	ch, cmd := startStream("claude", "", "", nil, "hi")
	if cmd == nil {
		t.Fatal("nil cmd")
	}
	if got := drain(ch); !strings.Contains(got, "hello") {
		t.Fatalf("stream: %q", got)
	}
	// error path (Start fails) + style + history branches
	execCommand = func(name string, args ...string) *exec.Cmd { return exec.Command("/no/such/binary/xyz") }
	ch2, _ := startStream("codex", "architect", "opus", []line{{who: "you", text: "a"}, {who: "codex", text: "b"}}, "go")
	drain(ch2)

	if dotExec("serve") == nil { // dotExec returns a tea.Cmd
		t.Fatal("dotExec nil")
	}
	if waitForChunk(make(chan streamMsg, 1)) == nil {
		t.Fatal("waitForChunk nil")
	}
	if newModel().Init() == nil {
		t.Fatal("Init nil")
	}
}

// ── Update / key routing ────────────────────────────────────────────────────
func TestUpdateMsgs(t *testing.T) {
	m := sized()
	// spinner tick while running (and not running)
	m.running = true
	m = upd(m, spinner.TickMsg{})
	m.running = false
	m = upd(m, spinner.TickMsg{})
	// streamMsg variants
	m.transcript = []line{{who: "you", text: "q"}, {who: "claude", text: ""}}
	m = upd(m, streamMsg{chunk: "hel"})
	m = upd(m, streamMsg{chunk: "lo"})
	if m.transcript[len(m.transcript)-1].text != "hello" {
		t.Fatal("stream chunks not appended")
	}
	m = upd(m, streamMsg{done: true})
	if m.running {
		t.Fatal("done should stop running")
	}
	// done with empty body → placeholder
	m.transcript = []line{{who: "claude", text: ""}}
	m = upd(m, streamMsg{done: true})
	if !strings.Contains(m.transcript[0].text, "no output") {
		t.Fatal("empty done placeholder")
	}
	// error
	m.transcript = []line{{who: "claude", text: ""}}
	m = upd(m, streamMsg{err: fmt.Errorf("boom")})
	if !strings.Contains(m.transcript[0].text, "boom") {
		t.Fatal("error not surfaced")
	}
	// streamMsg with empty transcript
	m.transcript = nil
	upd(m, streamMsg{chunk: "x"})
	// ctrl+c quits
	if _, c := sized().Update(key("ctrl+c")); c == nil {
		t.Fatal("ctrl+c should quit")
	}
	// tab: fleet→input, input→fleet, input+palette→complete
	m = sized()
	m = upd(m, key("tab"))
	if m.focus != "input" {
		t.Fatal("tab to input")
	}
	m = upd(m, key("tab"))
	if m.focus != "fleet" {
		t.Fatal("tab back to fleet")
	}
	m = upd(m, key("tab")) // input
	m.input.SetValue("/")
	m = upd(m, key("tab")) // palette open → completes, stays input
	if m.focus != "input" {
		t.Fatal("tab with palette should stay input")
	}
}

func TestUpdateFleet(t *testing.T) {
	m := sized() // focus fleet
	m = upd(m, key("j"))
	if m.cursor != 1 {
		t.Fatal("j")
	}
	m = upd(m, key("k"))
	if m.cursor != 0 {
		t.Fatal("k")
	}
	m = upd(m, key("k")) // at top, no-op
	for i := 0; i < len(fleet)+3; i++ {
		m = upd(m, key("down"))
	}
	if m.cursor != len(fleet)-1 {
		t.Fatal("down clamp")
	}
	m = upd(m, key("up"))
	// enter → open session (returns a cmd)
	if _, c := m.Update(key("enter")); c == nil {
		t.Fatal("enter should open session")
	}
	// "/" focuses input and prefills
	m2 := upd(m, key("/"))
	if m2.focus != "input" || m2.input.Value() != "/" {
		t.Fatalf("/ prefill: focus=%s val=%q", m2.focus, m2.input.Value())
	}
	upd(m, key("p")) // also focuses input
	upd(m, key("c")) // refresh
	upd(m, key("r"))
	if _, c := m.Update(key("i")); c == nil {
		t.Fatal("i install")
	}
	if _, c := m.Update(key("s")); c == nil {
		t.Fatal("s serve")
	}
	mUp := m
	mUp.gatewayUp = true
	if _, c := mUp.Update(key("s")); c == nil {
		t.Fatal("s serve-stop")
	}
	if _, c := m.Update(key("q")); c == nil {
		t.Fatal("q quit")
	}
	if _, c := m.Update(key("esc")); c == nil {
		t.Fatal("esc quit")
	}
}

func TestUpdateInput(t *testing.T) {
	base := func() model {
		m := sized()
		m = upd(m, key("tab")) // → input
		return m
	}
	// typing
	m := base()
	m = upd(m, key("h"))
	// esc with no palette → fleet
	m = upd(m, key("esc"))
	if m.focus != "fleet" {
		t.Fatal("esc to fleet")
	}
	// esc with palette open → clears
	m = base()
	m.input.SetValue("/he")
	m = upd(m, key("esc"))
	if m.input.Value() != "" {
		t.Fatal("esc should clear palette input")
	}
	// palette navigation
	m = base()
	m.input.SetValue("/")
	m = upd(m, key("down"))
	if m.palSel != 1 {
		t.Fatal("palette down")
	}
	m = upd(m, key("up"))
	if m.palSel != 0 {
		t.Fatal("palette up")
	}
	m = upd(m, key("ctrl+n"))
	m = upd(m, key("ctrl+p"))
	// tab completes
	m.input.SetValue("/sty")
	m = upd(m, key("tab"))
	if !strings.HasPrefix(m.input.Value(), "/style") {
		t.Fatalf("tab complete: %q", m.input.Value())
	}
	// enter on a cockpit palette item (/clear)
	m = base()
	m.transcript = []line{{who: "you", text: "x"}}
	m.input.SetValue("/clear")
	m = upd(m, key("enter"))
	if len(m.transcript) != 0 {
		t.Fatal("palette enter /clear")
	}
	// enter on a session palette item → opens session (cmd) + sys note
	m = base()
	m.input.SetValue("/compact")
	mm, c := m.Update(key("enter"))
	if c == nil || len(mm.(model).transcript) == 0 {
		t.Fatal("palette enter session")
	}
	// enter empty → no-op
	m = base()
	if _, c := m.Update(key("enter")); c != nil {
		t.Fatal("empty enter")
	}
	// enter a slash command directly (with arg → palette empty)
	m = base()
	m.input.SetValue("/style architect")
	m = upd(m, key("enter"))
	if m.style != "architect" {
		t.Fatal("direct slash with arg")
	}
	// enter a normal prompt → streams (cmd) while not running
	orig := execCommand
	execCommand = func(name string, args ...string) *exec.Cmd { return exec.Command("printf", "ok") }
	defer func() { execCommand = orig }()
	m = base()
	m.input.SetValue("hello there")
	mm2, c := m.Update(key("enter"))
	if c == nil || !mm2.(model).running {
		t.Fatal("normal send should stream")
	}
	// enter while running → ignored
	mr := mm2.(model)
	mr.input.SetValue("again")
	if _, c := mr.Update(key("enter")); c != nil {
		t.Fatal("send while running ignored")
	}
}

func TestHandleSlashAll(t *testing.T) {
	m := sized()
	for _, c := range []string{"/help", "/?", "/serve", "/cost", "/style x", "/style", "/style off", "/tool codex", "/tool nope", "/bogus"} {
		m, _ = func() (model, tea.Cmd) { mm, cmd := m.handleSlash(c); return mm.(model), cmd }()
	}
	if mm, _ := m.handleSlash("/clear"); len(mm.(model).transcript) != 0 {
		t.Fatal("/clear")
	}
	for _, q := range []string{"/quit", "/q", "/exit"} {
		if _, c := m.handleSlash(q); c == nil {
			t.Fatalf("%s should quit", q)
		}
	}
}

// ── render paths ────────────────────────────────────────────────────────────
func TestRenderPaths(t *testing.T) {
	// loading guards
	if !strings.Contains(newModel().View(), "loading") {
		t.Fatal("unsized → loading")
	}
	tiny := newModel()
	tiny = upd(tiny, tea.WindowSizeMsg{Width: 20, Height: 6})
	if !strings.Contains(tiny.View(), "loading") {
		t.Fatal("tiny → loading")
	}
	// full render: fleet focus, gateway up, style, transcript with code
	m := sized()
	m.gatewayUp = true
	m.gatewayMsg = "127.0.0.1:3456"
	m.costToday = "$1.23"
	m.style = "architect"
	m.recent = []string{"18:00 claude dotfiles"}
	m.status = "refreshing…"
	if v := m.View(); !strings.Contains(v, "dot ai") {
		t.Fatal("fleet view")
	}
	// input focus + palette + running
	m = upd(m, key("tab"))
	m.input.SetValue("/")
	m.running = true
	m.transcript = []line{{who: "you", text: "x"}, {who: "claude", text: "```go\nvar x = 1\n```"}, {who: "sys", text: "note"}}
	if v := m.View(); v == "" {
		t.Fatal("input/palette/running view")
	}
	// renderTranscript empty + with recent
	empty := sized()
	empty.recent = []string{"a", "b"}
	_ = empty.renderTranscript(40, 5)
	// renderPalette directly (session row + selected)
	p := sized()
	_ = p.renderPalette([]paletteItem{{"/help", "h", "cockpit"}, {"/compact", "c", "session"}}, 50)
}

func TestRunSnapshot(t *testing.T) {
	t.Setenv("DOT_AI_SNAPSHOT", "1")
	if err := run(); err != nil {
		t.Fatalf("snapshot run: %v", err)
	}
}

// ── close remaining coverable gaps ──────────────────────────────────────────
func TestCoverageGaps(t *testing.T) {
	// palette dedup: copilot's /clear is shadowed by the cockpit /clear.
	m := sized()
	m = upd(m, key("tab"))
	for i, tl := range fleet {
		if tl.name == "copilot" {
			m.cursor = i
		}
	}
	m.input.SetValue("/clear")
	n := 0
	for _, it := range m.palette() {
		if it.label == "/clear" {
			n++
		}
	}
	if n != 1 {
		t.Fatalf("dedup: expected one /clear, got %d", n)
	}

	// renderPalette with the selected row being a session command.
	p := sized()
	p.palSel = 1
	_ = p.renderPalette([]paletteItem{{"/help", "h", "cockpit"}, {"/compact", "c", "session"}}, 60)

	// windowRows start<0 clamp.
	if got := windowRows([]string{"a", "b", "c", "d", "e"}, 0, 3); len(got) != 3 || got[0] != "a" {
		t.Fatalf("windowRows start<0: %v", got)
	}

	// sqlite skip-lines (".pragma"/"Run Time:" filtered).
	db := seedDB(t)
	if _, err := os.Stat(db); err == nil {
		if got := sqlite(db, "SELECT '.x' UNION ALL SELECT 'Run Time: y' UNION ALL SELECT 'keep';"); got != "keep" {
			t.Fatalf("sqlite skip-lines: %q", got)
		}
	}

	// refresh with an empty data dir → cost "$0.00" + no recent.
	t.Setenv("XDG_DATA_HOME", t.TempDir())
	t.Setenv("DOT_AI_HOST", "127.0.0.1")
	t.Setenv("DOT_AI_PORT", "1")
	if msg := refresh().(refreshMsg); msg.costToday != "$0.00" || len(msg.recent) != 0 {
		t.Fatalf("empty-db refresh: %+v", msg)
	}

	// waitForChunk closure actually reads the channel.
	ch := make(chan streamMsg, 1)
	ch <- streamMsg{done: true}
	if msg := waitForChunk(ch)(); !msg.(streamMsg).done {
		t.Fatal("waitForChunk closure")
	}
}

// run()'s non-snapshot branch starts the TUI; with no TTY it returns promptly.
func TestRunNoTTY(t *testing.T) {
	os.Unsetenv("DOT_AI_SNAPSHOT")
	done := make(chan error, 1)
	go func() { done <- run() }()
	select {
	case <-done: // returned (an error in a headless env) — branch covered
	case <-time.After(3 * time.Second):
		t.Skip("run() did not return (interactive TTY?)")
	}
}

func TestCoverageGaps2(t *testing.T) {
	// Narrow render exercises the header gap<1 clamp.
	m := newModel()
	m = upd(m, tea.WindowSizeMsg{Width: 41, Height: 14})
	if v := m.View(); v == "" {
		t.Fatal("narrow view")
	}
	// sqlite error branch: invalid SQL → Output errors → "".
	db := seedDB(t)
	if _, err := os.Stat(db); err == nil {
		if sqlite(db, "NOT VALID SQL ;;") != "" {
			t.Fatal("invalid sql should yield empty")
		}
	}
	// renderTranscript truncates when content exceeds the height.
	big := sized()
	for i := 0; i < 30; i++ {
		big.transcript = append(big.transcript, line{who: "you", text: fmt.Sprintf("line %d", i)})
	}
	out := big.renderTranscript(40, 4)
	if strings.Count(out, "\n") != 3 {
		t.Fatalf("transcript should clamp to 4 lines, got %d", strings.Count(out, "\n")+1)
	}
}

func TestCoverageGaps3(t *testing.T) {
	// windowRows: start+h>len with start>=0 → clamp to len-h.
	if got := windowRows([]string{"a", "b", "c", "d", "e"}, 4, 3); len(got) != 3 || got[0] != "c" {
		t.Fatalf("windowRows end-clamp: %v", got)
	}
	// main()'s happy path (snapshot → run() returns nil → no os.Exit).
	t.Setenv("DOT_AI_SNAPSHOT", "1")
	main()
}

func TestCoverageGaps4(t *testing.T) {
	// execDone callback (post-exec refresh) is now directly callable.
	if execDone(nil) == nil {
		t.Fatal("execDone should return a refresh msg")
	}
	// renderTranscript top-pads when content is shorter than the height.
	m := sized()
	m.transcript = []line{{who: "you", text: "hi"}, {who: "claude", text: "yo"}}
	out := m.renderTranscript(40, 8)
	if strings.Count(out, "\n") != 7 { // exactly 8 lines (top-padded)
		t.Fatalf("transcript should pad to 8 lines, got %d", strings.Count(out, "\n")+1)
	}
}

func TestCoverageGaps5(t *testing.T) {
	// A long prose line wraps to multiple rows (the lipgloss-wrap branch).
	m := sized()
	m.transcript = []line{{who: "you", text: strings.Repeat("word ", 40)}}
	if out := m.renderTranscript(30, 10); !strings.Contains(out, "word") {
		t.Fatal("long prose render")
	}
}

func TestCoverageGaps6(t *testing.T) {
	// renderTranscript clamps a non-positive height to 1.
	m := sized()
	m.transcript = []line{{who: "you", text: "x"}}
	if got := m.renderTranscript(40, 0); strings.Count(got, "\n") != 0 {
		t.Fatalf("h<1 should clamp to a single line, got %d", strings.Count(got, "\n")+1)
	}
}

// ── Phase 1: model picker, session persistence, notifications ───────────────
func TestModelPicker(t *testing.T) {
	if modelLabel("") != "default" || modelLabel("opus") != "opus" {
		t.Fatal("modelLabel")
	}
	if nextModel("") != "opus" || nextModel("haiku") != "" || nextModel("bogus") != "" {
		t.Fatalf("nextModel cycle wrong")
	}
	// fleet 'm' cycles the model + sets status
	m := sized()
	m = upd(m, key("m"))
	if m.aiModel != "opus" || !strings.Contains(m.status, "model") {
		t.Fatalf("m key: model=%q status=%q", m.aiModel, m.status)
	}
	// header shows the model
	if !strings.Contains(m.View(), "opus") {
		t.Fatal("header missing model")
	}
	// slash: /model list, set, clear
	mm, _ := m.handleSlash("/model")
	mm, _ = mm.(model).handleSlash("/model sonnet")
	if mm.(model).aiModel != "sonnet" {
		t.Fatal("/model set")
	}
	mm, _ = mm.(model).handleSlash("/model default")
	if mm.(model).aiModel != "" {
		t.Fatal("/model default")
	}
}

func TestSessionPersistence(t *testing.T) {
	t.Setenv("XDG_STATE_HOME", t.TempDir())
	if loadSession() != nil {
		t.Fatal("no file → nil")
	}
	want := []line{{who: "you", text: "hi"}, {who: "claude", text: "yo\nthere"}}
	saveSession(want)
	got := loadSession()
	if len(got) != 2 || got[1].text != "yo\nthere" || got[0].who != "you" {
		t.Fatalf("round-trip: %+v", got)
	}
	// /save + /resume slash commands (resume adds a "resumed" sys note).
	m := sized()
	m.transcript = want
	m.handleSlash("/save")
	m.transcript = nil
	mm, _ := m.handleSlash("/resume")
	restored := false
	for _, l := range mm.(model).transcript {
		if l.who == "you" && l.text == "hi" {
			restored = true
		}
	}
	if !restored {
		t.Fatal("/resume should restore the saved lines")
	}
	empty := sized()
	t.Setenv("XDG_STATE_HOME", t.TempDir()) // fresh, no session
	mm, _ = empty.handleSlash("/resume")
	for _, l := range mm.(model).transcript {
		if l.who == "you" {
			t.Fatal("/resume with nothing saved must restore nothing")
		}
	}
}

func TestNotifyAndDoneHook(t *testing.T) {
	orig := execCommand
	defer func() { execCommand = orig }()
	execCommand = func(name string, args ...string) *exec.Cmd { return exec.Command("true") }
	notify("dot ai", "done") // current-GOOS branch
	// streamMsg done with a long runStart → saveSession + notify path
	t.Setenv("XDG_STATE_HOME", t.TempDir())
	m := sized()
	m.transcript = []line{{who: "you", text: "q"}, {who: "claude", text: "answer"}}
	m.running = true
	m.runStart = nowUnix() - 20 // ≥8s elapsed → triggers notify
	m = upd(m, streamMsg{done: true})
	if m.running || m.runStart != 0 {
		t.Fatal("done should clear running + runStart")
	}
	if loadSession() == nil {
		t.Fatal("done should have saved the session")
	}
}

func TestSplash(t *testing.T) {
	m := sized()
	// empty transcript → splash with wordmark + pitch + keys
	out := m.renderTranscript(60, 24)
	for _, want := range []string{"█▀▄", "cockpit for your AI fleet", "open session"} {
		if !strings.Contains(out, want) {
			t.Fatalf("splash missing %q", want)
		}
	}
	// recent runs tuck along the bottom (capped at 3)
	m.recent = []string{"a", "b", "c", "d", "e"}
	out = m.renderTranscript(60, 24)
	if !strings.Contains(out, "recent") || strings.Count(out, "\n  ") < 1 {
		t.Fatal("splash should show recent runs")
	}
	if strings.Contains(out, "  e") {
		t.Fatal("recent should be capped at 3")
	}
	// the splash also drives run()'s SPLASH preview path indirectly
	if m.splash(40, 3) == "" {
		t.Fatal("splash should render even when squeezed")
	}
}
