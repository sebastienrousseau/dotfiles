// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// OSS-Fuzz harnesses for the dot-ui input parsers.
//
// dot-ui lives in its own `package main` module
// (defaults/dot_local/share/dot-ui), which OSS-Fuzz's
// compile_native_go_fuzzer cannot import — it needs a library package. So,
// exactly as the shell harnesses in this directory port shell logic into
// Go, these port the dot-ui parsers and are kept in lockstep with them.
// Drift between a port and its original IS the bug class these harnesses
// exist to surface.
//
// The same functions are also fuzzed in-module (dot-ui/fuzz_test.go) where
// they run against the real implementation on every push; these ports are
// what runs continuously at scale on OSS-Fuzz / ClusterFuzzLite.
//
// Run locally:
//
//	cd oss-fuzz-integration/fuzz
//	go test -run '^$' -fuzz=FuzzUIEventLine -fuzztime=30s ./...

package fuzz

import (
	"encoding/json"
	"regexp"
	"strings"
	"testing"
)

// ── port of defaults/dot_local/share/dot-ui/run.go ──────────────────────────

// UIEvent mirrors dot-ui's Event: the union of all NDJSON event fields.
type UIEvent struct {
	T         string `json:"t"`
	Title     string `json:"title,omitempty"`
	Subtitle  string `json:"subtitle,omitempty"`
	ID        string `json:"id,omitempty"`
	Label     string `json:"label,omitempty"`
	State     string `json:"state,omitempty"`
	Detail    string `json:"detail,omitempty"`
	Cur       int    `json:"cur,omitempty"`
	Total     int    `json:"total,omitempty"`
	ElapsedMs int64  `json:"elapsed_ms,omitempty"`
	Summary   string `json:"summary,omitempty"`
}

// ParseUIEvent mirrors dot-ui's parseEvent: decode one NDJSON line, with
// blank and malformed lines rejected.
func ParseUIEvent(line string) (UIEvent, bool) {
	line = strings.TrimSpace(line)
	if line == "" {
		return UIEvent{}, false
	}
	var e UIEvent
	if err := json.Unmarshal([]byte(line), &e); err != nil {
		return UIEvent{}, false
	}
	return e, true
}

// UIProgressWidth mirrors the clamp in dot-ui's renderBar. A bar cell count
// outside [0, w] panicked strings.Repeat before the clamp was added.
func UIProgressWidth(cur, total, w int) int {
	filled := 0
	if total > 0 {
		filled = cur * w / total
	}
	return max(0, min(filled, w))
}

// FuzzUIEventLine: a line either decodes to a valid JSON event or is
// refused; blank lines are always refused; an accepted event round-trips;
// and the progress width derived from it is always a legal repeat count.
func FuzzUIEventLine(f *testing.F) {
	for _, s := range []string{
		"", "   ", "{", "[]", "null",
		`{"t":"header","title":"dot theme","subtitle":"pulse"}`,
		`{"t":"step","id":"a","label":"A","state":"ok","detail":"d"}`,
		`{"t":"progress","cur":3,"total":12}`,
		`{"t":"progress","cur":-1,"total":1}`, // the crasher that found the clamp
		`{"t":"progress","cur":9999999,"total":1}`,
		`{"t":"wait","label":"w"}`,
		`{"t":"done","elapsed_ms":1618,"summary":"s"}`,
		`{"t":"step","cur":"notanint"}`,
		"\t{\"t\":\"done\"}\t",
	} {
		f.Add(s)
	}
	f.Fuzz(func(t *testing.T, line string) {
		e, ok := ParseUIEvent(line)
		if strings.TrimSpace(line) == "" {
			if ok {
				t.Fatalf("blank line accepted: %q", line)
			}
			return
		}
		if !ok {
			if e != (UIEvent{}) {
				t.Fatalf("refused line returned a non-zero event: %+v", e)
			}
			return
		}
		if !json.Valid([]byte(strings.TrimSpace(line))) {
			t.Fatalf("accepted invalid JSON: %q", line)
		}
		b, err := json.Marshal(e)
		if err != nil {
			t.Fatalf("marshal: %v", err)
		}
		if e2, ok2 := ParseUIEvent(string(b)); !ok2 || e2 != e {
			t.Fatalf("round-trip mismatch: %+v vs %+v", e, e2)
		}
		const w = 24
		if got := UIProgressWidth(e.Cur, e.Total, w); got < 0 || got > w {
			t.Fatalf("progress width %d outside [0,%d] for cur=%d total=%d",
				got, w, e.Cur, e.Total)
		}
	})
}

// ── port of defaults/dot_local/share/dot-ui/theme.go ────────────────────────

// uiHexRe mirrors dot-ui's hexRe: #rgb and #rrggbb only.
var uiHexRe = regexp.MustCompile(`^#[0-9a-fA-F]{3}([0-9a-fA-F]{3})?$`)

// ValidUIColor mirrors dot-ui's parseColor acceptance test for a DOT_UI_*
// colour override.
func ValidUIColor(v string) bool { return v != "" && uiHexRe.MatchString(v) }

// FuzzUIHexColor: an accepted DOT_UI_* value is a literal #rgb / #rrggbb
// with no shell metacharacter or escape sequence hidden in it — these
// values are interpolated into terminal escape sequences by lipgloss.
func FuzzUIHexColor(f *testing.F) {
	for _, s := range []string{
		"", "#abc", "#ABCDEF", "#1a2b3c", "abc", "#ab", "#abcd", "#gggggg",
		" #abc", "#abc\n", "#abcdef0", "#abc;ls", "#abc\x1b[0m", "#абв",
	} {
		f.Add(s)
	}
	f.Fuzz(func(t *testing.T, v string) {
		if !ValidUIColor(v) {
			return
		}
		if len(v) != 4 && len(v) != 7 {
			t.Fatalf("accepted colour of length %d: %q", len(v), v)
		}
		if v[0] != '#' {
			t.Fatalf("accepted colour without a leading #: %q", v)
		}
		for i := 1; i < len(v); i++ {
			if !strings.ContainsRune("0123456789abcdefABCDEF", rune(v[i])) {
				t.Fatalf("accepted non-hex byte %q at %d in %q", v[i], i, v)
			}
		}
		for _, c := range dangerousChars {
			if strings.ContainsRune(v, c) {
				t.Fatalf("accepted colour contains %q: %q", c, v)
			}
		}
	})
}

// ── port of defaults/dot_local/share/dot-ui/pick.go ─────────────────────────

// UIFuzzyMatch mirrors dot-ui's fuzzyMatch: a case-insensitive rune
// subsequence test. Comparing a query byte against a candidate rune (the
// pre-fix behaviour) made every non-ASCII query unmatchable.
func UIFuzzyMatch(s, query string) bool {
	if query == "" {
		return true
	}
	q := []rune(strings.ToLower(query))
	i := 0
	for _, r := range strings.ToLower(s) {
		if i < len(q) && q[i] == r {
			i++
		}
	}
	return i == len(q)
}

// UIReadItems mirrors dot-ui's readItems: one candidate per line, blanks
// dropped.
func UIReadItems(in string) []string {
	var items []string
	for _, ln := range strings.Split(in, "\n") {
		if strings.TrimSpace(ln) != "" {
			items = append(items, ln)
		}
	}
	return items
}

// FuzzUIPickFilter: the picker must never lose a candidate it should match
// nor invent one. The empty query matches everything, a candidate always
// matches itself in any script, and no blank row survives the reader.
func FuzzUIPickFilter(f *testing.F) {
	for _, c := range [][2]string{
		{"altai-dark\nberlin-dark\ncanary-light\n", "dark"},
		{"a\n\n  \nb\n", ""},
		{"é\nÉ\n", "é"},
		{"日本語\n", "本"},
		{"İstanbul\n", "i"},
		{"no newline", "n"},
	} {
		f.Add(c[0], c[1])
	}
	f.Fuzz(func(t *testing.T, in, query string) {
		items := UIReadItems(in)
		if len(items) > strings.Count(in, "\n")+1 {
			t.Fatalf("reader invented rows: %d from %d lines", len(items), strings.Count(in, "\n")+1)
		}
		for _, it := range items {
			if strings.TrimSpace(it) == "" {
				t.Fatalf("blank candidate survived: %q", it)
			}
			if strings.Contains(it, "\n") {
				t.Fatalf("candidate spans lines: %q", it)
			}
			if !UIFuzzyMatch(it, "") {
				t.Fatalf("empty query must match %q", it)
			}
			if !UIFuzzyMatch(it, it) {
				t.Fatalf("%q must match itself", it)
			}
			if UIFuzzyMatch(it, query) &&
				len([]rune(strings.ToLower(query))) > len([]rune(strings.ToLower(it))) {
				t.Fatalf("query %q longer than candidate %q matched", query, it)
			}
		}
	})
}

// ── port of defaults/dot_local/share/dot-ui/main.go ─────────────────────────

// ParseUIPickArgs mirrors dot-ui's parsePickArgs: --header and --prompt,
// unknown flags ignored, a dangling flag ignored.
func ParseUIPickArgs(args []string) (header, prompt string) {
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--header":
			if i+1 < len(args) {
				i++
				header = args[i]
			}
		case "--prompt":
			if i+1 < len(args) {
				i++
				prompt = args[i]
			}
		}
	}
	return header, prompt
}

// FuzzUIPickArgs: the parser never invents a value — everything it returns
// came verbatim from the argument list — and never panics on any prefix,
// including a dangling trailing flag.
func FuzzUIPickArgs(f *testing.F) {
	f.Add("--header", "Pick a theme", "--prompt", "Theme >")
	f.Add("--header", "--prompt", "x", "--header")
	f.Add("", "", "", "")
	f.Add("--bogus", "-h", "--prompt", "$(id)")
	f.Fuzz(func(t *testing.T, a, b, c, d string) {
		args := []string{a, b, c, d}
		h, p := ParseUIPickArgs(args)
		fromArgs := func(s string) bool {
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
		if !fromArgs(h) || !fromArgs(p) {
			t.Fatalf("ParseUIPickArgs(%q) invented (%q,%q)", args, h, p)
		}
		for n := 0; n <= len(args); n++ {
			ParseUIPickArgs(args[:n])
		}
	})
}

// ── port of defaults/dot_local/share/dot-ui/table.go ────────────────────────

// unitSep mirrors dot-ui's row delimiter.
const unitSep = "\x1f"

// SplitUITable mirrors dot-ui's runTable input handling: the first line is
// the header, the rest are rows, each split on the unit separator.
func SplitUITable(in string) (headers []string, rows [][]string) {
	for _, ln := range strings.Split(in, "\n") {
		if ln == "" && headers == nil {
			continue
		}
		fields := strings.Split(ln, unitSep)
		if headers == nil {
			headers = fields
			continue
		}
		rows = append(rows, fields)
	}
	return headers, rows
}

// FuzzUITableRows: the splitter never drops or fabricates a cell, so a
// value can never migrate into a neighbouring column when rendered.
func FuzzUITableRows(f *testing.F) {
	f.Add("Alias\x1fExpands\x1fTier\nll\x1fls -alFh\x1fcore\n")
	f.Add("")
	f.Add("\n")
	f.Add("only\x1fheaders")
	f.Add("a\x1fb\nc\nd\x1fe\x1ff\x1fg\n")
	f.Add("\x1f\x1f\n\x1f\n")
	f.Fuzz(func(t *testing.T, in string) {
		headers, rows := SplitUITable(in)
		if headers == nil {
			if len(rows) != 0 {
				t.Fatalf("rows without a header: %v", rows)
			}
			return
		}
		for _, r := range rows {
			for _, cell := range r {
				if strings.Contains(cell, unitSep) || strings.Contains(cell, "\n") {
					t.Fatalf("cell still contains a delimiter: %q", cell)
				}
			}
		}
		// The split is reversible: re-joining every row with the separator
		// and re-splitting yields exactly the same grid, so no cell can be
		// merged into, or leak across, a neighbouring column.
		lines := []string{strings.Join(headers, unitSep)}
		for _, r := range rows {
			lines = append(lines, strings.Join(r, unitSep))
		}
		h2, r2 := SplitUITable(strings.Join(lines, "\n"))
		if len(h2) != len(headers) {
			t.Fatalf("header re-split into %d cells, want %d", len(h2), len(headers))
		}
		for i := range headers {
			if h2[i] != headers[i] {
				t.Fatalf("header cell %d changed: %q -> %q", i, headers[i], h2[i])
			}
		}
		if len(r2) != len(rows) {
			t.Fatalf("re-split produced %d rows, want %d", len(r2), len(rows))
		}
		for i := range rows {
			if len(r2[i]) != len(rows[i]) {
				t.Fatalf("row %d re-split into %d cells, want %d", i, len(r2[i]), len(rows[i]))
			}
			for j := range rows[i] {
				if r2[i][j] != rows[i][j] {
					t.Fatalf("cell [%d][%d] changed: %q -> %q", i, j, rows[i][j], r2[i][j])
				}
			}
		}
	})
}
