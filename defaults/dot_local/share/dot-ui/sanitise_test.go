// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
package main

import (
	"strings"
	"testing"
)

// hostile carries an OSC 52 clipboard write, a screen clear, a C1 CSI and
// bidi overrides/isolates: everything a crafted row could use to act on the
// terminal or disguise what it shows.
const hostile = "\x1b]52;c;ZXZpbA==\x07\x1b[2J\u009b31m‮evil⁦x⁩"

// assertInert fails if s still holds a byte or rune the terminal would act on.
func assertInert(t *testing.T, what, s string) {
	t.Helper()
	for _, bad := range []string{"\x1b", "\x07", "\u009b", "‪", "‮", "⁦", "⁩"} {
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
		{"a‪b‮c", "a�b�c"},
		{"⁦⁧⁨⁩", "����"},
		// Neighbours of the bidi ranges are ordinary text and stay.
		{"  ⁥⁪", "  ⁥⁪"},
		{"héllo ✓ 日本", "héllo ✓ 日本"},
	}
	for _, c := range cases {
		if got := clean(c.in); got != c.want {
			t.Errorf("clean(%q) = %q, want %q", c.in, got, c.want)
		}
	}
}

func TestRunTableStripsTerminalEscapes(t *testing.T) {
	in := "Name" + hostile + "\x1fValue\nrow\x1f" + hostile + "\n"
	var b strings.Builder
	if err := runTable(LoadPalette(), strings.NewReader(in), &b); err != nil {
		t.Fatal(err)
	}
	assertInert(t, "table", b.String())
	if strings.Count(b.String(), "evil") != 2 {
		t.Errorf("visible text was dropped:\n%s", b.String())
	}
}

func TestReadItemsStripsTerminalEscapes(t *testing.T) {
	items := readItems(strings.NewReader("ok\tcol\n" + hostile + "\n"))
	if len(items) != 2 || items[0] != "ok\tcol" {
		t.Fatalf("items = %q", items)
	}
	assertInert(t, "pick item", items[1])
	if !strings.Contains(items[1], "evil") {
		t.Errorf("pick item lost its text: %q", items[1])
	}
}

func TestParseEventStripsTerminalEscapes(t *testing.T) {
	esc := strings.ReplaceAll(hostile, "\x1b", `\u001b`)
	esc = strings.ReplaceAll(esc, "\x07", `\u0007`)
	line := `{"t":"step` + esc + `","title":"` + esc + `","subtitle":"` + esc +
		`","id":"` + esc + `","label":"` + esc + `","state":"` + esc +
		`","detail":"` + esc + `","summary":"` + esc + `"}`
	e, ok := parseEvent(line)
	if !ok {
		t.Fatalf("line rejected: %s", line)
	}
	for name, v := range map[string]string{
		"t": e.T, "title": e.Title, "subtitle": e.Subtitle, "id": e.ID,
		"label": e.Label, "state": e.State, "detail": e.Detail, "summary": e.Summary,
	} {
		assertInert(t, name, v)
		if !strings.Contains(v, "evil") {
			t.Errorf("%s lost its text: %q", name, v)
		}
	}
}
