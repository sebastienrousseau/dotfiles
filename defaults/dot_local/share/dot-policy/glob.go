// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package main

import (
	"regexp"
	"strings"
	"unicode/utf8"
)

// Glob syntax, the same in every list:
//
//   - any run of characters without a "/"
//     **   any run of characters, "/" included; "dir/**" also matches dir
//     ?    one character other than "/"
//
// Commands are matched with slash false, so there "*" crosses "/" too: a
// command pattern such as "rm -rf *" covers "rm -rf /tmp/x".
func globRegexp(pat string, slash bool) *regexp.Regexp {
	var b strings.Builder
	b.WriteString("^")
	for i := 0; i < len(pat); i++ {
		i += globToken(&b, pat, i, slash)
	}
	b.WriteString("$")
	return regexp.MustCompile(b.String())
}

// globToken writes the regexp for the token at pat[i] and returns how
// many extra bytes it consumed.
func globToken(b *strings.Builder, pat string, i int, slash bool) int {
	one := "[^/]"
	if !slash {
		one = "."
	}
	switch {
	case strings.HasPrefix(pat[i:], "/**") && i+3 == len(pat):
		b.WriteString("(/.*)?")
		return 2
	case strings.HasPrefix(pat[i:], "**"):
		b.WriteString(".*")
		return 1
	case pat[i] == '*':
		b.WriteString(one + "*")
	case pat[i] == '?':
		b.WriteString(one)
	default:
		// One whole rune; a byte that is not UTF-8 becomes U+FFFD, which a
		// path or command never holds, so it matches nothing.
		r, n := utf8.DecodeRuneInString(pat[i:])
		b.WriteString(regexp.QuoteMeta(string(r)))
		return n - 1
	}
	return 0
}

// matchAny says whether s matches one of the patterns, after expand
// rewrites each.
func matchAny(pats []string, s string, slash bool, expand func(string) string) bool {
	for _, p := range pats {
		if expand != nil {
			p = expand(p)
		}
		if globRegexp(p, slash).MatchString(s) {
			return true
		}
	}
	return false
}
