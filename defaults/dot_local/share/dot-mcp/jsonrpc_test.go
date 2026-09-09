// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
package main

import (
	"encoding/json"
	"errors"
	"io"
	"strings"
	"testing"
)

// errWriter fails every write, standing in for a client that hung up.
type errWriter struct{ err error }

func (w errWriter) Write([]byte) (int, error) { return 0, w.err }

// errReader fails every read with a non-EOF error.
type errReader struct{ err error }

func (r errReader) Read([]byte) (int, error) { return 0, r.err }

// TestDecodeRequest covers envelope validation: what is accepted, and which
// JSON-RPC code each rejection maps to.
func TestDecodeRequest(t *testing.T) {
	tests := []struct {
		name     string
		frame    string
		wantCode int
		wantNote bool // expect a notification (no id)
	}{
		{name: "request", frame: `{"jsonrpc":"2.0","id":1,"method":"ping"}`},
		{name: "string id", frame: `{"jsonrpc":"2.0","id":"a","method":"ping"}`},
		{name: "null id is a notification", frame: `{"jsonrpc":"2.0","id":null,"method":"ping"}`, wantNote: true},
		{name: "no id is a notification", frame: `{"jsonrpc":"2.0","method":"ping"}`, wantNote: true},
		{name: "malformed json", frame: `{`, wantCode: codeParseError},
		{name: "not an object", frame: `[1,2,3]`, wantCode: codeParseError},
		{name: "wrong version", frame: `{"jsonrpc":"1.0","id":1,"method":"ping"}`, wantCode: codeInvalidRequest},
		{name: "missing version", frame: `{"id":1,"method":"ping"}`, wantCode: codeInvalidRequest},
		{name: "empty method", frame: `{"jsonrpc":"2.0","id":1,"method":""}`, wantCode: codeInvalidRequest},
		{name: "object id", frame: `{"jsonrpc":"2.0","id":{"a":1},"method":"ping"}`, wantCode: codeInvalidRequest},
		{name: "array id", frame: `{"jsonrpc":"2.0","id":[1],"method":"ping"}`, wantCode: codeInvalidRequest},
		{name: "bool id", frame: `{"jsonrpc":"2.0","id":true,"method":"ping"}`, wantCode: codeInvalidRequest},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			req, rerr := decodeRequest([]byte(tc.frame))
			if tc.wantCode != 0 {
				if rerr == nil {
					t.Fatalf("expected error code %d, got a valid request", tc.wantCode)
				}
				if rerr.Code != tc.wantCode {
					t.Fatalf("code = %d, want %d (%s)", rerr.Code, tc.wantCode, rerr.Message)
				}
				return
			}
			if rerr != nil {
				t.Fatalf("unexpected error: %v", rerr)
			}
			if got := req.isNotification(); got != tc.wantNote {
				t.Fatalf("isNotification = %v, want %v", got, tc.wantNote)
			}
		})
	}
}

// TestValidIDRejectsGarbage covers the branch where the id is not decodable at
// all, which decodeRequest cannot reach because json.Unmarshal has already
// validated the whole frame.
func TestValidIDRejectsGarbage(t *testing.T) {
	if validID(json.RawMessage("{oops")) {
		t.Fatal("undecodable id accepted")
	}
}

// TestRPCErrorImplementsError pins the error string, which surfaces in stderr
// diagnostics.
func TestRPCErrorImplementsError(t *testing.T) {
	var err error = newRPCError(codeInvalidParams, "invalid params", "detail")
	if got, want := err.Error(), "jsonrpc -32602: invalid params"; got != want {
		t.Fatalf("Error() = %q, want %q", got, want)
	}
}

// TestFrameReader covers framing: blank-line skipping, CRLF, a line longer
// than the bufio buffer, a trailing fragment with no newline, and EOF.
func TestFrameReader(t *testing.T) {
	long := strings.Repeat("x", 200<<10)
	tests := []struct {
		name  string
		input string
		want  []string
	}{
		{name: "single frame", input: "a\n", want: []string{"a"}},
		{name: "blank lines skipped", input: "\n\n a \n\n", want: []string{" a "}},
		{name: "crlf trimmed", input: "a\r\nb\r\n", want: []string{"a", "b"}},
		{name: "trailing fragment", input: "a\nb", want: []string{"a", "b"}},
		{name: "longer than the buffer", input: long + "\n", want: []string{long}},
		{name: "empty stream", input: "", want: nil},
		{name: "only newlines", input: "\n\n\n", want: nil},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			fr := newFrameReader(strings.NewReader(tc.input))
			var got []string
			for {
				frame, err := fr.next()
				if err != nil {
					if !errors.Is(err, io.EOF) {
						t.Fatalf("next: %v", err)
					}
					break
				}
				got = append(got, string(frame))
			}
			if len(got) != len(tc.want) {
				t.Fatalf("got %d frames, want %d", len(got), len(tc.want))
			}
			for i := range got {
				if got[i] != tc.want[i] {
					t.Fatalf("frame %d = %q, want %q", i, got[i], tc.want[i])
				}
			}
		})
	}
}

// TestFrameReaderRejectsOversizeFrame pins the memory guard.
func TestFrameReaderRejectsOversizeFrame(t *testing.T) {
	fr := newFrameReader(strings.NewReader(strings.Repeat("x", 4096)))
	fr.limit = 1024
	if _, err := fr.next(); !errors.Is(err, errFrameTooLarge) {
		t.Fatalf("err = %v, want errFrameTooLarge", err)
	}
}

// TestFrameReaderPropagatesReadError pins that a transport failure is not
// mistaken for a clean end of stream.
func TestFrameReaderPropagatesReadError(t *testing.T) {
	sentinel := errors.New("device is on fire")
	fr := newFrameReader(errReader{err: sentinel})
	if _, err := fr.next(); !errors.Is(err, sentinel) {
		t.Fatalf("err = %v, want %v", err, sentinel)
	}
}

// TestTrimEOL covers the terminator variants directly, including a bare CR
// that no reader path produces on its own.
func TestTrimEOL(t *testing.T) {
	tests := []struct{ in, want string }{
		{"a\n", "a"}, {"a\r\n", "a"}, {"a\r", "a"}, {"a", "a"}, {"", ""}, {"\n", ""},
	}
	for _, tc := range tests {
		if got := string(trimEOL([]byte(tc.in))); got != tc.want {
			t.Errorf("trimEOL(%q) = %q, want %q", tc.in, got, tc.want)
		}
	}
}

// TestFrameWriter covers the three outgoing shapes and the id substitution.
func TestFrameWriter(t *testing.T) {
	var buf strings.Builder
	fw := newFrameWriter(&buf)
	if err := fw.writeResult(json.RawMessage("7"), map[string]any{"ok": true}); err != nil {
		t.Fatal(err)
	}
	if err := fw.writeError(nil, newRPCError(codeMethodNotFound, "method not found", "nope")); err != nil {
		t.Fatal(err)
	}
	if err := fw.writeNotification("notifications/message", map[string]any{"level": "info"}); err != nil {
		t.Fatal(err)
	}
	lines := strings.Split(strings.TrimRight(buf.String(), "\n"), "\n")
	if len(lines) != 3 {
		t.Fatalf("got %d frames, want 3: %q", len(lines), buf.String())
	}
	var res response
	if err := json.Unmarshal([]byte(lines[0]), &res); err != nil {
		t.Fatal(err)
	}
	if res.JSONRPC != "2.0" || string(res.ID) != "7" {
		t.Fatalf("result frame = %+v", res)
	}
	if !strings.Contains(lines[1], `"id":null`) || !strings.Contains(lines[1], `"code":-32601`) {
		t.Fatalf("error frame = %s", lines[1])
	}
	if strings.Contains(lines[2], `"id"`) {
		t.Fatalf("notification must carry no id: %s", lines[2])
	}
}

// TestFrameWriterErrors covers an unmarshalable payload and a dead pipe.
func TestFrameWriterErrors(t *testing.T) {
	fw := newFrameWriter(&strings.Builder{})
	if err := fw.write(map[string]any{"bad": make(chan int)}); err == nil {
		t.Fatal("expected a marshal error")
	}
	sentinel := errors.New("broken pipe")
	fw = newFrameWriter(errWriter{err: sentinel})
	if err := fw.writeResult(nil, map[string]any{}); !errors.Is(err, sentinel) {
		t.Fatalf("err = %v, want %v", err, sentinel)
	}
	if err := fw.writeError(json.RawMessage("1"), newRPCError(codeInternalError, "x", nil)); !errors.Is(err, sentinel) {
		t.Fatalf("err = %v, want %v", err, sentinel)
	}
	if err := fw.writeNotification("m", nil); !errors.Is(err, sentinel) {
		t.Fatalf("err = %v, want %v", err, sentinel)
	}
}
