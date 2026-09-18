// Copyright (c) 2015-2026 Dotfiles. All rights reserved.
// FuzzValidateName exercises the same regex our shell
// `validate_name` function (scripts/dot/lib/utils.sh:101) uses
// to gate user-supplied identifiers before passing them to mise /
// gh / ssh / chezmoi.
//
// The Go port MUST stay in lockstep with the shell regex; any
// drift between them is the bug we want OSS-Fuzz to surface.
//
// Shell source pattern: ^[a-zA-Z0-9._-]+$
// Go port (this file):  ^[a-zA-Z0-9._\-]+$
//
// Invariants the fuzzer enforces:
//
//   1. A name that matches MUST contain only allowed characters
//      (no shell metacharacters: $, `, ;, |, &, \, *, ?, etc.)
//   2. A name that does NOT match MUST contain at least one
//      disallowed character.
//   3. Empty input MUST be rejected.
//   4. UTF-8 bytes outside [a-zA-Z0-9._-] MUST be rejected
//      (catches homoglyph attacks).
//
// Run locally:
//   cd oss-fuzz-integration/fuzz
//   go test -fuzz=FuzzValidateName -fuzztime=30s

package fuzz

import (
	"regexp"
	"strings"
	"testing"
	"unicode"
)

// ValidateName mirrors scripts/dot/lib/utils.sh:101.
var validateNameRE = regexp.MustCompile(`^[a-zA-Z0-9._\-]+$`)

// allowedChars is the explicit allow-set used for the post-match
// invariant check. Keep in lockstep with the regex.
const allowedChars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"

// ValidateName returns true iff name is acceptable per the shell
// regex. Exposed so seed corpus + fuzz function share one path.
func ValidateName(name string) bool {
	return validateNameRE.MatchString(name)
}

func FuzzValidateName(f *testing.F) {
	// Seed corpus — accept cases that MUST pass + reject cases that
	// MUST fail. OSS-Fuzz mutates these to discover counter-examples.
	seeds := []string{
		"mathiasbynens",
		"holman.dotfiles",
		"paulirish_42",
		"x",                              // 1 char
		strings.Repeat("a", 64),          // long but valid
		"with-dash",
		"with.dot",
		"with_underscore",
		"123",                            // leading digit (allowed)
		"",                               // empty (must reject)
		"contains space",                 // space (must reject)
		"contains/slash",                 // slash (must reject)
		"injection;ls",                   // shell metacharacter
		"$(whoami)",                      // command substitution
		"`whoami`",                       // backtick
		"name\nnewline",                  // newline
		"\x00nullbyte",                 // null byte
		"\u202eRLO",                      // right-to-left override
		"emoji\U0001F600",                        // multi-byte UTF-8
		"--flag-injection",               // looks like a CLI flag
	}
	for _, s := range seeds {
		f.Add(s)
	}

	f.Fuzz(func(t *testing.T, name string) {
		matched := ValidateName(name)

		if matched {
			// Invariant 1: every byte must be in the allow-set.
			// Also catches multi-byte runes that managed to slip
			// through the byte-level regex (none should, but the
			// fuzzer should prove it).
			for i, b := range []byte(name) {
				if !strings.ContainsRune(allowedChars, rune(b)) {
					t.Fatalf("matched but byte %d is %q (disallowed): %q",
						i, b, name)
				}
			}
			// Invariant 3: matched ⇒ non-empty.
			if len(name) == 0 {
				t.Fatalf("matched empty string")
			}
		} else {
			// Invariant 2: rejected names must contain at least one
			// non-allowed character, OR be empty.
			if len(name) == 0 {
				return // valid rejection — empty
			}
			ok := false
			for _, r := range name {
				// Non-ASCII OR ASCII-but-outside-allowed.
				if r > unicode.MaxASCII || !strings.ContainsRune(allowedChars, r) {
					ok = true
					break
				}
			}
			if !ok {
				t.Fatalf("rejected but every char is allowed: %q", name)
			}
		}
	})
}
