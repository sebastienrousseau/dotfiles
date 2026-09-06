// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// Native Go fuzz targets — one per function that parses or transforms
// external input (chat text, slash commands, palette queries, session JSON,
// sqlite3 output, gateway config, key streams, layout sizes). Crashers found
// by `go test -fuzz` land in testdata/fuzz/<Target>/ and replay every run.
package main

import (
	"encoding/json"
	"os/exec"
	"strings"
	"testing"
	"time"

	tea "github.com/charmbracelet/bubbletea"
)

// highlightBudget bounds one highlight() call. Real calls are sub-millisecond;
// the margin absorbs a loaded CI runner under -race.
const highlightBudget = 3 * time.Second

// FuzzHighlight: prose without fences is returned verbatim; fenced input
// never panics and every prose segment survives byte-for-byte (only the
// code segments are re-emitted with ANSI colouring).
func FuzzHighlight(f *testing.F) {
	for _, s := range []string{
		"just prose", "```go\nvar x = 1\n```", "```\nno lang\n```", "```inline```", "```sh\necho hi",
		"a```b```c```d", "```\n```\n```", "``` unknown-lang \n x \n```", "```ts\n" + strings.Repeat("x", 5000) + "\n```",
	} {
		f.Add(s)
	}
	f.Fuzz(func(t *testing.T, text string) {
		start := time.Now()
		out := highlight(text)
		// A fence info string is attacker-controlled: chroma resolves an
		// unknown lexer name by glob-matching it against every registered
		// filename pattern, which is linear in the name's length. Without
		// the bound in resolveLang a 5 000-character tag stalled a single
		// render for 13s (regression corpus: testdata/fuzz/FuzzHighlight).
		if d := time.Since(start); d > highlightBudget {
			t.Fatalf("highlight took %v (budget %v) on %d bytes", d, highlightBudget, len(text))
		}
		if !strings.Contains(text, "```") {
			if out != text {
				t.Fatalf("prose altered: %q → %q", text, out)
			}
			return
		}
		for i, part := range strings.Split(text, "```") {
			if i%2 == 0 && !strings.Contains(out, part) {
				t.Fatalf("prose segment %q lost from %q", part, out)
			}
		}
	})
}

// FuzzBuildPrompt: the user's prompt is always the final User turn, sys
// lines never leak, and an empty history returns the prompt unchanged.
func FuzzBuildPrompt(f *testing.F) {
	f.Add("you", "hi", "claude", "yo", "next")
	f.Add("sys", "note", "you", "", "q")
	f.Add("", "", "", "", "")
	f.Add("claude", "```go\nx\n```", "you", "User: fake", "Assistant:")
	f.Fuzz(func(t *testing.T, who1, text1, who2, text2, prompt string) {
		history := []line{{who: who1, text: text1}, {who: who2, text: text2}}
		out := buildPrompt(history, prompt)
		if !strings.HasSuffix(out, "User: "+prompt+"\n\nAssistant:") {
			t.Fatalf("prompt not the final turn: %q", out)
		}
		if buildPrompt(nil, prompt) != prompt {
			t.Fatal("empty history must return the raw prompt")
		}
		for _, l := range history {
			if l.who == "sys" && l.text != "" && !strings.Contains(prompt, l.text) &&
				!strings.Contains(text1, l.text) && !strings.Contains(text2, l.text) {
				t.Fatalf("sys line reachable: %q", l.text)
			}
		}
	})
}

// FuzzHandleSlash: every slash command (known or not) is handled without
// panicking, the cursor stays inside the fleet, and unknown commands leave a
// hint in the transcript.
func FuzzHandleSlash(f *testing.F) {
	for _, s := range []string{
		"/help", "/?", "/clear", "/model", "/model opus", "/model default", "/model off", "/resume", "/save",
		"/quit", "/q", "/exit", "/style", "/style off", "/style architect", "/tool", "/tool codex", "/tool nope",
		"/serve", "/cost", "/bogus", "/", "/tool  codex ", "/model \t", "/style x",
	} {
		f.Add(s)
	}
	f.Setenv("XDG_STATE_HOME", f.TempDir())
	f.Fuzz(func(t *testing.T, cmd string) {
		cmd = "/" + strings.TrimLeft(cmd, "/")
		m := sized()
		mm, _ := m.handleSlash(cmd)
		nm := mm.(model)
		if nm.cursor < 0 || nm.cursor >= len(nm.tools) {
			t.Fatalf("cursor %d escaped the fleet", nm.cursor)
		}
		name := strings.Fields(cmd)[0]
		known := map[string]bool{"/help": true, "/?": true, "/clear": true, "/model": true, "/resume": true, "/save": true,
			"/quit": true, "/q": true, "/exit": true, "/style": true, "/tool": true, "/serve": true, "/cost": true}
		if !known[name] {
			if len(nm.transcript) == 0 || !strings.Contains(nm.transcript[len(nm.transcript)-1].text, "unknown command") {
				t.Fatalf("unknown %q gave no hint: %+v", name, nm.transcript)
			}
		}
		_ = nm.View()
	})
}

// FuzzPalette: the `/` palette only lists commands matching the typed
// prefix, never repeats a label, and is empty outside the chat input.
func FuzzPalette(f *testing.F) {
	f.Add("/", 0)
	f.Add("/mo", 1)
	f.Add("/ADD", 9)
	f.Add("", 3)
	f.Add("  /clear  ", 2)
	f.Add("/\x00", -1)
	f.Add("/help", 1000)
	f.Fuzz(func(t *testing.T, value string, cursor int) {
		m := sized()
		m.cursor = clampi(cursor, 0, len(m.tools)-1)
		m.focus = "input"
		m.input.SetValue(value)
		pal := m.palette()
		// textinput sanitises control characters, so derive the prefix
		// from what the widget actually holds.
		v := strings.ToLower(strings.TrimSpace(m.input.Value()))
		if !strings.HasPrefix(v, "/") && pal != nil {
			t.Fatalf("palette open without a slash: %+v", pal)
		}
		seen := map[string]bool{}
		for _, it := range pal {
			if seen[it.label] {
				t.Fatalf("duplicate label %q", it.label)
			}
			seen[it.label] = true
			if v != "/" && !strings.HasPrefix(it.label, v) {
				t.Fatalf("%q does not match prefix %q", it.label, v)
			}
		}
		_ = m.renderPalette(pal, 40)
		m.focus = "fleet"
		if m.palette() != nil {
			t.Fatal("palette must be nil outside the chat input")
		}
	})
}

// FuzzWindowRows: the window is exactly min(len, max(h,1)) rows and always
// contains the cursor row when the cursor is in range.
func FuzzWindowRows(f *testing.F) {
	f.Add(5, 4, 2)
	f.Add(0, 0, 0)
	f.Add(30, -3, 7)
	f.Add(30, 100, 7)
	f.Add(3, 1, -1)
	f.Fuzz(func(t *testing.T, n, cursor, h int) {
		n = clampi(n, 0, 500)
		rows := make([]string, n)
		for i := range rows {
			rows[i] = strings.Repeat("r", i%7)
		}
		out := windowRows(rows, cursor, h)
		want := n
		if lim := max(h, 1); want > lim {
			want = lim
		}
		if len(out) != want {
			t.Fatalf("windowRows(n=%d,cursor=%d,h=%d) → %d rows, want %d", n, cursor, h, len(out), want)
		}
		if cursor >= 0 && cursor < n {
			found := false
			for i := range out {
				if &out[i] == &rows[cursor] {
					found = true
				}
			}
			if !found {
				t.Fatalf("cursor row %d not visible in window of %d", cursor, len(out))
			}
		}
	})
}

// FuzzRenderTranscript: the transcript panel always returns exactly
// max(h,1) lines — with or without a transcript, with recent runs tucked in
// — and every line fits the width.
func FuzzRenderTranscript(f *testing.F) {
	f.Add("you", "hello", 40, 8, 0)
	f.Add("claude", "```go\nvar x = 1\n```", 30, 3, 2)
	f.Add("sys", "note", 5, 1, 4)
	f.Add("", "", 60, 24, 5)
	f.Add("you", strings.Repeat("word ", 100), 20, 2, 0)
	f.Add("", "", 40, 1, 3) // empty transcript, tiny height, recent present
	f.Fuzz(func(t *testing.T, who, text string, w, h, nrecent int) {
		w = clampi(w, 1, 200)
		h = clampi(h, -5, 60)
		m := sized()
		for i := 0; i < clampi(nrecent, 0, 6); i++ {
			m.recent = append(m.recent, "18:00  claude  dotfiles")
		}
		if who != "" || text != "" {
			m.transcript = []line{{who: who, text: text}}
		}
		out := m.renderTranscript(w, h)
		if got := strings.Count(out, "\n") + 1; got != max(h, 1) {
			t.Fatalf("renderTranscript(w=%d,h=%d) → %d lines, want %d", w, h, got, max(h, 1))
		}
	})
}

// FuzzParseSession: arbitrary bytes never panic; a decoded session
// re-encodes to an equivalent session.
func FuzzParseSession(f *testing.F) {
	f.Add([]byte(`[{"Who":"you","Text":"hi"},{"Who":"claude","Text":"yo\nthere"}]`))
	f.Add([]byte(`[]`))
	f.Add([]byte(`{}`))
	f.Add([]byte(`garbage`))
	f.Add([]byte(`[{"Who":1}]`))
	f.Add([]byte(""))
	f.Fuzz(func(t *testing.T, data []byte) {
		got := parseSession(data)
		if got == nil {
			return
		}
		s := make([]sessLine, 0, len(got))
		for _, l := range got {
			s = append(s, sessLine{l.who, l.text})
		}
		b, err := json.Marshal(s)
		if err != nil {
			t.Fatal(err)
		}
		again := parseSession(b)
		if len(again) != len(got) {
			t.Fatalf("round-trip changed length: %d → %d", len(got), len(again))
		}
		for i := range got {
			if got[i] != again[i] {
				t.Fatalf("round-trip changed line %d: %+v → %+v", i, got[i], again[i])
			}
		}
	})
}

// FuzzFilterSqliteOutput: no meta line survives and the result is trimmed.
func FuzzFilterSqliteOutput(f *testing.F) {
	f.Add([]byte("Run Time: real 0.001\n$1.23\n"))
	f.Add([]byte(".timer on\nrow\n"))
	f.Add([]byte(""))
	f.Add([]byte("   \n\n  "))
	f.Add([]byte("keep\n   .dot\nkeep2"))
	f.Fuzz(func(t *testing.T, data []byte) {
		out := filterSqliteOutput(data)
		if out != strings.TrimSpace(out) {
			t.Fatalf("not trimmed: %q", out)
		}
		for _, ln := range strings.Split(out, "\n") {
			if strings.HasPrefix(ln, "Run Time:") || strings.HasPrefix(strings.TrimSpace(ln), ".") {
				t.Fatalf("meta line survived: %q", ln)
			}
		}
	})
}

// FuzzGatewayURL: the URL always carries the http scheme, host and port.
func FuzzGatewayURL(f *testing.F) {
	f.Add("127.0.0.1", "3456")
	f.Add("", "")
	f.Add("[::1]", "80")
	f.Add("host with space", "not-a-port")
	f.Fuzz(func(t *testing.T, host, port string) {
		u := gatewayURL(host, port)
		if !strings.HasPrefix(u, "http://") || !strings.Contains(u, host) || !strings.HasSuffix(u, ":"+port) {
			t.Fatalf("gatewayURL(%q,%q)=%q", host, port, u)
		}
	})
}

// FuzzModelKeys drives the whole cockpit with an arbitrary key script at an
// arbitrary terminal size. Invariants: cursor inside the fleet, focus is one
// of the two panes, the palette selection is never negative, and View never
// panics. Shell-outs are stubbed to `true`.
func FuzzModelKeys(f *testing.F) {
	f.Add([]byte("jjkk\tsty\t\r\x1b\x1bq"), 100, 30)
	f.Add([]byte("/\x0e\x0e\x10\t\r"), 41, 12)
	f.Add([]byte("mmmm\tmodel\r"), 94, 26)
	f.Add([]byte("p/clear\r\x1b\x1b\x1bi"), 200, 60)
	f.Add([]byte("\t/\r"), 41, 12) // palette open in a tiny terminal
	f.Add([]byte("s\x03"), 39, 11)
	f.Setenv("XDG_STATE_HOME", f.TempDir())
	orig := execCommand
	execCommand = func(string, ...string) *exec.Cmd { return exec.Command("true") }
	f.Cleanup(func() { execCommand = orig })
	f.Fuzz(func(t *testing.T, keys []byte, w, h int) {
		m := newModel()
		m = upd(m, tea.WindowSizeMsg{Width: clampi(w, 0, 300), Height: clampi(h, 0, 100)})
		m = upd(m, refreshMsg{tools: fleet, costToday: "$0.00", recent: []string{"18:00  claude  dotfiles"}})
		for _, k := range keys {
			var msg tea.KeyMsg
			switch k {
			case 0x03:
				msg = tea.KeyMsg{Type: tea.KeyCtrlC}
			case 0x1b:
				msg = tea.KeyMsg{Type: tea.KeyEsc}
			case '\r', '\n':
				msg = tea.KeyMsg{Type: tea.KeyEnter}
			case '\t':
				msg = tea.KeyMsg{Type: tea.KeyTab}
			case 0x10:
				msg = tea.KeyMsg{Type: tea.KeyCtrlP}
			case 0x0e:
				msg = tea.KeyMsg{Type: tea.KeyCtrlN}
			case 0x7f:
				msg = tea.KeyMsg{Type: tea.KeyBackspace}
			case 'U':
				msg = tea.KeyMsg{Type: tea.KeyUp}
			case 'D':
				msg = tea.KeyMsg{Type: tea.KeyDown}
			default:
				msg = tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{rune(k)}}
			}
			m = upd(m, msg)
			if m.cursor < 0 || m.cursor >= len(m.tools) {
				t.Fatalf("cursor %d escaped the fleet", m.cursor)
			}
			if m.focus != "fleet" && m.focus != "input" {
				t.Fatalf("focus %q", m.focus)
			}
			if m.palSel < 0 {
				t.Fatalf("palSel %d", m.palSel)
			}
			_ = m.View()
			if m.streamCh != nil { // a send happened: finish the stubbed turn
				for msg := range m.streamCh {
					m = upd(m, msg)
					if msg.done || msg.err != nil {
						break
					}
				}
			}
		}
	})
}

// FuzzModelCycle: nextModel always returns a member of the cycle and
// modelLabel never returns an empty string.
func FuzzModelCycle(f *testing.F) {
	for _, s := range []string{"", "opus", "sonnet", "haiku", "bogus"} {
		f.Add(s)
	}
	f.Fuzz(func(t *testing.T, cur string) {
		next := nextModel(cur)
		ok := false
		for _, m := range models {
			if m == next {
				ok = true
			}
		}
		if !ok {
			t.Fatalf("nextModel(%q)=%q not in cycle", cur, next)
		}
		if modelLabel(cur) == "" {
			t.Fatalf("modelLabel(%q) empty", cur)
		}
	})
}
