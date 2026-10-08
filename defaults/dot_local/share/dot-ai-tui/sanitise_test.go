// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
package main

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"testing/iotest"
)

// hostile carries an OSC 52 clipboard write, a screen clear, a C1 CSI and
// bidi overrides/isolates: model output or a crafted db row could use any of
// them to act on the terminal or disguise what it shows.
const hostile = "\x1b]52;c;ZXZpbA==\x07\x1b[2J\u009b31m\u202eevil\u2066x\u2069"

// assertInert fails if s still holds a sequence the terminal would act on.
// chroma's own SGR colour codes ("\x1b[...m") are allowed through, so this
// checks for the OSC/BEL/clear/C1 and bidi parts of hostile specifically.
func assertInert(t *testing.T, what, s string) {
	t.Helper()
	for _, bad := range []string{"\x1b]", "\x07", "\x1b[2J", "\u009b", "\u202a", "\u202e", "\u2066", "\u2069"} {
		if strings.Contains(s, bad) {
			t.Errorf("%s still contains %q: %q", what, bad, s)
		}
	}
}

func TestCleanReplacesControlAndBidi(t *testing.T) {
	cases := []struct{ in, want string }{
		{"plain text", "plain text"},
		{"tab\tand\nnewline", "tab\tand\nnewline"},
		{"\x1b[2J", "�[2J"},
		{"\x00\x7f\u0085\u009b", "����"},
		{"a\u202ab\u202ec", "a�b�c"},
		{"\u2066\u2067\u2068\u2069", "����"},
		{"  ⁥\u206a", "  ⁥\u206a"},
		{"héllo ✓ 日本", "héllo ✓ 日本"},
	}
	for _, c := range cases {
		if got := clean(c.in); got != c.want {
			t.Errorf("clean(%q) = %q, want %q", c.in, got, c.want)
		}
	}
}

func TestStreamChunkStripsTerminalEscapes(t *testing.T) {
	for _, reply := range []string{
		"plain " + hostile,
		"```go\nfmt.Println(\"" + hostile + "\")\n```",
	} {
		m := sized()
		m.transcript = []line{{who: "you", text: "q"}, {who: "claude", text: ""}}
		m = upd(m, streamMsg{chunk: reply})
		got := m.transcript[1].text
		assertInert(t, "transcript", got)
		if !strings.Contains(got, "evil") {
			t.Errorf("visible text was dropped: %q", got)
		}
		assertInert(t, "view", m.View())
	}
}

// TestPumpChunksKeepsRunesWhole: a read boundary can fall inside a multi-byte
// rune. Cleaning each chunk must not turn the two halves into U+FFFD.
func TestPumpChunksKeepsRunesWhole(t *testing.T) {
	const want = "héllo ✓ 日本 𝄞 done"
	ch := make(chan streamMsg, 64)
	go func() {
		pumpChunks(iotest.OneByteReader(strings.NewReader(want)), ch)
		close(ch)
	}()
	m := sized()
	m.transcript = []line{{who: "claude", text: ""}}
	for msg := range ch {
		m = upd(m, msg)
	}
	if got := m.transcript[0].text; got != want {
		t.Fatalf("reassembled %q, want %q", got, want)
	}
}

// TestPumpChunksFlushesTruncatedRune: a stream that ends mid-rune still
// surfaces the dangling bytes (as U+FFFD) instead of dropping them.
func TestPumpChunksFlushesTruncatedRune(t *testing.T) {
	ch := make(chan streamMsg, 64)
	pumpChunks(iotest.OneByteReader(strings.NewReader("ab\xe6\x97")), ch)
	close(ch)
	var got string
	for msg := range ch {
		got += clean(msg.chunk)
	}
	if got != "ab��" {
		t.Fatalf("got %q", got)
	}
}

func TestStartStreamStripsTerminalEscapes(t *testing.T) {
	orig := execCommand
	defer func() { execCommand = orig }()
	execCommand = func(string, ...string) *exec.Cmd {
		return exec.Command("printf", "%s", "out "+hostile)
	}
	ch, _ := startStream("claude", "", "", nil, "hi")
	m := sized()
	m.transcript = []line{{who: "claude", text: ""}}
	for {
		msg := <-ch
		m = upd(m, msg)
		if msg.done {
			break
		}
	}
	assertInert(t, "streamed reply", m.transcript[0].text)
	if !strings.Contains(m.transcript[0].text, "evil") {
		t.Fatalf("reply lost its text: %q", m.transcript[0].text)
	}
}

func TestParseSessionStripsTerminalEscapes(t *testing.T) {
	esc := strings.NewReplacer("\x1b", `\u001b`, "\x07", `\u0007`).Replace(hostile)
	got := parseSession([]byte(`[{"who":"claude` + esc + `","text":"` + esc + `"}]`))
	if len(got) != 1 {
		t.Fatalf("got %d lines", len(got))
	}
	assertInert(t, "who", got[0].who)
	assertInert(t, "text", got[0].text)
}

func TestRefreshCleansRecentRows(t *testing.T) {
	if _, err := exec.LookPath("sqlite3"); err != nil {
		t.Skip("sqlite3 CLI not installed")
	}
	dir := t.TempDir()
	db := filepath.Join(dir, "dotfiles-ai.db")
	// char(27)=ESC, char(7)=BEL, char(8238)=U+202E.
	q := "CREATE TABLE runs(id INTEGER PRIMARY KEY, ts TEXT, delegate TEXT, project TEXT, cost_usd REAL);" +
		"INSERT INTO runs(ts,delegate,project,cost_usd) VALUES('2026-06-27T18:00:00Z'," +
		"char(27)||']52;c;ZXZpbA=='||char(7)||'evil'," +
		"char(8238)||'proj'||char(27)||'[2J',0.04);"
	if out, err := exec.Command("sqlite3", db, q).CombinedOutput(); err != nil {
		t.Fatalf("seed: %v %s", err, out)
	}
	t.Setenv("XDG_DATA_HOME", dir)
	t.Setenv("DOT_AI_HOST", "127.0.0.1")
	t.Setenv("DOT_AI_PORT", "1")
	msg := refresh().(refreshMsg)
	if len(msg.recent) != 1 {
		t.Fatalf("recent = %q", msg.recent)
	}
	assertInert(t, "recent row", msg.recent[0])
	if !strings.Contains(msg.recent[0], "evil") || !strings.Contains(msg.recent[0], "proj") {
		t.Fatalf("recent row lost its text: %q", msg.recent[0])
	}
}

// TestRefreshHealthBodyIsBounded: the /health probe reads at most 4 KiB, so a
// hostile or broken listener cannot make the UI buffer an unbounded body.
func TestRefreshHealthBodyIsBounded(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprint(w, strings.Repeat(" ", 4096)+`{"status":"healthy"}`)
	}))
	defer srv.Close()
	host, port, _ := strings.Cut(strings.TrimPrefix(srv.URL, "http://"), ":")
	t.Setenv("DOT_AI_HOST", host)
	t.Setenv("DOT_AI_PORT", port)
	t.Setenv("XDG_DATA_HOME", t.TempDir())
	if msg := refresh().(refreshMsg); msg.gatewayUp {
		t.Fatal("a body past the 4 KiB cap must not count as healthy")
	}
	// Within the cap it still does.
	srv2 := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprint(w, strings.Repeat(" ", 4096-len(`"healthy"`))+`"healthy"`)
	}))
	defer srv2.Close()
	host, port, _ = strings.Cut(strings.TrimPrefix(srv2.URL, "http://"), ":")
	t.Setenv("DOT_AI_HOST", host)
	t.Setenv("DOT_AI_PORT", port)
	if msg := refresh().(refreshMsg); !msg.gatewayUp {
		t.Fatal("a healthy body that fits the cap must count as healthy")
	}
}
