// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package protocol

import (
	"bufio"
	"bytes"
	"strings"
	"testing"
)

func TestRoundTrip(t *testing.T) {
	var b bytes.Buffer
	m := Message{JSONRPC: "2.0", ID: 1, Method: "dot.initialize", Params: Value(Initialize{1, strings.Repeat("a", 64)})}
	if err := Write(&b, m); err != nil {
		t.Fatal(err)
	}
	got, err := Read(bufio.NewReaderSize(&b, 128))
	if err != nil || got.Method != m.Method {
		t.Fatal(got, err)
	}
}
func TestReject(t *testing.T) {
	for _, s := range []string{"noise\n", "Content-Length: 65537\r\n\r\n", "Content-Length: -1\r\n\r\n", "Content-Length: 1\n\n{", "Content-Length: 1\r\nOther: x\r\n\r\n{", "Content-Length: 4\r\n\r\n{}"} {
		if _, err := Read(bufio.NewReaderSize(strings.NewReader(s), 128)); err == nil {
			t.Fatal(s)
		}
	}
	for _, s := range []string{`{"protocol":1,"protocol":2}`, `{"unexpected":1}`, `{} {}`, strings.Repeat("[", 20) + strings.Repeat("]", 20)} {
		var dst Initialize
		if err := Strict([]byte(s), &dst); err == nil {
			t.Fatal(s)
		}
	}
}
func FuzzFrames(f *testing.F) {
	f.Add([]byte("Content-Length: 2\r\n\r\n{}"))
	f.Fuzz(func(t *testing.T, b []byte) {
		if len(b) > MaxFrame+256 {
			t.Skip()
		}
		Read(bufio.NewReaderSize(bytes.NewReader(b), 128))
	})
}
