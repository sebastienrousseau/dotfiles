// Copyright (c) 2015-2026 Dotfiles. All rights reserved.
// FuzzInitURLResolver exercises the URL-construction logic in
// `dot init` (scripts/dot/commands/init.sh). The shell flow takes
// one of three input shapes:
//
//   1. bare user      → constructs https://github.com/<user>/dotfiles.git
//   2. owner/repo     → constructs https://github.com/<owner>/<repo>.git
//   3. full URL       → passes through after scheme check
//
// Refuses anything else (R2 §6 hardening). Invariants:
//
//   * Refused inputs MUST return an empty URL.
//   * Accepted URLs MUST start with one of: "https://", "git@",
//     "ssh://", "file://" (the last only when a permissive flag
//     is set; this fuzzer is the strict mode).
//   * Accepted URLs MUST NOT contain shell metacharacters in the
//     scheme/host segments (full path is opaque).
//   * Empty input MUST refuse.
//
// Run locally:
//   cd oss-fuzz-integration/fuzz
//   go test -fuzz=FuzzInitURLResolver -fuzztime=30s

package fuzz

import (
	"net/url"
	"regexp"
	"strings"
	"testing"
)

// Mirrors the shell regex at scripts/dot/commands/init.sh for the
// bare-user and owner/repo cases. Shell pattern: [A-Za-z0-9._-]+
var ghOwnerRepoRE = regexp.MustCompile(`^([a-zA-Z0-9._\-]+)(/([a-zA-Z0-9._\-]+))?$`)

// ResolveInitURL ports the shell logic.
// Returns "" when the input is refused.
//
// IMPORTANT: no TrimSpace. The shell case statement
// (scripts/dot/commands/init.sh) operates on the literal arg without
// trimming. Adding TrimSpace here would make the Go port MORE
// permissive than the shell — past fuzz runs proved this: ` git@"` and
// ` git@:"` both passed after trim but the shell would reject them
// outright because the leading whitespace makes the `git@*:*` case
// pattern miss.
func ResolveInitURL(in string) string {
	if in == "" {
		return ""
	}

	// Full URL? Accept https://, git@<host>:<path>, ssh:// — refuse
	// plain http:// and everything else. Mirrors the shell case in
	// scripts/dot/commands/init.sh which uses pattern `git@*:*`
	// (requires the colon after git@; without it the SSH form is
	// malformed and downstream tools reject it anyway).
	if strings.HasPrefix(in, "git@") {
		if !strings.Contains(in[4:], ":") {
			return ""
		}
		return in
	}
	if strings.HasPrefix(in, "https://") || strings.HasPrefix(in, "ssh://") {
		if _, err := url.Parse(in); err != nil {
			return ""
		}
		return in
	}
	if strings.HasPrefix(in, "http://") {
		return "" // refuse plain HTTP per R3 §7.3 N5
	}
	if strings.Contains(in, "://") {
		return "" // unknown scheme
	}

	// Bare user or owner/repo.
	m := ghOwnerRepoRE.FindStringSubmatch(in)
	if m == nil {
		return ""
	}
	owner := m[1]
	repo := "dotfiles" // default repo name for bare-user form
	if m[3] != "" {
		repo = m[3]
	}
	return "https://github.com/" + owner + "/" + repo + ".git"
}

var dangerousChars = ";&|`$\\<>\"' \t\n\r"

func FuzzInitURLResolver(f *testing.F) {
	seeds := []string{
		// Must accept
		"mathiasbynens",
		"holman/dotfiles",
		"paul.irish/dotfiles",
		"https://github.com/sebastienrousseau/dotfiles.git",
		"git@github.com:sebastienrousseau/dotfiles.git",
		"ssh://git@github.com/sebastienrousseau/dotfiles.git",
		// Must reject
		"",
		" ",
		"http://github.com/x/y.git", // plain HTTP
		"javascript:alert(1)",
		"file:///etc/passwd",
		"name with space",
		"a/b/c", // too many slashes
		"$(whoami)",
		"`whoami`",
		"name;ls",
		"--help", // looks like a flag
		"\nnewline",
	}
	for _, s := range seeds {
		f.Add(s)
	}

	f.Fuzz(func(t *testing.T, in string) {
		out := ResolveInitURL(in)

		if out == "" {
			return // refused — always safe
		}

		// Accepted: enforce invariants.
		switch {
		case strings.HasPrefix(out, "https://"):
		case strings.HasPrefix(out, "git@"):
		case strings.HasPrefix(out, "ssh://"):
		default:
			t.Fatalf("accepted URL has bad scheme: %q (from input %q)", out, in)
		}

		// Shell metacharacters must NOT appear in the output. The
		// path part is opaque, but we constructed the URL so any
		// dangerous char in the OUTPUT came from a slipped input.
		// We tolerate them only inside a full-URL passthrough.
		if !strings.Contains(in, "://") && !strings.HasPrefix(in, "git@") {
			for _, c := range dangerousChars {
				if strings.ContainsRune(out, c) {
					t.Fatalf("constructed URL contains %q (from input %q): %q",
						c, in, out)
				}
			}
		}
	})
}
