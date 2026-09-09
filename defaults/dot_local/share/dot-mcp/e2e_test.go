// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// End-to-end protocol tests. These build the real binary and drive it over
// real pipes as a client would: unit tests prove the handlers behave, only
// this proves the process speaks the protocol.
package main

import (
	"bufio"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"testing"
	"time"
)

// buildBinary compiles the server once per test binary and returns its path.
var buildBinary = sync.OnceValues(func() (string, error) {
	if runtime.GOOS == "windows" {
		return "", errors.New("the stdio server is not built for windows")
	}
	dir, err := os.MkdirTemp("", "dot-mcp-e2e")
	if err != nil {
		return "", err
	}
	bin := filepath.Join(dir, "dot-mcp")
	cmd := exec.Command("go", "build", "-o", bin, ".")
	if out, err := cmd.CombinedOutput(); err != nil {
		return "", fmt.Errorf("go build: %v\n%s", err, out)
	}
	return bin, nil
})

// fakeDotScript writes an executable stand-in for the `dot` CLI that echoes a
// fixed JSON document, so the exchange is deterministic and no test depends on
// a dotfiles installation.
func fakeDotScript(t *testing.T) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "dot")
	script := "#!/bin/sh\n" +
		"printf '{\"status\":\"healthy\",\"argv\":\"%s\"}\\n' \"$*\"\n"
	if err := os.WriteFile(path, []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	return path
}

// session is a live client conversation with the server process.
type session struct {
	cmd    *exec.Cmd
	stdin  io.WriteCloser
	out    *bufio.Reader
	stderr *strings.Builder
	t      *testing.T
}

// startSession launches the built binary with the given environment additions.
func startSession(t *testing.T, extraEnv ...string) *session {
	t.Helper()
	bin, err := buildBinary()
	if err != nil {
		t.Skipf("cannot build the server here: %v", err)
	}
	cmd := exec.Command(bin, "serve")
	cmd.Env = append(os.Environ(), extraEnv...)
	stdin, err := cmd.StdinPipe()
	if err != nil {
		t.Fatal(err)
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		t.Fatal(err)
	}
	var stderr strings.Builder
	cmd.Stderr = &stderr
	if err := cmd.Start(); err != nil {
		t.Fatal(err)
	}
	s := &session{cmd: cmd, stdin: stdin, out: bufio.NewReader(stdout), stderr: &stderr, t: t}
	t.Cleanup(func() {
		_ = stdin.Close()
		_ = cmd.Wait()
	})
	return s
}

// send writes one frame to the server.
func (s *session) send(frame string) {
	s.t.Helper()
	if _, err := io.WriteString(s.stdin, frame+"\n"); err != nil {
		s.t.Fatalf("write frame: %v (stderr: %s)", err, s.stderr.String())
	}
}

// receive reads frames until one carries the wanted id, skipping the
// server-initiated notifications a real client would also have to skip.
func (s *session) receive(id float64) map[string]any {
	s.t.Helper()
	deadline := time.Now().Add(30 * time.Second)
	for time.Now().Before(deadline) {
		line, err := s.out.ReadString('\n')
		if err != nil {
			s.t.Fatalf("read frame: %v (stderr: %s)", err, s.stderr.String())
		}
		var m map[string]any
		if err := json.Unmarshal([]byte(line), &m); err != nil {
			s.t.Fatalf("stdout carried a non-JSON line %q (stderr: %s)", line, s.stderr.String())
		}
		if m["jsonrpc"] != "2.0" {
			s.t.Fatalf("frame is not JSON-RPC 2.0: %s", line)
		}
		if got, ok := m["id"].(float64); ok && got == id {
			return m
		}
	}
	s.t.Fatalf("timed out waiting for response %v", id)
	return nil
}

// TestEndToEndProtocolExchange is the acceptance test for the whole thing: a
// real process, real pipes, a real handshake, a real tools/list and a real
// tools/call, asserted on the wire.
func TestEndToEndProtocolExchange(t *testing.T) {
	dot := fakeDotScript(t)
	s := startSession(t, "DOT_MCP_DOT_BIN="+dot)

	s.send(`{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"e2e","version":"1.0"}}}`)
	init := s.receive(1)
	res, ok := init["result"].(map[string]any)
	if !ok {
		t.Fatalf("initialize failed: %v", init)
	}
	if res["protocolVersion"] != "2025-06-18" {
		t.Fatalf("protocolVersion = %v", res["protocolVersion"])
	}
	info := res["serverInfo"].(map[string]any)
	if info["name"] != serverName || info["version"] != version {
		t.Fatalf("serverInfo = %v", info)
	}
	caps := res["capabilities"].(map[string]any)
	for _, want := range []string{"tools", "resources", "logging"} {
		if _, ok := caps[want]; !ok {
			t.Errorf("initialize did not declare %q", want)
		}
	}

	s.send(`{"jsonrpc":"2.0","method":"notifications/initialized"}`)

	s.send(`{"jsonrpc":"2.0","id":2,"method":"tools/list"}`)
	tools := s.receive(2)["result"].(map[string]any)["tools"].([]any)
	names := map[string]bool{}
	for _, entry := range tools {
		e := entry.(map[string]any)
		names[e["name"].(string)] = true
		if _, ok := e["inputSchema"].(map[string]any); !ok {
			t.Errorf("%v has no inputSchema on the wire", e["name"])
		}
	}
	for _, want := range []string{"mcp-doctor", "agent-mode", "workstation-attestation", "fleet-status"} {
		if !names[want] {
			t.Errorf("tools/list omitted %q", want)
		}
	}

	s.send(`{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"mcp-doctor","arguments":{"strict":true}}}`)
	call := s.receive(3)["result"].(map[string]any)
	if call["isError"] != false {
		t.Fatalf("tools/call reported an error: %v", call)
	}
	structured, ok := call["structuredContent"].(map[string]any)
	if !ok {
		t.Fatalf("no structuredContent: %v", call)
	}
	if structured["status"] != "healthy" {
		t.Fatalf("status = %v", structured["status"])
	}
	if got, want := structured["argv"], "mcp doctor --json --strict"; got != want {
		t.Fatalf("the server ran %q, want %q", got, want)
	}
	content := call["content"].([]any)[0].(map[string]any)
	if content["type"] != "text" || !strings.Contains(content["text"].(string), "healthy") {
		t.Fatalf("content = %v", content)
	}

	s.send(`{"jsonrpc":"2.0","id":4,"method":"resources/list"}`)
	if len(s.receive(4)["result"].(map[string]any)["resources"].([]any)) != len(defaultResources()) {
		t.Fatal("resources/list did not return the full table over the wire")
	}

	s.send(`{"jsonrpc":"2.0","id":5,"method":"prompts/list"}`)
	if code := s.receive(5)["error"].(map[string]any)["code"]; code != float64(codeMethodNotFound) {
		t.Fatalf("code = %v, want %d", code, codeMethodNotFound)
	}
}

// TestEndToEndShutsDownOnEOF pins the lifecycle end: closing stdin ends the
// process with status 0, which is how an MCP client stops an stdio server.
func TestEndToEndShutsDownOnEOF(t *testing.T) {
	bin, err := buildBinary()
	if err != nil {
		t.Skipf("cannot build the server here: %v", err)
	}
	cmd := exec.Command(bin, "serve")
	cmd.Stdin = strings.NewReader(`{"jsonrpc":"2.0","id":1,"method":"ping"}` + "\n")
	var out, errbuf strings.Builder
	cmd.Stdout = &out
	cmd.Stderr = &errbuf
	if err := cmd.Run(); err != nil {
		t.Fatalf("run: %v (stderr: %s)", err, errbuf.String())
	}
	if !strings.Contains(out.String(), `"result":{}`) {
		t.Fatalf("stdout = %q", out.String())
	}
	if !strings.Contains(errbuf.String(), "shutting down") {
		t.Fatalf("stderr = %q", errbuf.String())
	}
}

// TestEndToEndKeepsStdoutClean pins the invariant a client cannot recover
// from: with a `dot` shim that writes to stderr and exits non-zero, every
// stdout line must still be a protocol frame.
func TestEndToEndKeepsStdoutClean(t *testing.T) {
	noisy := filepath.Join(t.TempDir(), "dot")
	script := "#!/bin/sh\necho 'this must never reach the client stdout' >&2\nexit 4\n"
	if err := os.WriteFile(noisy, []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	s := startSession(t, "DOT_MCP_DOT_BIN="+noisy)
	s.send(`{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18"}}`)
	s.receive(1)
	s.send(`{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"fleet-status"}}`)
	res := s.receive(2)["result"].(map[string]any)
	if res["isError"] != true {
		t.Fatalf("a failing command was not flagged: %v", res)
	}
	text := res["content"].([]any)[0].(map[string]any)["text"].(string)
	if !strings.Contains(text, "must never reach the client stdout") {
		t.Fatalf("stderr was not folded into the tool result: %q", text)
	}
}
