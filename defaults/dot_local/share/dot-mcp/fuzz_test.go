// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// Fuzz targets for everything that parses input a peer controls: the frame
// reader, the request decoder, the argument validator, and a whole session.
// The invariant every target asserts is the same one the transport depends on
// — the server never panics, and never writes a line to stdout that is not a
// JSON-RPC object.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"io/fs"
	"strings"
	"testing"
)

// FuzzReadFrames drives the frame reader over arbitrary bytes. The reader must
// terminate, never panic, and never return a frame containing a newline.
func FuzzReadFrames(f *testing.F) {
	f.Add("")
	f.Add("{}\n")
	f.Add("\n\n\n")
	f.Add("{\"jsonrpc\":\"2.0\"}\r\n{}\n")
	f.Add(strings.Repeat("a", 70000) + "\n")
	f.Fuzz(func(t *testing.T, input string) {
		fr := newFrameReader(strings.NewReader(input))
		for i := 0; i < 4096; i++ {
			frame, err := fr.next()
			if err != nil {
				if !errors.Is(err, io.EOF) && !errors.Is(err, errFrameTooLarge) {
					t.Fatalf("unexpected reader error: %v", err)
				}
				return
			}
			if len(frame) == 0 {
				t.Fatal("reader returned an empty frame")
			}
			if strings.ContainsAny(string(frame), "\n") {
				t.Fatalf("frame contains a newline: %q", frame)
			}
		}
		t.Fatal("reader did not terminate")
	})
}

// FuzzDecodeRequest drives the envelope decoder. Either a request comes back
// or an error object does, never both and never a panic.
func FuzzDecodeRequest(f *testing.F) {
	f.Add(`{"jsonrpc":"2.0","id":1,"method":"ping"}`)
	f.Add(`{"jsonrpc":"2.0","method":"notifications/initialized"}`)
	f.Add(`{"jsonrpc":"2.0","id":{"deep":{"deeper":1}},"method":"x"}`)
	f.Add(`{"jsonrpc":"2.0","id":1e309,"method":"x"}`)
	f.Add("")
	f.Add("null")
	f.Fuzz(func(t *testing.T, frame string) {
		req, rerr := decodeRequest([]byte(frame))
		if (req == nil) == (rerr == nil) {
			t.Fatalf("decodeRequest(%q) returned req=%v err=%v", frame, req, rerr)
		}
		if rerr != nil {
			if rerr.Code != codeParseError && rerr.Code != codeInvalidRequest {
				t.Fatalf("unexpected error code %d", rerr.Code)
			}
			return
		}
		if req.Method == "" {
			t.Fatal("accepted an empty method")
		}
		// A decoded request must survive re-encoding, since the id is echoed
		// back verbatim in the response.
		if _, err := json.Marshal(response{JSONRPC: "2.0", ID: req.ID, Result: map[string]any{}}); err != nil {
			t.Fatalf("cannot echo the id back: %v", err)
		}
	})
}

// FuzzValidateArgs drives the schema validator with arbitrary JSON argument
// objects. Accepted arguments must never contain a key the schema does not
// declare, and a string constrained by a pattern must always satisfy it —
// that is what keeps a hostile argument out of the argument vector.
func FuzzValidateArgs(f *testing.F) {
	f.Add(`{"action":"show","profile":"audit"}`)
	f.Add(`{"action":"list"}`)
	f.Add(`{"profile":"../../etc/passwd"}`)
	f.Add(`{"strict":true}`)
	f.Add(`{}`)
	f.Add(`{"__proto__":{}}`)
	schemas := map[string]inputSchema{}
	for _, tl := range defaultTools() {
		schemas[tl.Name] = tl.Schema
	}
	f.Fuzz(func(t *testing.T, raw string) {
		var args map[string]any
		if err := json.Unmarshal([]byte(raw), &args); err != nil {
			return // not an argument object; the server rejects it earlier
		}
		for name, schema := range schemas {
			out, rerr := validateArgs(schema, args)
			if rerr != nil {
				if rerr.Code != codeInvalidParams && rerr.Code != codeInternalError {
					t.Fatalf("%s: unexpected error code %d", name, rerr.Code)
				}
				continue
			}
			for k, v := range out {
				prop, ok := schema.Properties[k]
				if !ok {
					t.Fatalf("%s: accepted undeclared argument %q", name, k)
				}
				s, isString := v.(string)
				if !isString {
					continue
				}
				if prop.re != nil && !prop.re.MatchString(s) {
					t.Fatalf("%s: accepted %q for %q, which violates %s", name, s, k, prop.Pattern)
				}
				if len(prop.Enum) > 0 && !containsString(prop.Enum, s) {
					t.Fatalf("%s: accepted %q for %q, which is outside the enum", name, s, k)
				}
			}
			// Whatever survived validation must produce an argument vector,
			// and no element of it may be an option the tool did not intend.
			for _, arg := range toolByName(name).argv(out) {
				if strings.HasPrefix(arg, "-") && !containsString([]string{"--json", "--strict"}, arg) {
					t.Fatalf("%s: argv contains an unexpected option %q", name, arg)
				}
			}
		}
	})
}

// toolByName looks a tool up in a fresh registry.
func toolByName(name string) tool {
	for _, tl := range defaultTools() {
		if tl.Name == name {
			return tl
		}
	}
	panic("no such tool: " + name)
}

// FuzzServeSession drives a whole session over arbitrary input. Every line the
// server writes to stdout must be a JSON-RPC object, whatever it was fed.
func FuzzServeSession(f *testing.F) {
	f.Add(initFrame)
	f.Add(initFrame + "\n" + `{"jsonrpc":"2.0","id":2,"method":"tools/list"}`)
	f.Add(`{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"mcp-doctor"}}`)
	f.Add(`{"jsonrpc":"2.0","id":2,"method":"resources/read","params":{"uri":"dotfiles://mcp/policy"}}`)
	f.Add("garbage\n{\n[]\n")
	f.Fuzz(func(t *testing.T, input string) {
		var out, logs strings.Builder
		srv := NewServer(strings.NewReader(input), &out, &logs)
		srv.run = func(context.Context, string, []string, []string) (commandResult, error) {
			return commandResult{Stdout: `{"ok":true}`}, nil
		}
		srv.env = fakeEnv(map[string]string{"__wd": "/", "__home": "/h"})
		srv.readFile = func(string) ([]byte, error) { return nil, fs.ErrNotExist }
		if err := srv.Serve(); err != nil {
			t.Fatalf("Serve: %v", err)
		}
		for _, line := range strings.Split(strings.TrimRight(out.String(), "\n"), "\n") {
			if line == "" {
				continue
			}
			var m map[string]any
			if err := json.Unmarshal([]byte(line), &m); err != nil {
				t.Fatalf("stdout carried a non-JSON line %q", line)
			}
			if m["jsonrpc"] != "2.0" {
				t.Fatalf("stdout carried a non-JSON-RPC frame %q", line)
			}
		}
	})
}

// FuzzBuildCallResult drives the result classifier with arbitrary command
// output. The result must always carry exactly one non-empty text block, so a
// client never receives a content-free tool result.
func FuzzBuildCallResult(f *testing.F) {
	f.Add(`{"status":"healthy"}`, "", 0)
	f.Add("", "boom", 1)
	f.Add("[1,2,3]", "", 0)
	f.Add("{", "", 127)
	f.Fuzz(func(t *testing.T, stdout, stderr string, code int) {
		res := buildCallResult(commandResult{Stdout: stdout, Stderr: stderr, ExitCode: code})
		if len(res.Content) != 1 {
			t.Fatalf("got %d content blocks, want 1", len(res.Content))
		}
		if res.Content[0].Type != "text" || res.Content[0].Text == "" {
			t.Fatalf("content = %+v", res.Content[0])
		}
		if _, err := json.Marshal(res); err != nil {
			t.Fatalf("result does not marshal: %v", err)
		}
	})
}
