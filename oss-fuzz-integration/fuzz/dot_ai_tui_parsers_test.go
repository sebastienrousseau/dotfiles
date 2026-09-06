// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// OSS-Fuzz harnesses for the dot-ai-tui (cockpit) input parsers.
//
// dot-ai-tui lives in its own `package main` module
// (defaults/dot_local/share/dot-ai-tui), which OSS-Fuzz's
// compile_native_go_fuzzer cannot import — it needs a library package. So,
// exactly as the shell harnesses in this directory port shell logic into
// Go, these port the cockpit's parsers and are kept in lockstep with them.
// Drift between a port and its original IS the bug class these harnesses
// exist to surface.
//
// The same functions are also fuzzed in-module (dot-ai-tui/fuzz_test.go)
// where they run against the real implementation on every push; these
// ports are what runs continuously at scale on OSS-Fuzz / ClusterFuzzLite.
//
// Run locally:
//
//	cd oss-fuzz-integration/fuzz
//	go test -run '^$' -fuzz=FuzzAISessionFile -fuzztime=30s ./...

package fuzz

import (
	"encoding/json"
	"regexp"
	"strings"
	"testing"
)

// ── port of defaults/dot_local/share/dot-ai-tui/main.go ─────────────────────

// AISessLine mirrors the cockpit's sessLine — one persisted chat turn.
type AISessLine struct{ Who, Text string }

// ParseAISession mirrors the cockpit's parseSession: a corrupt session file
// must load as nothing rather than as a partial transcript.
func ParseAISession(b []byte) []AISessLine {
	var s []AISessLine
	if json.Unmarshal(b, &s) != nil {
		return nil
	}
	return s
}

// FuzzAISessionFile: the saved-session file is on disk and is replayed into
// the transcript by /resume, so a malformed or hostile file must decode to
// nothing, never to a partial or mutated transcript.
func FuzzAISessionFile(f *testing.F) {
	for _, s := range []string{
		`[{"Who":"you","Text":"hi"},{"Who":"claude","Text":"yo\nthere"}]`,
		`[]`, `{}`, `garbage`, ``, `[{"Who":1}]`, `null`,
		"[{\"Who\":\"you\",\"Text\":\"\\u0000\\u001b[0m\"}]",
		`[` + strings.Repeat(`{"Who":"a","Text":"b"},`, 64) + `{"Who":"z","Text":"z"}]`,
	} {
		f.Add([]byte(s))
	}
	f.Fuzz(func(t *testing.T, data []byte) {
		got := ParseAISession(data)
		if got == nil {
			return
		}
		b, err := json.Marshal(got)
		if err != nil {
			t.Fatalf("marshal: %v", err)
		}
		again := ParseAISession(b)
		if len(again) != len(got) {
			t.Fatalf("round-trip changed length: %d -> %d", len(got), len(again))
		}
		for i := range got {
			if got[i] != again[i] {
				t.Fatalf("round-trip changed line %d: %+v -> %+v", i, got[i], again[i])
			}
		}
	})
}

// FilterAISqliteOutput mirrors the cockpit's filterSqliteOutput. sqlite3
// reads ~/.sqliterc, which can turn on .timer/.headers and inject meta
// lines into what the cockpit parses as cost and run data.
func FilterAISqliteOutput(b []byte) string {
	var keep []string
	for _, ln := range strings.Split(strings.TrimSpace(string(b)), "\n") {
		if strings.HasPrefix(ln, "Run Time:") || strings.HasPrefix(strings.TrimSpace(ln), ".") {
			continue
		}
		keep = append(keep, ln)
	}
	return strings.TrimSpace(strings.Join(keep, "\n"))
}

// FuzzAISqliteOutput: no sqlite3 meta line may survive into the data the
// cockpit renders, and the result is always trimmed.
func FuzzAISqliteOutput(f *testing.F) {
	for _, s := range []string{
		"Run Time: real 0.001\n$1.23\n", ".timer on\nrow\n", "", "   \n\n  ",
		"keep\n   .dot\nkeep2", "only\nRun Time: x", ".\n..\n...",
	} {
		f.Add([]byte(s))
	}
	f.Fuzz(func(t *testing.T, data []byte) {
		out := FilterAISqliteOutput(data)
		if out != strings.TrimSpace(out) {
			t.Fatalf("result not trimmed: %q", out)
		}
		if out == "" {
			return
		}
		for _, ln := range strings.Split(out, "\n") {
			if strings.HasPrefix(ln, "Run Time:") {
				t.Fatalf("timer meta line survived: %q", ln)
			}
			if strings.HasPrefix(strings.TrimSpace(ln), ".") {
				t.Fatalf("dot-command meta line survived: %q", ln)
			}
		}
	})
}

// aiLangRe mirrors the cockpit's langRe: the bound on a fenced block's info
// string. chroma resolves an unknown lexer name by glob-matching it against
// every registered filename pattern — work linear in the name's length — so
// an unbounded tag from model output stalled every render.
var aiLangRe = regexp.MustCompile(`^[A-Za-z0-9_+#.-]{1,32}$`)

// ValidAILangTag mirrors the cockpit's fence-tag acceptance test.
func ValidAILangTag(lang string) bool { return aiLangRe.MatchString(lang) }

// SplitAIFences mirrors the cockpit's highlight() segmentation: even
// segments are prose, odd segments are code whose first line is the info
// string.
func SplitAIFences(text string) (langs []string, prose []string) {
	if !strings.Contains(text, "```") {
		return nil, []string{text}
	}
	for i, p := range strings.Split(text, "```") {
		if i%2 == 0 {
			prose = append(prose, p)
			continue
		}
		lang := ""
		if nl := strings.IndexByte(p, '\n'); nl >= 0 {
			lang = strings.TrimSpace(p[:nl])
		}
		langs = append(langs, lang)
	}
	return langs, prose
}

// FuzzAIFenceTag: model output is untrusted. Every fence info string
// extracted from it must be either refused or a short identifier, so the
// unbounded-lexer-lookup stall cannot recur; prose segments must survive
// segmentation unchanged.
func FuzzAIFenceTag(f *testing.F) {
	for _, s := range []string{
		"just prose", "```go\nvar x = 1\n```", "```\nno lang\n```", "```inline```",
		"```sh\necho hi", "a```b```c```d", "```\n```\n```",
		"```ts" + strings.Repeat("x", 5000) + "\n```", // the crasher that found the bound
		"``` unknown-lang \n x \n```", "```../../etc/passwd\nx\n```",
		"```a;rm -rf /\nx\n```",
	} {
		f.Add(s)
	}
	f.Fuzz(func(t *testing.T, text string) {
		langs, prose := SplitAIFences(text)
		for _, lang := range langs {
			if !ValidAILangTag(lang) {
				continue // refused: chroma is given "" and uses plaintext
			}
			if n := len(lang); n < 1 || n > 32 {
				t.Fatalf("accepted fence tag of length %d: %q", n, lang)
			}
			for _, r := range lang {
				if !strings.ContainsRune("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_+#.-", r) {
					t.Fatalf("accepted fence tag with %q: %q", r, lang)
				}
			}
			for _, c := range dangerousChars {
				if strings.ContainsRune(lang, c) {
					t.Fatalf("accepted fence tag contains %q: %q", c, lang)
				}
			}
		}
		for _, p := range prose {
			if !strings.Contains(text, p) {
				t.Fatalf("segmentation invented prose: %q", p)
			}
		}
	})
}

// AIGatewayURL mirrors the cockpit's gatewayURL: DOT_AI_HOST / DOT_AI_PORT
// are user-controlled and are used to build the health-check URL.
func AIGatewayURL(host, port string) string { return "http://" + host + ":" + port }

// FuzzAIGatewayURL: the constructed URL always keeps the http scheme and
// carries the configured host and port verbatim, so a crafted env value
// cannot redirect the health check to another scheme.
func FuzzAIGatewayURL(f *testing.F) {
	f.Add("127.0.0.1", "3456")
	f.Add("", "")
	f.Add("[::1]", "80")
	f.Add("evil.example.com/@", "80")
	f.Add("host with space", "not-a-port")
	f.Fuzz(func(t *testing.T, host, port string) {
		u := AIGatewayURL(host, port)
		if !strings.HasPrefix(u, "http://") {
			t.Fatalf("scheme lost: %q", u)
		}
		if !strings.Contains(u, host) || !strings.HasSuffix(u, ":"+port) {
			t.Fatalf("AIGatewayURL(%q,%q)=%q", host, port, u)
		}
	})
}
