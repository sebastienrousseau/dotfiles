// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// Native Go fuzz targets — one per function that parses or transforms
// external input (NDJSON events, env colors, picker keys/queries, table
// rows, CLI flags). Each carries a seed corpus; crashers found by
// `go test -fuzz` land in testdata/fuzz/<Target>/ and replay on every run.
package main

import (
	"encoding/json"
	"strings"
	"testing"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// FuzzParseEvent: any line either parses to a valid JSON event or is
// rejected; blank lines are always rejected; a parsed event round-trips.
func FuzzParseEvent(f *testing.F) {
	for _, s := range []string{
		"", "   ", "{", "[]", "null", `{"t":"header","title":"t","subtitle":"s"}`,
		`{"t":"step","id":"a","label":"A","state":"ok","detail":"d"}`,
		`{"t":"progress","cur":3,"total":12}`, `{"t":"wait","label":"w"}`,
		`{"t":"done","elapsed_ms":1618,"summary":"s"}`, `{"t":"step","cur":"notanint"}`,
		"{\"t\":\"\u0000\"}", "\t{\"t\":\"done\"}\t",
	} {
		f.Add(s)
	}
	f.Fuzz(func(t *testing.T, line string) {
		e, ok := parseEvent(line)
		if strings.TrimSpace(line) == "" {
			if ok {
				t.Fatalf("blank line parsed: %q", line)
			}
			return
		}
		if !ok {
			if e != (Event{}) {
				t.Fatalf("rejected line returned a non-zero event: %+v", e)
			}
			return
		}
		if !json.Valid([]byte(strings.TrimSpace(line))) {
			t.Fatalf("parsed invalid JSON: %q", line)
		}
		b, err := json.Marshal(e)
		if err != nil {
			t.Fatalf("marshal: %v", err)
		}
		if e2, ok2 := parseEvent(string(b)); !ok2 || e2 != e {
			t.Fatalf("round-trip mismatch: %+v vs %+v", e, e2)
		}
	})
}

// FuzzParseColor: the result is either the fallback or exactly the input,
// and an accepted input is a well-formed #rgb / #rrggbb literal.
func FuzzParseColor(f *testing.F) {
	for _, s := range []string{"", "#abc", "#ABCDEF", "#1a2b3c", "abc", "#ab", "#abcd", "#gggggg", " #abc", "#abc\n", "#abcdef0"} {
		f.Add(s)
	}
	fb := lipgloss.Color("#000000")
	f.Fuzz(func(t *testing.T, v string) {
		got := parseColor(v, fb)
		if got == fb && v != string(fb) {
			return
		}
		if string(got) != v {
			t.Fatalf("parseColor(%q) returned neither fallback nor input: %q", v, got)
		}
		if (len(v) != 4 && len(v) != 7) || v[0] != '#' {
			t.Fatalf("accepted malformed color %q", v)
		}
		for _, c := range v[1:] {
			if !strings.ContainsRune("0123456789abcdefABCDEF", c) {
				t.Fatalf("accepted non-hex digit %q in %q", c, v)
			}
		}
	})
}

// FuzzFuzzyMatch: the empty query matches everything, every string matches
// itself (any script, any case), and a match never exceeds the candidate's
// rune count.
func FuzzFuzzyMatch(f *testing.F) {
	for _, c := range [][2]string{
		{"altai-dark", ""}, {"altai-dark", "adk"}, {"altai-dark", "ALT"}, {"altai-dark", "kdar"},
		{"é", "é"}, {"Straße", "straße"}, {"日本語", "本"}, {"İstanbul", "i"}, {"", "x"},
	} {
		f.Add(c[0], c[1])
	}
	f.Fuzz(func(t *testing.T, s, q string) {
		if !fuzzyMatch(s, "") {
			t.Fatalf("empty query must match %q", s)
		}
		if !fuzzyMatch(s, s) {
			t.Fatalf("%q must match itself", s)
		}
		if up := strings.ToUpper(s); !fuzzyMatch(s, up) || !fuzzyMatch(up, s) {
			// Case-folding is asymmetric for a few scripts (ToLower(ToUpper(x)) != ToLower(x)),
			// so only assert when the fold is stable.
			if lo, refolded := strings.ToLower(s), strings.ToLower(up); lo == refolded {
				t.Fatalf("%q must match itself case-insensitively", s)
			}
		}
		if fuzzyMatch(s, q) && len([]rune(strings.ToLower(q))) > len([]rune(strings.ToLower(s))) {
			t.Fatalf("query %q longer than candidate %q matched", q, s)
		}
	})
}

// FuzzStepApply feeds an arbitrary NDJSON stream through the reducer and
// renders after every event: the id index always mirrors the step list and
// View never panics.
func FuzzStepApply(f *testing.F) {
	f.Add(`{"t":"header","title":"dot theme","subtitle":"pulse"}
{"t":"step","id":"a","label":"Alpha","state":"run"}
{"t":"step","id":"a","state":"ok","detail":"done"}
{"t":"step","id":"b","label":"Beta","state":"na"}
{"t":"progress","cur":1,"total":2}
{"t":"wait","label":"w"}
{"t":"done","elapsed_ms":5,"summary":"s"}`)
	f.Add(`{"t":"step","id":"","label":"","state":""}` + "\n" + `{"t":"step","id":"","state":"na"}`)
	f.Add("garbage\n\n{\"t\":\"progress\",\"cur\":-5,\"total\":-1}\n{\"t\":\"done\"}")
	f.Fuzz(func(t *testing.T, stream string) {
		m := newTestModel()
		for _, ln := range strings.Split(stream, "\n") {
			if e, ok := parseEvent(ln); ok {
				m.apply(e)
			}
			if len(m.index) != len(m.steps) {
				t.Fatalf("index/steps drift: %d vs %d", len(m.index), len(m.steps))
			}
			for id, i := range m.index {
				if i < 0 || i >= len(m.steps) || m.steps[i].id != id {
					t.Fatalf("index %q → %d does not point at its step", id, i)
				}
			}
			_ = m.View()
			_ = m.renderBar()
		}
		var b strings.Builder
		if err := snapshotStep(m.st, strings.NewReader(stream), &b); err != nil {
			t.Fatal(err)
		}
		if !strings.Contains(b.String(), "Done") {
			t.Fatalf("snapshot never finalized:\n%s", b.String())
		}
	})
}

// FuzzPickKeys drives the picker with arbitrary items and a key script.
// Invariants: cursor and offset stay inside the filtered list, the filtered
// list is a subset of the items, and View never panics.
func FuzzPickKeys(f *testing.F) {
	f.Add("altai-dark\nberlin-dark\nbloom-dark\ncanary-light\n", []byte("dark\x0e\x0e\x10\x7f\x7f\r"), 15)
	f.Add("a\nb\n", []byte("\x03"), 7)
	f.Add("", []byte("\r"), 0)
	f.Add("x\ny\nz\n", []byte("\x1b"), 100)
	f.Add("é\nÉ\n", []byte("é\r"), 5)
	f.Fuzz(func(t *testing.T, items string, keys []byte, height int) {
		m := newPickModel(NewStyles(LoadPalette()), "h", "p", readItems(strings.NewReader(items)))
		var mm tea.Model = m
		mm, _ = mm.Update(tea.WindowSizeMsg{Width: 80, Height: height})
		for _, k := range keys {
			var msg tea.KeyMsg
			switch k {
			case 0x03:
				msg = tea.KeyMsg{Type: tea.KeyCtrlC}
			case 0x1b:
				msg = tea.KeyMsg{Type: tea.KeyEsc}
			case '\r', '\n':
				msg = tea.KeyMsg{Type: tea.KeyEnter}
			case 0x10:
				msg = tea.KeyMsg{Type: tea.KeyCtrlP}
			case 0x0e:
				msg = tea.KeyMsg{Type: tea.KeyCtrlN}
			case 0x7f, 0x08:
				msg = tea.KeyMsg{Type: tea.KeyBackspace}
			case 'U':
				msg = tea.KeyMsg{Type: tea.KeyUp}
			case 'D':
				msg = tea.KeyMsg{Type: tea.KeyDown}
			default:
				msg = tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{rune(k)}}
			}
			mm, _ = mm.Update(msg)
			pm := mm.(pickModel)
			if len(pm.filtered) == 0 && pm.cursor != 0 {
				t.Fatalf("cursor %d with empty list", pm.cursor)
			}
			if len(pm.filtered) > 0 && (pm.cursor < 0 || pm.cursor >= len(pm.filtered)) {
				t.Fatalf("cursor %d outside filtered list of %d", pm.cursor, len(pm.filtered))
			}
			if pm.offset < 0 || pm.offset > pm.cursor {
				t.Fatalf("offset %d not in [0,cursor=%d]", pm.offset, pm.cursor)
			}
			if len(pm.filtered) > len(pm.all) {
				t.Fatalf("filtered grew past items: %d > %d", len(pm.filtered), len(pm.all))
			}
			for _, it := range pm.filtered {
				if !fuzzyMatch(it, pm.query) {
					t.Fatalf("filtered item %q does not match query %q", it, pm.query)
				}
			}
			_ = pm.View()
			if pm.cancelled || pm.selected != "" {
				return
			}
		}
	})
}

// FuzzRunTable: any byte stream renders without panicking; a non-empty
// header always produces a bordered table, an empty stream produces nothing.
func FuzzRunTable(f *testing.F) {
	f.Add([]byte("Alias\x1fExpands\x1fTier\nll\x1fls -alFh\x1fcore\n"))
	f.Add([]byte(""))
	f.Add([]byte("\n"))
	f.Add([]byte("only\x1fheaders"))
	f.Add([]byte("a\x1fb\nc\nd\x1fe\x1ff\x1fg\n"))
	f.Add([]byte("\x1f\x1f\n\x1f\n"))
	f.Add([]byte("h\n" + strings.Repeat("x\x1fy\n", 200)))
	f.Fuzz(func(t *testing.T, data []byte) {
		var b strings.Builder
		if err := runTable(LoadPalette(), strings.NewReader(string(data)), &b); err != nil {
			t.Fatal(err)
		}
		hasHeader := len(strings.SplitN(string(data), "\n", 2)[0]) > 0 || strings.Contains(string(data), "\n")
		if hasHeader && b.Len() > 0 && !strings.Contains(b.String(), "╭") {
			t.Fatalf("table without a border:\n%s", b.String())
		}
		if len(data) == 0 && b.Len() != 0 {
			t.Fatalf("empty input rendered %q", b.String())
		}
	})
}

// FuzzReadItems: no blank rows survive and the count never exceeds the
// number of input lines.
func FuzzReadItems(f *testing.F) {
	f.Add("a\n\n  \nb\nc\n")
	f.Add("")
	f.Add("\n\n\n")
	f.Add("no newline")
	f.Add(" leading\ntrailing \n")
	f.Fuzz(func(t *testing.T, in string) {
		items := readItems(strings.NewReader(in))
		if len(items) > strings.Count(in, "\n")+1 {
			t.Fatalf("more items (%d) than lines", len(items))
		}
		for _, it := range items {
			if strings.TrimSpace(it) == "" {
				t.Fatalf("blank item %q survived", it)
			}
			if strings.Contains(it, "\n") {
				t.Fatalf("item spans lines: %q", it)
			}
		}
	})
}

// FuzzParsePickArgs: header/prompt are always either empty or one of the
// given arguments, and the parser never panics on dangling flags.
func FuzzParsePickArgs(f *testing.F) {
	f.Add("--header", "H", "--prompt", "P")
	f.Add("--prompt", "", "--header", "")
	f.Add("--header", "--prompt", "x", "--header")
	f.Add("", "", "", "")
	f.Add("--bogus", "--header", "--header", "value")
	f.Fuzz(func(t *testing.T, a, b, c, d string) {
		args := []string{a, b, c, d}
		h, p := parsePickArgs(args)
		in := func(s string) bool {
			if s == "" {
				return true
			}
			for _, x := range args {
				if x == s {
					return true
				}
			}
			return false
		}
		if !in(h) || !in(p) {
			t.Fatalf("parsePickArgs(%q) invented (%q,%q)", args, h, p)
		}
		for n := 0; n <= len(args); n++ {
			parsePickArgs(args[:n]) // every prefix must be safe too
		}
	})
}
