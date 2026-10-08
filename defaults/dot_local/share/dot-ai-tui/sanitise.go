// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// Terminal-output sanitising. Model replies, saved sessions and db rows all
// come from outside this process, so a crafted value could carry escape
// sequences (OSC 52 clipboard writes, screen clears, C1 CSI) or bidi
// overrides that make text read differently from what it is (CWE-150,
// CWE-451). clean neutralises both before the text is highlighted or drawn;
// chroma's own colour codes are added afterwards and survive.
package main

import (
	"io"
	"strings"
	"unicode"
	"unicode/utf8"
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

// pumpChunks forwards r to ch in read-sized chunks that never end inside a
// multi-byte rune, so per-chunk cleaning cannot turn a rune split across two
// reads into a pair of U+FFFD. Bytes still pending at EOF are flushed as is.
func pumpChunks(r io.Reader, ch chan<- streamMsg) {
	buf := make([]byte, 512)
	var pending []byte
	for {
		n, rerr := r.Read(buf)
		data := append(pending, buf[:n]...)
		cut := completePrefix(data)
		if cut > 0 {
			ch <- streamMsg{chunk: string(data[:cut])}
		}
		pending = append([]byte(nil), data[cut:]...)
		if rerr != nil {
			break
		}
	}
	if len(pending) > 0 {
		ch <- streamMsg{chunk: string(pending)}
	}
}

// completePrefix returns the length of b without a trailing incomplete
// UTF-8 sequence. Invalid bytes count as complete (they decode as width 1).
func completePrefix(b []byte) int {
	for i := len(b) - 1; i >= 0 && i > len(b)-utf8.UTFMax; i-- {
		if utf8.RuneStart(b[i]) {
			if utf8.FullRune(b[i:]) {
				return len(b)
			}
			return i
		}
	}
	return len(b)
}
