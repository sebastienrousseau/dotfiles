// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// Benchmarks for the per-frame hot path. An MCP client sends a frame per user
// action, so none of this is throughput-critical; the numbers exist to catch a
// regression that turns a microsecond into a millisecond.
package main

import (
	"context"
	"io"
	"io/fs"
	"strings"
	"testing"
)

// benchServer builds a server with inert seams over the given input.
func benchServer(input string) *Server {
	srv := NewServer(strings.NewReader(input), io.Discard, io.Discard)
	srv.run = func(context.Context, string, []string, []string) (commandResult, error) {
		return commandResult{Stdout: `{"status":"healthy"}`}, nil
	}
	srv.env = fakeEnv(map[string]string{"__wd": "/", "__home": "/h"})
	srv.readFile = func(string) ([]byte, error) { return nil, fs.ErrNotExist }
	return srv
}

// BenchmarkReadFrames measures the frame reader over a realistic session.
func BenchmarkReadFrames(b *testing.B) {
	input := strings.Repeat(initFrame+"\n", 32)
	b.ReportAllocs()
	for b.Loop() {
		fr := newFrameReader(strings.NewReader(input))
		for {
			if _, err := fr.next(); err != nil {
				break
			}
		}
	}
}

// BenchmarkDecodeRequest measures envelope decoding.
func BenchmarkDecodeRequest(b *testing.B) {
	frame := []byte(initFrame)
	b.ReportAllocs()
	for b.Loop() {
		if _, err := decodeRequest(frame); err != nil {
			b.Fatal(err)
		}
	}
}

// BenchmarkValidateArgs measures schema validation of a populated argument
// object, including default injection.
func BenchmarkValidateArgs(b *testing.B) {
	schema := toolByName("agent-mode").Schema
	args := map[string]any{"action": "show", "profile": "audit"}
	b.ReportAllocs()
	for b.Loop() {
		if _, rerr := validateArgs(schema, args); rerr != nil {
			b.Fatal(rerr)
		}
	}
}

// BenchmarkToolsList measures rendering the manifest, which a client requests
// on every connection.
func BenchmarkToolsList(b *testing.B) {
	srv := benchServer("")
	b.ReportAllocs()
	for b.Loop() {
		if _, rerr := srv.handleToolsList(); rerr != nil {
			b.Fatal(rerr)
		}
	}
}

// BenchmarkToolsCall measures a full call minus the child process.
func BenchmarkToolsCall(b *testing.B) {
	srv := benchServer("")
	params := []byte(`{"name":"mcp-doctor","arguments":{"strict":true}}`)
	b.ReportAllocs()
	for b.Loop() {
		if _, rerr := srv.handleToolsCall(params); rerr != nil {
			b.Fatal(rerr)
		}
	}
}

// BenchmarkBuildCallResult measures classification of a JSON report.
func BenchmarkBuildCallResult(b *testing.B) {
	res := commandResult{Stdout: `{"status":"healthy","server_count":3,"summary":{"errors":0}}`}
	b.ReportAllocs()
	for b.Loop() {
		buildCallResult(res)
	}
}

// BenchmarkServeSession measures a whole handshake-plus-two-calls session end
// to end in-process.
func BenchmarkServeSession(b *testing.B) {
	input := strings.Join([]string{
		initFrame,
		`{"jsonrpc":"2.0","method":"notifications/initialized"}`,
		`{"jsonrpc":"2.0","id":2,"method":"tools/list"}`,
		`{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"fleet-status"}}`,
	}, "\n") + "\n"
	b.ReportAllocs()
	for b.Loop() {
		if err := benchServer(input).Serve(); err != nil {
			b.Fatal(err)
		}
	}
}

// BenchmarkWriteFrame measures serialising one response onto the wire.
func BenchmarkWriteFrame(b *testing.B) {
	fw := newFrameWriter(io.Discard)
	payload := map[string]any{"protocolVersion": latestProtocolVersion, "serverInfo": map[string]any{"name": serverName}}
	b.ReportAllocs()
	for b.Loop() {
		if err := fw.writeResult([]byte("1"), payload); err != nil {
			b.Fatal(err)
		}
	}
}
