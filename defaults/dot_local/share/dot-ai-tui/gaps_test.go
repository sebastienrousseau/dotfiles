// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
package main

import (
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// TestMainErrorExit covers main's failure path through the exit seam: a run
// error is reported on stderr and the process exits 1.
func TestMainErrorExit(t *testing.T) {
	oldExit, oldRun, oldErr := exit, runProgram, os.Stderr
	defer func() { exit, runProgram, os.Stderr = oldExit, oldRun, oldErr }()
	code := -1
	exit = func(c int) { code = c }
	runProgram = func() error { return errors.New("boom") }
	r, w, err := os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	os.Stderr = w
	main()
	w.Close()
	b, _ := io.ReadAll(r)
	if code != 1 {
		t.Fatalf("exit code=%d want 1", code)
	}
	if !strings.Contains(string(b), "dot-ai-tui: boom") {
		t.Errorf("stderr=%q", string(b))
	}
}

// TestNotifyCmdPlatforms covers the macOS (osascript) and Linux
// (notify-send) notification commands.
func TestNotifyCmdPlatforms(t *testing.T) {
	orig := execCommand
	defer func() { execCommand = orig }()
	var got []string
	execCommand = func(name string, args ...string) *exec.Cmd {
		got = append([]string{name}, args...)
		return exec.Command("true")
	}
	notifyCmd("darwin", "T", "B")
	if got[0] != "osascript" || !strings.Contains(strings.Join(got, " "), `display notification "B" with title "T"`) {
		t.Errorf("darwin cmd=%q", got)
	}
	notifyCmd("linux", "T", "B")
	if strings.Join(got, " ") != "notify-send T B" {
		t.Errorf("linux cmd=%q", got)
	}
	notifyCmd("windows", "T", "B") // any other OS uses notify-send too
	if got[0] != "notify-send" {
		t.Errorf("fallback cmd=%q", got)
	}
}

// TestHighlightFallback covers the raw-code fallback when chroma fails, plus
// a fence with no language line and an unterminated fence.
func TestHighlightFallback(t *testing.T) {
	orig := highlightCode
	defer func() { highlightCode = orig }()
	highlightCode = func(io.Writer, string, string, string, string) error { return errors.New("no formatter") }
	if got := highlight("a ```go\nx := 1\n``` b"); got != "a x := 1\n b" {
		t.Errorf("fallback=%q", got)
	}
	highlightCode = orig
	// No newline after the opening fence → the whole block is the code.
	if got := highlight("```inline```"); !strings.Contains(got, "inline") {
		t.Errorf("single-line fence=%q", got)
	}
	// Unterminated fence still renders.
	if got := highlight("```sh\necho hi"); !strings.Contains(got, "echo") {
		t.Errorf("unterminated fence=%q", got)
	}
}

// TestParseSessionMalformed covers corrupt session files (nil result).
func TestParseSessionMalformed(t *testing.T) {
	if parseSession([]byte("{not json")) != nil {
		t.Error("malformed JSON must yield nil")
	}
	if got := parseSession([]byte("[]")); got == nil || len(got) != 0 {
		t.Errorf("empty list should yield an empty slice, got %v", got)
	}
	if got := parseSession([]byte(`[{"Who":"you","Text":"hi"}]`)); len(got) != 1 || got[0].who != "you" {
		t.Errorf("parseSession=%v", got)
	}
	dir := t.TempDir()
	t.Setenv("XDG_STATE_HOME", dir)
	p := filepath.Join(dir, "dot-ai-tui", "session.json")
	if err := os.MkdirAll(filepath.Dir(p), 0o700); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(p, []byte("garbage"), 0o600); err != nil {
		t.Fatal(err)
	}
	if loadSession() != nil {
		t.Error("corrupt session file must load as nil")
	}
}

// TestSaveSessionUnwritable covers a state dir that cannot be created
// (XDG_STATE_HOME points at a regular file): saveSession is a silent no-op.
func TestSaveSessionUnwritable(t *testing.T) {
	f := filepath.Join(t.TempDir(), "not-a-dir")
	if err := os.WriteFile(f, nil, 0o600); err != nil {
		t.Fatal(err)
	}
	t.Setenv("XDG_STATE_HOME", f)
	saveSession([]line{{who: "you", text: "x"}})
	if loadSession() != nil {
		t.Error("nothing should have been saved under a file path")
	}
}

// TestSessionPathDefault covers the ~/.local/state default when
// XDG_STATE_HOME is unset.
func TestSessionPathDefault(t *testing.T) {
	t.Setenv("XDG_STATE_HOME", "")
	t.Setenv("HOME", "/h")
	if got := sessionPath(); got != filepath.Join("/h", ".local", "state", "dot-ai-tui", "session.json") {
		t.Errorf("sessionPath=%q", got)
	}
}

// TestStartStreamPipeError covers the StdoutPipe failure branch (stdout
// already wired on the command).
func TestStartStreamPipeError(t *testing.T) {
	orig := execCommand
	defer func() { execCommand = orig }()
	execCommand = func(string, ...string) *exec.Cmd {
		c := exec.Command("true")
		c.Stdout = io.Discard
		return c
	}
	ch, _ := startStream("claude", "", "", nil, "hi")
	msg := <-ch
	if msg.err == nil || !msg.done {
		t.Fatalf("expected pipe error, got %+v", msg)
	}
}

// TestRenderSnapshotSplash covers DOT_AI_SPLASH (empty-state preview) and
// the default palette preview through run().
func TestRenderSnapshotSplash(t *testing.T) {
	t.Setenv("DOT_AI_SNAPSHOT", "1")
	t.Setenv("DOT_AI_SPLASH", "1")
	t.Setenv("DOT_AI_HOST", "127.0.0.1")
	t.Setenv("DOT_AI_PORT", "1")
	t.Setenv("XDG_DATA_HOME", t.TempDir())
	old := os.Stdout
	r, w, err := os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	os.Stdout = w
	runErr := run()
	os.Stdout = old
	w.Close()
	b, _ := io.ReadAll(r)
	if runErr != nil {
		t.Fatal(runErr)
	}
	if !strings.Contains(string(b), "cockpit for your AI fleet") {
		t.Errorf("splash snapshot missing wordmark pitch:\n%s", string(b))
	}
}

// TestFilterSqliteOutput covers the sqlite3 CLI output scrubber.
func TestFilterSqliteOutput(t *testing.T) {
	cases := []struct{ in, want string }{
		{"", ""},
		{"a\n", "a"},
		{"  a  \nb\n", "a  \nb"},
		{"Run Time: real 0.001\n42\n", "42"},
		{".timer on\n.headers off\nrow\n", "row"},
		{"   .dotted after spaces\nkeep", "keep"},
		{"only\nRun Time: x", "only"},
	}
	for _, c := range cases {
		if got := filterSqliteOutput([]byte(c.in)); got != c.want {
			t.Errorf("filterSqliteOutput(%q)=%q want %q", c.in, got, c.want)
		}
	}
}

// TestGatewayURL covers the pure URL builder.
func TestGatewayURL(t *testing.T) {
	if got := gatewayURL("localhost", "80"); got != "http://localhost:80" {
		t.Errorf("gatewayURL=%q", got)
	}
	if got := gatewayURL("", ""); got != "http://:" {
		t.Errorf("gatewayURL empty=%q", got)
	}
}

// TestResolveLang covers fence-info validation, lexer resolution and the
// bounded cache; TestHighlightHugeLangTag is the regression for the
// 13-second render stall on a 5 000-character language tag (found by
// FuzzHighlight).
func TestResolveLang(t *testing.T) {
	if got := resolveLang("go"); got != "Go" {
		t.Errorf("resolveLang(go)=%q", got)
	}
	if got := resolveLang("ts"); got != "TypeScript" {
		t.Errorf("resolveLang(ts)=%q", got)
	}
	for _, bad := range []string{"", "a b", "x\n", strings.Repeat("x", 33), "ts;rm -rf", "日本"} {
		if got := resolveLang(bad); got != "" {
			t.Errorf("resolveLang(%q)=%q want empty", bad, got)
		}
	}
	// Unknown-but-valid tags resolve to "" and are memoised.
	if got := resolveLang("nolang-zz"); got != "" {
		t.Errorf("unknown lang=%q", got)
	}
	if v, ok := langCache.Load("nolang-zz"); !ok || v.(string) != "" {
		t.Error("unknown lang should be cached")
	}
	// The cache stops growing at its cap.
	for i := 0; i < int(langCacheMax)+10; i++ {
		resolveLang(fmt.Sprintf("zz%d", i))
	}
	if n := langCacheN.Load(); n > langCacheMax {
		t.Errorf("cache grew to %d > %d", n, langCacheMax)
	}
}

func TestHighlightHugeLangTag(t *testing.T) {
	in := "```ts" + strings.Repeat("x", 5000) + "\ncode\n```"
	start := time.Now()
	out := highlight(in)
	if d := time.Since(start); d > 2*time.Second {
		t.Fatalf("highlight took %v on a huge language tag", d)
	}
	if !strings.Contains(out, "code") {
		t.Errorf("code lost: %q", out)
	}
}

// TestErrorLineStyled covers the transcript styling of a failed turn: the
// line is rendered with the error colour, not the assistant colour.
func TestErrorLineStyled(t *testing.T) {
	m := sized()
	m.transcript = []line{{who: "you", text: "q"}, {who: "claude", text: ""}}
	m = upd(m, streamMsg{err: errors.New("boom")})
	if got := m.transcript[1].text; got != errPrefix+"boom" {
		t.Fatalf("error line=%q", got)
	}
	if out := m.renderTranscript(60, 6); !strings.Contains(out, "boom") {
		t.Fatalf("error text missing:\n%s", out)
	}
	// The error style must be visually distinct from the assistant style.
	if errSt.GetForeground() == botSt.GetForeground() {
		t.Error("errSt and botSt share a foreground colour")
	}
	// `go test` has no colour profile, so Render is the identity and the
	// branch cannot be observed through lipgloss output. It is observable
	// through chroma: an error line is shown literally, while a reply with
	// the same text is syntax-highlighted.
	fenced := "```go\nvar x = 1\n```"
	m.transcript[1].text = errPrefix + fenced
	if out := m.renderTranscript(60, 8); strings.Contains(out, "\x1b[38;5;") {
		t.Errorf("an error line must not be syntax-highlighted:\n%q", out)
	}
	m.transcript[1].text = fenced
	if out := m.renderTranscript(60, 8); !strings.Contains(out, "\x1b[38;5;") {
		t.Errorf("a normal reply must still be syntax-highlighted:\n%q", out)
	}
}

// TestSaveSessionMarshalFailure covers the encode-failure branch: a
// failure must leave any previously saved session untouched rather than
// writing a truncated file.
func TestSaveSessionMarshalFailure(t *testing.T) {
	t.Setenv("XDG_STATE_HOME", t.TempDir())
	good := []line{{who: "you", text: "keep me"}}
	saveSession(good)

	orig := marshalSession
	defer func() { marshalSession = orig }()
	marshalSession = func([]sessLine) ([]byte, error) { return nil, errors.New("encode failed") }
	saveSession([]line{{who: "you", text: "must not land"}})

	got := loadSession()
	if len(got) != 1 || got[0].text != "keep me" {
		t.Fatalf("a failed encode must not overwrite the session: %+v", got)
	}
}

// TestSplashClampsNegativeHeight covers the height clamp directly: the
// splash is asked for fewer rows than it has content for, and for a
// negative count.
func TestSplashClampsNegativeHeight(t *testing.T) {
	m := sized()
	for _, h := range []int{-10, -1, 0, 1, 3, 30} {
		out := m.splash(40, h)
		want := max(h, 0)
		got := strings.Count(out, "\n") + 1
		if want == 0 {
			if out != "" {
				t.Errorf("h=%d should render nothing, got %q", h, out)
			}
			continue
		}
		if got != want {
			t.Errorf("splash(40,%d) rendered %d lines, want %d", h, got, want)
		}
	}
}
