// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"strings"
	"testing"
)

// recordedCall is one invocation captured by the fake runner.
type recordedCall struct {
	name string
	args []string
	env  []string
}

// fakeRunner returns a runner that records what it was asked to run and
// replays a fixed outcome, so no test needs a `dot` binary on PATH.
func fakeRunner(res commandResult, err error, calls *[]recordedCall) runner {
	return func(_ context.Context, name string, args []string, env []string) (commandResult, error) {
		if calls != nil {
			*calls = append(*calls, recordedCall{name: name, args: args, env: env})
		}
		return res, err
	}
}

// newTestServer wires a server over the given frames with inert seams: a fake
// runner, a fake environment, and buffers for stdout and stderr.
func newTestServer(frames []string) (*Server, *strings.Builder, *strings.Builder) {
	in := strings.Join(frames, "\n")
	if in != "" {
		in += "\n"
	}
	var out, logs strings.Builder
	srv := NewServer(strings.NewReader(in), &out, &logs)
	srv.run = fakeRunner(commandResult{Stdout: `{"status":"healthy"}`}, nil, nil)
	srv.env = fakeEnv(map[string]string{"__wd": "/", "__home": "/home/u"})
	srv.readFile = func(string) ([]byte, error) { return nil, fs.ErrNotExist }
	return srv, &out, &logs
}

// runSession serves the frames and decodes every message the server wrote.
func runSession(t *testing.T, frames []string, tweak func(*Server)) []map[string]any {
	t.Helper()
	srv, out, _ := newTestServer(frames)
	if tweak != nil {
		tweak(srv)
	}
	if err := srv.Serve(); err != nil {
		t.Fatalf("Serve: %v", err)
	}
	return decodeFrames(t, out.String())
}

// decodeFrames splits and decodes newline-delimited JSON, failing the test on
// any line that is not a JSON object — which is the invariant that keeps the
// transport usable.
func decodeFrames(t *testing.T, s string) []map[string]any {
	t.Helper()
	var msgs []map[string]any
	for _, line := range strings.Split(strings.TrimRight(s, "\n"), "\n") {
		if line == "" {
			continue
		}
		var m map[string]any
		if err := json.Unmarshal([]byte(line), &m); err != nil {
			t.Fatalf("stdout carried a non-JSON line %q: %v", line, err)
		}
		if m["jsonrpc"] != "2.0" {
			t.Fatalf("frame is not JSON-RPC 2.0: %s", line)
		}
		msgs = append(msgs, m)
	}
	return msgs
}

// initFrame is the standard opening handshake used by most tests.
const initFrame = `{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","clientInfo":{"name":"probe","version":"1.0"}}}`

// responses filters out server-initiated notifications.
func responses(msgs []map[string]any) []map[string]any {
	var out []map[string]any
	for _, m := range msgs {
		if _, isNotification := m["method"]; !isNotification {
			out = append(out, m)
		}
	}
	return out
}

// result extracts the result object of the nth response, failing on an error
// response.
func result(t *testing.T, msgs []map[string]any, n int) map[string]any {
	t.Helper()
	resps := responses(msgs)
	if n >= len(resps) {
		t.Fatalf("wanted response %d, got %d responses: %v", n, len(resps), msgs)
	}
	if e, ok := resps[n]["error"]; ok {
		t.Fatalf("response %d is an error: %v", n, e)
	}
	res, ok := resps[n]["result"].(map[string]any)
	if !ok {
		t.Fatalf("response %d has no result object: %v", n, resps[n])
	}
	return res
}

// rpcErrorOf extracts the error object of the nth response.
func rpcErrorOf(t *testing.T, msgs []map[string]any, n int) map[string]any {
	t.Helper()
	resps := responses(msgs)
	if n >= len(resps) {
		t.Fatalf("wanted response %d, got %d: %v", n, len(resps), msgs)
	}
	e, ok := resps[n]["error"].(map[string]any)
	if !ok {
		t.Fatalf("response %d is not an error: %v", n, resps[n])
	}
	return e
}

// TestInitializeNegotiatesTheProtocolVersion covers the version table: a
// supported version is echoed, an unknown one is answered with the latest.
func TestInitializeNegotiatesTheProtocolVersion(t *testing.T) {
	tests := []struct {
		name, asked, want string
	}{
		{name: "current", asked: "2025-06-18", want: "2025-06-18"},
		{name: "older supported", asked: "2024-11-05", want: "2024-11-05"},
		{name: "unknown future version", asked: "2099-01-01", want: latestProtocolVersion},
		{name: "absent", asked: "", want: latestProtocolVersion},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			frame := fmt.Sprintf(`{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":%q}}`, tc.asked)
			res := result(t, runSession(t, []string{frame}, nil), 0)
			if got := res["protocolVersion"]; got != tc.want {
				t.Fatalf("protocolVersion = %v, want %v", got, tc.want)
			}
		})
	}
}

// TestInitializeDeclaresOnlyImplementedCapabilities is the card's other half:
// the handshake must advertise tools, resources and logging, and nothing else.
func TestInitializeDeclaresOnlyImplementedCapabilities(t *testing.T) {
	res := result(t, runSession(t, []string{initFrame}, nil), 0)
	caps, ok := res["capabilities"].(map[string]any)
	if !ok {
		t.Fatalf("no capabilities object: %v", res)
	}
	for _, want := range []string{"tools", "resources", "logging"} {
		if _, ok := caps[want]; !ok {
			t.Errorf("capability %q not declared", want)
		}
	}
	if _, ok := caps["prompts"]; ok {
		t.Error("prompts is declared but not implemented")
	}
	if len(caps) != 3 {
		t.Errorf("capabilities = %v, want exactly tools/resources/logging", caps)
	}
	info, ok := res["serverInfo"].(map[string]any)
	if !ok || info["name"] != serverName || info["version"] != version {
		t.Fatalf("serverInfo = %v", res["serverInfo"])
	}
	if s, _ := res["instructions"].(string); s == "" {
		t.Error("initialize returned no instructions")
	}
}

// TestInitializeRejectsMalformedParams covers the params decode failure.
func TestInitializeRejectsMalformedParams(t *testing.T) {
	frame := `{"jsonrpc":"2.0","id":1,"method":"initialize","params":"not-an-object"}`
	if got := rpcErrorOf(t, runSession(t, []string{frame}, nil), 0)["code"]; got != float64(codeInvalidParams) {
		t.Fatalf("code = %v, want %d", got, codeInvalidParams)
	}
}

// TestRequestsBeforeInitializeAreRejected pins the lifecycle gate, and that
// ping is exempt so a client may probe liveness first.
func TestRequestsBeforeInitializeAreRejected(t *testing.T) {
	msgs := runSession(t, []string{
		`{"jsonrpc":"2.0","id":1,"method":"tools/list"}`,
		`{"jsonrpc":"2.0","id":2,"method":"ping"}`,
	}, nil)
	e := rpcErrorOf(t, msgs, 0)
	if e["code"] != float64(codeInvalidRequest) {
		t.Fatalf("code = %v, want %d", e["code"], codeInvalidRequest)
	}
	if !strings.Contains(fmt.Sprint(e["message"]), "not initialized") {
		t.Fatalf("message = %v", e["message"])
	}
	if got := result(t, msgs, 1); len(got) != 0 {
		t.Fatalf("ping result = %v, want an empty object", got)
	}
}

// TestNotificationsAreNeverAnswered covers the three notification paths, none
// of which may produce a frame.
func TestNotificationsAreNeverAnswered(t *testing.T) {
	srv, out, logs := newTestServer([]string{
		`{"jsonrpc":"2.0","method":"notifications/initialized"}`,
		`{"jsonrpc":"2.0","method":"notifications/cancelled","params":{"requestId":9}}`,
		`{"jsonrpc":"2.0","method":"notifications/unheard-of"}`,
		`{"jsonrpc":"2.0","id":null,"method":"notifications/initialized"}`,
	})
	if err := srv.Serve(); err != nil {
		t.Fatalf("Serve: %v", err)
	}
	if out.String() != "" {
		t.Fatalf("notifications produced output: %q", out.String())
	}
	if !srv.initialized {
		t.Error("notifications/initialized did not mark the session initialized")
	}
	for _, want := range []string{"completed initialization", "cancellation", "unknown notification"} {
		if !strings.Contains(logs.String(), want) {
			t.Errorf("stderr missing %q:\n%s", want, logs.String())
		}
	}
}

// TestToolsListMatchesTheRegistry pins that every registered tool is listed
// with a schema a client can actually use.
func TestToolsListMatchesTheRegistry(t *testing.T) {
	msgs := runSession(t, []string{initFrame, `{"jsonrpc":"2.0","id":2,"method":"tools/list"}`}, nil)
	list, ok := result(t, msgs, 1)["tools"].([]any)
	if !ok {
		t.Fatalf("tools/list returned no array")
	}
	if len(list) != len(defaultTools()) {
		t.Fatalf("listed %d tools, registry has %d", len(list), len(defaultTools()))
	}
	for i, entry := range list {
		e, ok := entry.(map[string]any)
		if !ok {
			t.Fatalf("tool %d is not an object", i)
		}
		schema, ok := e["inputSchema"].(map[string]any)
		if !ok {
			t.Fatalf("tool %v has no inputSchema", e["name"])
		}
		if schema["type"] != "object" {
			t.Errorf("tool %v: inputSchema.type = %v", e["name"], schema["type"])
		}
		if schema["additionalProperties"] != false {
			t.Errorf("tool %v: schema is not closed", e["name"])
		}
		if _, ok := schema["properties"]; !ok {
			t.Errorf("tool %v: schema declares no properties object", e["name"])
		}
		ann, ok := e["annotations"].(map[string]any)
		if !ok || ann["readOnlyHint"] != true {
			t.Errorf("tool %v: annotations = %v", e["name"], e["annotations"])
		}
	}
}

// TestToolsCallRunsTheTool covers the happy path end to end in-process: the
// argv handed to the CLI, the structured content returned, and the log
// notification emitted alongside it.
func TestToolsCallRunsTheTool(t *testing.T) {
	var calls []recordedCall
	msgs := runSession(t, []string{
		initFrame,
		`{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"mcp-doctor","arguments":{"strict":true}}}`,
	}, func(s *Server) {
		s.run = fakeRunner(commandResult{Stdout: `{"status":"warning"}`, ExitCode: 1}, nil, &calls)
		s.env = fakeEnv(map[string]string{"DOT_MCP_DOT_BIN": "/opt/dot", "__wd": "/", "__home": "/h"})
	})
	if len(calls) != 1 {
		t.Fatalf("ran %d commands, want 1", len(calls))
	}
	if calls[0].name != "/opt/dot" {
		t.Fatalf("ran %q, want the exported dot binary", calls[0].name)
	}
	want := []string{"mcp", "doctor", "--json", "--strict"}
	if strings.Join(calls[0].args, " ") != strings.Join(want, " ") {
		t.Fatalf("argv = %v, want %v", calls[0].args, want)
	}
	res := result(t, msgs, 1)
	if res["isError"] != false {
		t.Fatalf("isError = %v: a policy warning is a report, not a tool failure", res["isError"])
	}
	sc, ok := res["structuredContent"].(map[string]any)
	if !ok || sc["status"] != "warning" || sc["exitCode"] != float64(1) {
		t.Fatalf("structuredContent = %v", res["structuredContent"])
	}
	var sawLog bool
	for _, m := range msgs {
		if m["method"] == "notifications/message" {
			sawLog = true
			p := m["params"].(map[string]any)
			if p["logger"] != serverName || p["level"] != "info" {
				t.Errorf("log notification params = %v", p)
			}
		}
	}
	if !sawLog {
		t.Error("no notifications/message emitted for a tool call")
	}
}

// TestToolsCallRejections covers every way a call can be refused before the
// command runs.
func TestToolsCallRejections(t *testing.T) {
	tests := []struct {
		name     string
		params   string
		wantCode int
		wantMsg  string
	}{
		{name: "unknown tool", params: `{"name":"rm-rf","arguments":{}}`, wantCode: codeInvalidParams, wantMsg: "unknown tool"},
		{name: "unknown argument", params: `{"name":"fleet-status","arguments":{"host":"other"}}`, wantCode: codeInvalidParams, wantMsg: "invalid params"},
		{name: "wrong argument type", params: `{"name":"mcp-doctor","arguments":{"strict":"yes"}}`, wantCode: codeInvalidParams, wantMsg: "invalid params"},
		{name: "value outside the enum", params: `{"name":"agent-mode","arguments":{"action":"set"}}`, wantCode: codeInvalidParams, wantMsg: "invalid params"},
		{name: "profile failing the pattern", params: `{"name":"agent-mode","arguments":{"action":"show","profile":"../../etc"}}`, wantCode: codeInvalidParams, wantMsg: "invalid params"},
		{name: "show without a profile", params: `{"name":"agent-mode","arguments":{"action":"show"}}`, wantCode: codeInvalidParams, wantMsg: "invalid params"},
		{name: "malformed params", params: `"nope"`, wantCode: codeInvalidParams, wantMsg: "invalid params"},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			var calls []recordedCall
			msgs := runSession(t, []string{
				initFrame,
				fmt.Sprintf(`{"jsonrpc":"2.0","id":2,"method":"tools/call","params":%s}`, tc.params),
			}, func(s *Server) { s.run = fakeRunner(commandResult{}, nil, &calls) })
			e := rpcErrorOf(t, msgs, 1)
			if e["code"] != float64(tc.wantCode) {
				t.Fatalf("code = %v, want %d (%v)", e["code"], tc.wantCode, e)
			}
			if !strings.Contains(fmt.Sprint(e["message"]), tc.wantMsg) {
				t.Fatalf("message = %v, want it to contain %q", e["message"], tc.wantMsg)
			}
			if len(calls) != 0 {
				t.Fatalf("a rejected call still ran %v", calls)
			}
		})
	}
}

// TestToolsCallReportsExecutionFailure covers the runner returning a transport
// error — a missing `dot` binary, most often.
func TestToolsCallReportsExecutionFailure(t *testing.T) {
	msgs := runSession(t, []string{
		initFrame,
		`{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"fleet-status"}}`,
	}, func(s *Server) {
		s.run = fakeRunner(commandResult{}, errors.New("executable file not found"), nil)
	})
	e := rpcErrorOf(t, msgs, 1)
	if e["code"] != float64(codeInternalError) {
		t.Fatalf("code = %v, want %d", e["code"], codeInternalError)
	}
	if !strings.Contains(fmt.Sprint(e["data"]), "fleet-status") {
		t.Fatalf("data = %v", e["data"])
	}
}

// TestToolsCallWithoutArguments covers a call whose params omit `arguments`
// entirely, which clients do for zero-argument tools.
func TestToolsCallWithoutArguments(t *testing.T) {
	var calls []recordedCall
	msgs := runSession(t, []string{
		initFrame,
		`{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"workstation-attestation"}}`,
	}, func(s *Server) {
		s.run = fakeRunner(commandResult{Stdout: `{"version":"0.0.0"}`}, nil, &calls)
	})
	if len(calls) != 1 || strings.Join(calls[0].args, " ") != "attest --json" {
		t.Fatalf("calls = %v", calls)
	}
	if result(t, msgs, 1)["isError"] != false {
		t.Fatal("a successful call was flagged as an error")
	}
}

// TestChildEnvIsPlainAndRooted pins what a shelled-out command inherits.
func TestChildEnvIsPlainAndRooted(t *testing.T) {
	srv, _, _ := newTestServer(nil)
	srv.env = fakeEnv(map[string]string{"DOT_MCP_REPO_ROOT": "/repo", "__wd": "/", "__home": "/h"},
		"/repo/"+rootMarker)
	env := strings.Join(srv.childEnv(), "\n")
	for _, want := range []string{"NO_COLOR=1", "DOT_UI_PLAIN=1", "DOT_MCP_REPO_ROOT=/repo"} {
		if !strings.Contains(env, want) {
			t.Errorf("child environment missing %q", want)
		}
	}
	// Without a resolvable root the variable is simply not exported.
	srv.env = fakeEnv(map[string]string{"__wd": "/", "__home": "/h"})
	if strings.Contains(strings.Join(srv.childEnv(), "\n"), "DOT_MCP_REPO_ROOT=") {
		t.Error("exported an empty repo root")
	}
}

// TestResourcesListAndRead covers the resource surface against a fake file
// system, including every failure mode of a read.
func TestResourcesListAndRead(t *testing.T) {
	msgs := runSession(t, []string{
		initFrame,
		`{"jsonrpc":"2.0","id":2,"method":"resources/list"}`,
		`{"jsonrpc":"2.0","id":3,"method":"resources/read","params":{"uri":"dotfiles://mcp/policy"}}`,
		`{"jsonrpc":"2.0","id":4,"method":"resources/templates/list"}`,
	}, func(s *Server) {
		s.env = fakeEnv(map[string]string{"MCP_POLICY_CONFIG": "/etc/policy.json", "__wd": "/", "__home": "/h"})
		s.readFile = func(p string) ([]byte, error) {
			if p != "/etc/policy.json" {
				return nil, fmt.Errorf("unexpected read of %s", p)
			}
			return []byte(`{"defaultProfile":"strict-local"}`), nil
		}
	})
	list, ok := result(t, msgs, 1)["resources"].([]any)
	if !ok || len(list) != len(defaultResources()) {
		t.Fatalf("resources/list = %v", result(t, msgs, 1))
	}
	for _, entry := range list {
		e := entry.(map[string]any)
		for _, field := range []string{"uri", "name", "title", "description", "mimeType"} {
			if s, _ := e[field].(string); s == "" {
				t.Errorf("resource %v has no %s", e["uri"], field)
			}
		}
		if _, leaked := e["resolve"]; leaked {
			t.Errorf("resource %v leaked its resolver onto the wire", e["uri"])
		}
	}
	contents, ok := result(t, msgs, 2)["contents"].([]any)
	if !ok || len(contents) != 1 {
		t.Fatalf("resources/read = %v", result(t, msgs, 2))
	}
	c := contents[0].(map[string]any)
	if c["uri"] != "dotfiles://mcp/policy" || c["mimeType"] != "application/json" {
		t.Fatalf("contents = %v", c)
	}
	if !strings.Contains(fmt.Sprint(c["text"]), "strict-local") {
		t.Fatalf("text = %v", c["text"])
	}
	if tmpl, ok := result(t, msgs, 3)["resourceTemplates"].([]any); !ok || len(tmpl) != 0 {
		t.Fatalf("resources/templates/list = %v", result(t, msgs, 3))
	}
}

// TestResourcesReadFailures covers the URI that is not served, the document
// that is missing, the tree that cannot be resolved, and the oversize file.
func TestResourcesReadFailures(t *testing.T) {
	tests := []struct {
		name    string
		uri     string
		tweak   func(*Server)
		wantMsg string
	}{
		{name: "unknown uri", uri: "dotfiles://nope", wantMsg: "resource not found"},
		{
			name:    "missing file",
			uri:     "dotfiles://mcp/policy",
			wantMsg: "resource unavailable",
		},
		{
			name: "unresolvable checkout",
			uri:  "dotfiles://mcp/server-card",
			tweak: func(s *Server) {
				s.env = fakeEnv(map[string]string{"__wd": "/", "__home": "/h"})
			},
			wantMsg: "resource unavailable",
		},
		{
			name: "oversize document",
			uri:  "dotfiles://mcp/policy",
			tweak: func(s *Server) {
				s.env = fakeEnv(map[string]string{"MCP_POLICY_CONFIG": "/big.json", "__wd": "/", "__home": "/h"})
				s.readFile = func(string) ([]byte, error) {
					return make([]byte, maxResourceBytes+1), nil
				}
			},
			wantMsg: "resource too large",
		},
		{name: "malformed params", uri: "", tweak: nil, wantMsg: "resource not found"},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			frame := fmt.Sprintf(`{"jsonrpc":"2.0","id":2,"method":"resources/read","params":{"uri":%q}}`, tc.uri)
			msgs := runSession(t, []string{initFrame, frame}, tc.tweak)
			e := rpcErrorOf(t, msgs, 1)
			if e["code"] != float64(codeResourceNotOK) {
				t.Fatalf("code = %v, want %d", e["code"], codeResourceNotOK)
			}
			if !strings.Contains(fmt.Sprint(e["message"]), tc.wantMsg) {
				t.Fatalf("message = %v, want %q", e["message"], tc.wantMsg)
			}
		})
	}
}

// TestResourcesReadMalformedParams covers the params decode failure, which is
// an invalid-params error rather than a missing resource.
func TestResourcesReadMalformedParams(t *testing.T) {
	msgs := runSession(t, []string{initFrame, `{"jsonrpc":"2.0","id":2,"method":"resources/read","params":[]}`}, nil)
	if got := rpcErrorOf(t, msgs, 1)["code"]; got != float64(codeInvalidParams) {
		t.Fatalf("code = %v, want %d", got, codeInvalidParams)
	}
}

// TestLoggingSetLevel covers the level gate: a raised threshold suppresses the
// debug notification a tool call would otherwise emit.
func TestLoggingSetLevel(t *testing.T) {
	msgs := runSession(t, []string{
		initFrame,
		`{"jsonrpc":"2.0","id":2,"method":"logging/setLevel","params":{"level":"error"}}`,
		`{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"fleet-status"}}`,
	}, nil)
	if got := result(t, msgs, 1); len(got) != 0 {
		t.Fatalf("setLevel result = %v, want an empty object", got)
	}
	for _, m := range msgs {
		if m["method"] == "notifications/message" {
			t.Fatalf("level error still emitted %v", m)
		}
	}
}

// TestLoggingSetLevelRejections covers an unknown level and malformed params.
func TestLoggingSetLevelRejections(t *testing.T) {
	for _, params := range []string{`{"level":"chatty"}`, `"nope"`} {
		msgs := runSession(t, []string{
			initFrame,
			fmt.Sprintf(`{"jsonrpc":"2.0","id":2,"method":"logging/setLevel","params":%s}`, params),
		}, nil)
		if got := rpcErrorOf(t, msgs, 1)["code"]; got != float64(codeInvalidParams) {
			t.Fatalf("params %s: code = %v, want %d", params, got, codeInvalidParams)
		}
	}
}

// TestLevelIndex covers the ranking, including the unknown level that must not
// silence logging.
func TestLevelIndex(t *testing.T) {
	if levelIndex("debug") != 0 {
		t.Error("debug is not the lowest level")
	}
	if levelIndex("emergency") != len(logLevels)-1 {
		t.Error("emergency is not the highest level")
	}
	if levelIndex("nonsense") != levelIndex("info") {
		t.Error("an unknown level does not fall back to info")
	}
}

// TestNotifyLogSurvivesAWriteFailure covers the branch where a log
// notification cannot be delivered: it is reported on stderr and dropped, not
// escalated.
func TestNotifyLogSurvivesAWriteFailure(t *testing.T) {
	var logs strings.Builder
	srv := NewServer(strings.NewReader(""), errWriter{err: errors.New("gone")}, &logs)
	srv.notifyLog("error", map[string]any{"event": "probe"})
	if !strings.Contains(logs.String(), "dropping log notification") {
		t.Fatalf("stderr = %q", logs.String())
	}
}

// TestUnknownMethod covers the JSON-RPC method-not-found path.
func TestUnknownMethod(t *testing.T) {
	msgs := runSession(t, []string{initFrame, `{"jsonrpc":"2.0","id":2,"method":"prompts/list"}`}, nil)
	e := rpcErrorOf(t, msgs, 1)
	if e["code"] != float64(codeMethodNotFound) || e["data"] != "prompts/list" {
		t.Fatalf("error = %v", e)
	}
}

// TestMalformedFrameIsAnsweredWithANullID pins that a frame too broken to
// carry an id still gets an answer instead of a dropped connection.
func TestMalformedFrameIsAnsweredWithANullID(t *testing.T) {
	msgs := runSession(t, []string{`{"jsonrpc":`, initFrame}, nil)
	if msgs[0]["id"] != nil {
		t.Fatalf("id = %v, want null", msgs[0]["id"])
	}
	e := msgs[0]["error"].(map[string]any)
	if e["code"] != float64(codeParseError) {
		t.Fatalf("code = %v, want %d", e["code"], codeParseError)
	}
	// The session continues: the following handshake is still answered.
	if _, ok := msgs[1]["result"]; !ok {
		t.Fatalf("session did not survive a malformed frame: %v", msgs[1])
	}
}

// TestOversizeFrameEndsTheSessionCleanly pins that a frame past the limit is
// reported and the session closed, rather than the reader resynchronising in
// the middle of a message.
func TestOversizeFrameEndsTheSessionCleanly(t *testing.T) {
	srv, out, logs := newTestServer([]string{strings.Repeat("x", 4096)})
	srv.in.limit = 1024
	if err := srv.Serve(); err != nil {
		t.Fatalf("Serve: %v", err)
	}
	msgs := decodeFrames(t, out.String())
	if len(msgs) != 1 || msgs[0]["error"].(map[string]any)["code"] != float64(codeInvalidRequest) {
		t.Fatalf("msgs = %v", msgs)
	}
	if !strings.Contains(logs.String(), "frame too large") {
		t.Fatalf("stderr = %q", logs.String())
	}
}

// TestServeReturnsTransportErrors covers the two fatal paths: a read that
// fails for a reason other than EOF, and a write to a closed peer.
func TestServeReturnsTransportErrors(t *testing.T) {
	readErr := errors.New("read failed")
	srv := NewServer(errReader{err: readErr}, &strings.Builder{}, &strings.Builder{})
	if err := srv.Serve(); !errors.Is(err, readErr) {
		t.Fatalf("Serve = %v, want %v", err, readErr)
	}

	writeErr := errors.New("write failed")
	srv = NewServer(strings.NewReader(initFrame+"\n"), errWriter{err: writeErr}, &strings.Builder{})
	if err := srv.Serve(); !errors.Is(err, writeErr) {
		t.Fatalf("Serve = %v, want %v", err, writeErr)
	}

	// A frame that cannot even be parsed still needs its error written, and
	// that write can fail too.
	srv = NewServer(strings.NewReader("{\n"), errWriter{err: writeErr}, &strings.Builder{})
	if err := srv.Serve(); !errors.Is(err, writeErr) {
		t.Fatalf("Serve = %v, want %v", err, writeErr)
	}

	// So can the write of a normal error response.
	srv = NewServer(strings.NewReader(`{"jsonrpc":"2.0","id":1,"method":"nope"}`+"\n"),
		errWriter{err: writeErr}, &strings.Builder{})
	if err := srv.Serve(); !errors.Is(err, writeErr) {
		t.Fatalf("Serve = %v, want %v", err, writeErr)
	}

	// And the write of an oversize-frame notice, which must not be escalated
	// into a returned error — the session is closing regardless.
	srv = NewServer(strings.NewReader(strings.Repeat("x", 4096)), errWriter{err: writeErr}, &strings.Builder{})
	srv.in.limit = 512
	if err := srv.Serve(); err != nil {
		t.Fatalf("Serve = %v, want nil", err)
	}
}

// TestServeLogsOnlyToStderr is the invariant the whole transport depends on.
func TestServeLogsOnlyToStderr(t *testing.T) {
	srv, out, logs := newTestServer([]string{
		initFrame,
		`{"jsonrpc":"2.0","method":"notifications/initialized"}`,
		`{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"fleet-status"}}`,
	})
	if err := srv.Serve(); err != nil {
		t.Fatalf("Serve: %v", err)
	}
	decodeFrames(t, out.String()) // fails the test on any non-JSON line
	if logs.Len() == 0 {
		t.Fatal("nothing was logged to stderr")
	}
	if strings.Contains(out.String(), "dot-mcp:") {
		t.Fatalf("a log line reached stdout:\n%s", out.String())
	}
}

// TestWriteToolManifest covers the side-channel manifest used by the card
// drift check.
func TestWriteToolManifest(t *testing.T) {
	srv, _, _ := newTestServer(nil)
	var buf strings.Builder
	if err := srv.WriteToolManifest(&buf); err != nil {
		t.Fatal(err)
	}
	var doc struct {
		Name         string           `json:"name"`
		Version      string           `json:"version"`
		Capabilities map[string]bool  `json:"capabilities"`
		Tools        []toolDescriptor `json:"tools"`
		Resources    []string         `json:"resources"`
	}
	if err := json.Unmarshal([]byte(buf.String()), &doc); err != nil {
		t.Fatalf("manifest is not valid JSON: %v", err)
	}
	if doc.Name != serverName || doc.Version != version {
		t.Fatalf("manifest identity = %s/%s", doc.Name, doc.Version)
	}
	if len(doc.Tools) != len(defaultTools()) || len(doc.Resources) != len(defaultResources()) {
		t.Fatalf("manifest lists %d tools and %d resources", len(doc.Tools), len(doc.Resources))
	}
	if doc.Capabilities["prompts"] {
		t.Error("manifest claims prompts")
	}
}

// TestWriteToolManifestPropagatesWriteErrors covers the error return.
func TestWriteToolManifestPropagatesWriteErrors(t *testing.T) {
	srv, _, _ := newTestServer(nil)
	if err := srv.WriteToolManifest(errWriter{err: errors.New("nope")}); err == nil {
		t.Fatal("expected a write error")
	}
}

// TestDecodeParamsToleratesAbsentParams covers both empty forms.
func TestDecodeParamsToleratesAbsentParams(t *testing.T) {
	var p callParams
	if rerr := decodeParams(nil, &p); rerr != nil {
		t.Fatalf("absent params rejected: %v", rerr)
	}
	if rerr := decodeParams(json.RawMessage("null"), &p); rerr != nil {
		t.Fatalf("null params rejected: %v", rerr)
	}
}

// TestOrUnknown covers the client-identity placeholder.
func TestOrUnknown(t *testing.T) {
	if orUnknown("") != "unknown" || orUnknown("x") != "x" {
		t.Fatal("orUnknown misbehaves")
	}
}

// TestLookupToolMiss covers the negative branch of the registry lookup.
func TestLookupToolMiss(t *testing.T) {
	srv, _, _ := newTestServer(nil)
	if _, ok := srv.lookupTool("nope"); ok {
		t.Fatal("found a tool that does not exist")
	}
}
