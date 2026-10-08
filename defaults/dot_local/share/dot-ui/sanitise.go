// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// Terminal-output sanitising. Every string that reaches the screen comes from
// another process (table rows, picker items, NDJSON events), so a crafted
// value could carry escape sequences (OSC 52 clipboard writes, screen clears,
// C1 CSI) or bidi overrides that make the text read differently from what it
// is (CWE-150, CWE-451). clean neutralises both before lipgloss sees them.
package main

import (
	"strings"
	"unicode"
)

// clean replaces C0/C1 control characters (except tab and newline) and the
// bidi embedding/override (U+202A–U+202E) and isolate (U+2066–U+2069)
// characters with U+FFFD, so they show up instead of acting on the terminal.
func clean(s string) string {
	return strings.Map(func(r rune) rune {
		if r == '\t' || r == '\n' {
			return r
		}
		if unicode.IsControl(r) || (r >= 0x202A && r <= 0x202E) || (r >= 0x2066 && r <= 0x2069) {
			return unicode.ReplacementChar
		}
		return r
	}, s)
}
