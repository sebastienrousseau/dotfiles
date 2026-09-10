// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// The MCP layer: lifecycle, method dispatch, and the tools/resources/logging
// features the server card declares. Everything here is single-goroutine —
// frames are handled in arrival order — which is all the stdio transport needs
// and removes a whole class of interleaving bug.
package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"sort"
	"time"
)

// Protocol versions this server implements, newest first. initialize echoes
// the client's version when it is one of these and otherwise answers with
// latestProtocolVersion, which is what the specification requires: the client
// then decides whether it can proceed.
var supportedProtocolVersions = []string{"2025-06-18", "2025-03-26", "2024-11-05"}

// latestProtocolVersion is the version offered when a client asks for one this
// server does not implement.
const latestProtocolVersion = "2025-06-18"

// serverName is the MCP server identity; it matches `name` in the server card.
const serverName = "dotfiles-mcp"

// logLevels are the RFC 5424 severities MCP uses, in increasing order. A
// message is emitted when its level is at least the configured minimum.
var logLevels = []string{"debug", "info", "notice", "warning", "error", "critical", "alert", "emergency"}

// defaultLogLevel is the minimum severity emitted before logging/setLevel.
const defaultLogLevel = "info"

// instructions is the server's guidance to the model, returned by initialize.
const instructions = "Read-only governance surface for a chezmoi-managed dotfiles workstation. " +
	"Tools run the `dot` CLI's own audit commands and never change configuration. " +
	"Resources expose the MCP policy, the MCP registry, the agent profiles and the discovery cards."

// Server is one stdio MCP session.
type Server struct {
	in        *frameReader
	out       *frameWriter
	logw      io.Writer
	env       environment
	run       runner
	readFile  func(string) ([]byte, error)
	timeout   time.Duration
	tools     []tool
	resources []resource

	initialized bool
	clientInfo  string
	logLevel    string
}

// NewServer wires a session to the given streams with production seams.
func NewServer(stdin io.Reader, stdout, stderr io.Writer) *Server {
	return &Server{
		in:        newFrameReader(stdin),
		out:       newFrameWriter(stdout),
		logw:      stderr,
		env:       osEnvironment(),
		run:       execRunner,
		readFile:  osReadFile,
		timeout:   defaultToolTimeout,
		tools:     defaultTools(),
		resources: defaultResources(),
		logLevel:  defaultLogLevel,
	}
}

// logf writes a diagnostic to stderr. Never stdout: stdout is the protocol
// stream and a stray byte there desynchronises the client permanently.
func (s *Server) logf(format string, args ...any) {
	fmt.Fprintf(s.logw, "dot-mcp: "+format+"\n", args...)
}

// Serve reads frames until EOF and answers each one. EOF is a clean shutdown —
// the client closing its end of the pipe is how an stdio MCP session ends — so
// it returns nil. A write failure is fatal: the peer is gone and there is no
// way to report anything.
func (s *Server) Serve() error {
	s.logf("listening on stdio (protocol %s, %d tools, %d resources)",
		latestProtocolVersion, len(s.tools), len(s.resources))
	for {
		frame, err := s.in.next()
		if err != nil {
			if errors.Is(err, io.EOF) {
				s.logf("stdin closed, shutting down")
				return nil
			}
			if errors.Is(err, errFrameTooLarge) {
				// Answerable: tell the client, then stop, because the reader
				// is no longer synchronised with a message boundary.
				s.logf("frame too large, closing session")
				_ = s.out.writeError(nullID, newRPCError(codeInvalidRequest, "invalid request", err.Error()))
				return nil
			}
			return err
		}
		if err := s.handleFrame(frame); err != nil {
			return err
		}
	}
}

// handleFrame decodes and dispatches one frame. The returned error is a
// transport failure only; protocol-level problems are answered as JSON-RPC
// error objects.
func (s *Server) handleFrame(frame []byte) error {
	req, rerr := decodeRequest(frame)
	if rerr != nil {
		s.logf("rejected frame: %s", rerr.Message)
		return s.out.writeError(nullID, rerr)
	}
	if req.isNotification() {
		s.handleNotification(req)
		return nil
	}
	result, rerr := s.handleRequest(req)
	if rerr != nil {
		return s.out.writeError(req.ID, rerr)
	}
	return s.out.writeResult(req.ID, result)
}

// handleNotification processes a message with no id. Unknown notifications are
// ignored, as the specification requires — a client is free to send ones this
// server does not implement.
func (s *Server) handleNotification(req *request) {
	switch req.Method {
	case "notifications/initialized":
		s.initialized = true
		s.logf("client %s completed initialization", s.clientInfo)
	case "notifications/cancelled":
		// Every handler here is synchronous, so by the time a cancellation
		// arrives the request it names has already been answered.
		s.logf("ignoring cancellation for an already-completed request")
	default:
		s.logf("ignoring unknown notification %q", req.Method)
	}
}

// handleRequest dispatches a request that expects a response.
func (s *Server) handleRequest(req *request) (any, *rpcError) {
	if req.Method != "initialize" && req.Method != "ping" && !s.initialized {
		return nil, newRPCError(codeInvalidRequest, "server not initialized",
			fmt.Sprintf("%s was called before the initialize handshake completed", req.Method))
	}
	switch req.Method {
	case "initialize":
		return s.handleInitialize(req.Params)
	case "ping":
		return map[string]any{}, nil
	case "tools/list":
		return s.handleToolsList()
	case "tools/call":
		return s.handleToolsCall(req.Params)
	case "resources/list":
		return s.handleResourcesList()
	case "resources/templates/list":
		// No templated resources: every URI this server serves is fixed.
		return map[string]any{"resourceTemplates": []any{}}, nil
	case "resources/read":
		return s.handleResourcesRead(req.Params)
	case "logging/setLevel":
		return s.handleSetLevel(req.Params)
	default:
		return nil, newRPCError(codeMethodNotFound, "method not found", req.Method)
	}
}

// initializeParams is the subset of the initialize request this server reads.
type initializeParams struct {
	ProtocolVersion string `json:"protocolVersion"`
	ClientInfo      struct {
		Name    string `json:"name"`
		Version string `json:"version"`
	} `json:"clientInfo"`
}

// handleInitialize negotiates the protocol version and declares capabilities.
// The declared set is exactly what this server implements — tools, resources
// and logging — and matches capabilities in the server card.
func (s *Server) handleInitialize(raw json.RawMessage) (any, *rpcError) {
	var p initializeParams
	if err := decodeParams(raw, &p); err != nil {
		return nil, err
	}
	negotiated := latestProtocolVersion
	if containsString(supportedProtocolVersions, p.ProtocolVersion) {
		negotiated = p.ProtocolVersion
	} else if p.ProtocolVersion != "" {
		s.logf("client asked for protocol %q; offering %s", p.ProtocolVersion, negotiated)
	}
	s.clientInfo = fmt.Sprintf("%s/%s", orUnknown(p.ClientInfo.Name), orUnknown(p.ClientInfo.Version))
	// The handshake is complete for dispatch purposes once initialize has been
	// answered; notifications/initialized only confirms it. Waiting for the
	// notification would reject a client that pipelines its first tools/list.
	s.initialized = true
	return map[string]any{
		"protocolVersion": negotiated,
		"serverInfo": map[string]any{
			"name":    serverName,
			"title":   "dotfiles workstation governance",
			"version": version,
		},
		"capabilities": map[string]any{
			"tools":     map[string]any{"listChanged": false},
			"resources": map[string]any{"subscribe": false, "listChanged": false},
			"logging":   map[string]any{},
		},
		"instructions": instructions,
	}, nil
}

// orUnknown substitutes a placeholder for an empty client-supplied string.
func orUnknown(s string) string {
	if s == "" {
		return "unknown"
	}
	return s
}

// handleToolsList returns the manifest. Order is the registry's order, which
// is stable, so a client diffing two sessions sees no spurious change.
func (s *Server) handleToolsList() (any, *rpcError) {
	out := make([]toolDescriptor, 0, len(s.tools))
	for _, t := range s.tools {
		out = append(out, t.descriptor())
	}
	return map[string]any{"tools": out}, nil
}

// callParams is the tools/call request payload.
type callParams struct {
	Name      string         `json:"name"`
	Arguments map[string]any `json:"arguments"`
}

// handleToolsCall validates the arguments against the tool's schema, runs the
// underlying `dot` command, and returns the result. A tool that fails is
// reported as an MCP tool error (isError on the result), not a JSON-RPC error:
// the call itself succeeded, the audit is what came back unhappy.
func (s *Server) handleToolsCall(raw json.RawMessage) (any, *rpcError) {
	var p callParams
	if err := decodeParams(raw, &p); err != nil {
		return nil, err
	}
	t, ok := s.lookupTool(p.Name)
	if !ok {
		return nil, newRPCError(codeInvalidParams, "unknown tool", p.Name)
	}
	args, rerr := validateArgs(t.Schema, p.Arguments)
	if rerr != nil {
		return nil, rerr
	}
	if rerr := conditionalRequirements(t.Name, args); rerr != nil {
		return nil, rerr
	}
	argv := t.argv(args)
	bin := s.env.dotBinary()
	s.notifyLog("info", map[string]any{"event": "tool.call", "tool": t.Name, "argv": argv})

	ctx, cancel := context.WithTimeout(context.Background(), s.timeout)
	defer cancel()
	res, err := s.run(ctx, bin, argv, s.childEnv())
	if err != nil {
		s.notifyLog("error", map[string]any{"event": "tool.error", "tool": t.Name, "error": err.Error()})
		return nil, newRPCError(codeInternalError, "tool execution failed",
			fmt.Sprintf("%s: %v", t.Name, err))
	}
	s.notifyLog("debug", map[string]any{"event": "tool.done", "tool": t.Name, "exitCode": res.ExitCode})
	return buildCallResult(res), nil
}

// lookupTool finds a tool by name.
func (s *Server) lookupTool(name string) (tool, bool) {
	for _, t := range s.tools {
		if t.Name == name {
			return t, true
		}
	}
	return tool{}, false
}

// childEnv is the environment handed to a shelled-out `dot`. NO_COLOR keeps
// ANSI escapes out of tool output, and the repo root is passed through so the
// child resolves the same tree this server is serving.
func (s *Server) childEnv() []string {
	env := append([]string{}, os.Environ()...)
	env = append(env, "NO_COLOR=1", "DOT_UI_PLAIN=1")
	if root := s.env.repoRoot(); root != "" {
		env = append(env, "DOT_MCP_REPO_ROOT="+root)
	}
	return env
}

// handleResourcesList returns the resource table.
func (s *Server) handleResourcesList() (any, *rpcError) {
	return map[string]any{"resources": s.resources}, nil
}

// readParams is the resources/read request payload.
type readParams struct {
	URI string `json:"uri"`
}

// handleResourcesRead serves one resource by URI.
func (s *Server) handleResourcesRead(raw json.RawMessage) (any, *rpcError) {
	var p readParams
	if err := decodeParams(raw, &p); err != nil {
		return nil, err
	}
	for _, r := range s.resources {
		if r.URI != p.URI {
			continue
		}
		contents, rerr := readResource(r, s.env, s.readFile)
		if rerr != nil {
			return nil, rerr
		}
		return map[string]any{"contents": []resourceContents{contents}}, nil
	}
	return nil, newRPCError(codeResourceNotOK, "resource not found", p.URI)
}

// levelParams is the logging/setLevel request payload.
type levelParams struct {
	Level string `json:"level"`
}

// handleSetLevel changes the minimum severity of emitted log notifications.
func (s *Server) handleSetLevel(raw json.RawMessage) (any, *rpcError) {
	var p levelParams
	if err := decodeParams(raw, &p); err != nil {
		return nil, err
	}
	if !containsString(logLevels, p.Level) {
		return nil, newRPCError(codeInvalidParams, "invalid params",
			fmt.Sprintf("unknown log level %q", p.Level))
	}
	s.logLevel = p.Level
	s.logf("log level set to %s", p.Level)
	return map[string]any{}, nil
}

// notifyLog emits a notifications/message frame when level passes the
// configured threshold. A failed write is not fatal — losing a log line must
// not end a working session — so it is recorded on stderr and dropped.
func (s *Server) notifyLog(level string, data map[string]any) {
	if levelIndex(level) < levelIndex(s.logLevel) {
		return
	}
	if err := s.out.writeNotification("notifications/message", map[string]any{
		"level":  level,
		"logger": serverName,
		"data":   data,
	}); err != nil {
		s.logf("dropping log notification: %v", err)
	}
}

// levelIndex ranks a severity; an unknown level sorts as info so a typo cannot
// silence logging entirely.
func levelIndex(level string) int {
	for i, l := range logLevels {
		if l == level {
			return i
		}
	}
	return 1
}

// decodeParams unmarshals a params object, tolerating an absent params member
// (which is legal for a request whose arguments are all optional).
func decodeParams(raw json.RawMessage, dst any) *rpcError {
	if len(raw) == 0 || string(raw) == "null" {
		return nil
	}
	if err := json.Unmarshal(raw, dst); err != nil {
		return newRPCError(codeInvalidParams, "invalid params", err.Error())
	}
	return nil
}

// WriteToolManifest prints the tool and resource manifest as a JSON document,
// so what the server serves can be inspected — or diffed against the published
// card — without speaking the protocol.
func (s *Server) WriteToolManifest(w io.Writer) error {
	tools := make([]toolDescriptor, 0, len(s.tools))
	for _, t := range s.tools {
		tools = append(tools, t.descriptor())
	}
	uris := make([]string, 0, len(s.resources))
	for _, r := range s.resources {
		uris = append(uris, r.URI)
	}
	sort.Strings(uris)
	enc := json.NewEncoder(w)
	enc.SetIndent("", "  ")
	return enc.Encode(map[string]any{
		"name":            serverName,
		"version":         version,
		"protocolVersion": latestProtocolVersion,
		"capabilities": map[string]bool{
			"tools":     true,
			"resources": true,
			"prompts":   false,
			"logging":   true,
		},
		"tools":     tools,
		"resources": uris,
	})
}
