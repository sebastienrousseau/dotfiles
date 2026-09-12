// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
package main

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"strings"
)

// ExampleServer_Serve shows the shape of a handshake on the wire: one JSON
// object per line on stdout, nothing else.
func ExampleServer_Serve() {
	in := strings.NewReader(`{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18"}}` + "\n")
	srv := NewServer(in, os.Stdout, io.Discard)
	if err := srv.Serve(); err != nil {
		fmt.Println("serve:", err)
	}
	// Output:
	// {"jsonrpc":"2.0","id":1,"result":{"capabilities":{"logging":{},"resources":{"listChanged":false,"subscribe":false},"tools":{"listChanged":false}},"instructions":"Read-only governance surface for a chezmoi-managed dotfiles workstation. Tools run the `dot` CLI's own audit commands and never change configuration. Resources expose the MCP policy, the MCP registry, the agent profiles and the discovery cards.","protocolVersion":"2025-06-18","serverInfo":{"name":"dotfiles-mcp","title":"dotfiles workstation governance","version":"0.2.520"}}}
}

// ExampleServer_Serve_toolsCall shows a tool call being answered with both a
// text block and structured content, with the tool's exit code attached.
func ExampleServer_Serve_toolsCall() {
	frames := strings.Join([]string{
		`{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18"}}`,
		`{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"fleet-status"}}`,
	}, "\n") + "\n"

	var out strings.Builder
	srv := NewServer(strings.NewReader(frames), &out, io.Discard)
	srv.run = func(context.Context, string, []string, []string) (commandResult, error) {
		return commandResult{Stdout: `{"node_id":"laptop","drift":"clean"}`}, nil
	}
	if err := srv.Serve(); err != nil {
		fmt.Println("serve:", err)
	}
	// The second response is the call; the notification before it is a log
	// message, which a client skips the same way.
	for _, line := range strings.Split(strings.TrimSpace(out.String()), "\n") {
		var m map[string]any
		if err := json.Unmarshal([]byte(line), &m); err != nil {
			fmt.Println("bad frame:", err)
			return
		}
		if m["id"] == float64(2) {
			b, _ := json.Marshal(m["result"])
			fmt.Println(string(b))
		}
	}
	// Output:
	// {"content":[{"text":"{\"node_id\":\"laptop\",\"drift\":\"clean\"}","type":"text"}],"isError":false,"structuredContent":{"drift":"clean","exitCode":0,"node_id":"laptop"}}
}

// ExampleServer_WriteToolManifest shows the manifest side-channel used to
// check the published server card against the running registry.
func ExampleServer_WriteToolManifest() {
	srv := NewServer(strings.NewReader(""), io.Discard, io.Discard)
	var buf strings.Builder
	if err := srv.WriteToolManifest(&buf); err != nil {
		fmt.Println("manifest:", err)
		return
	}
	var doc struct {
		Name      string   `json:"name"`
		Resources []string `json:"resources"`
		Tools     []struct {
			Name string `json:"name"`
		} `json:"tools"`
	}
	if err := json.Unmarshal([]byte(buf.String()), &doc); err != nil {
		fmt.Println("decode:", err)
		return
	}
	fmt.Println(doc.Name)
	for _, t := range doc.Tools {
		fmt.Println("tool:", t.Name)
	}
	for _, r := range doc.Resources {
		fmt.Println("resource:", r)
	}
	// Output:
	// dotfiles-mcp
	// tool: mcp-doctor
	// tool: agent-mode
	// tool: workstation-attestation
	// tool: fleet-status
	// resource: dotfiles://agent/card
	// resource: dotfiles://agent/profiles
	// resource: dotfiles://mcp/policy
	// resource: dotfiles://mcp/registry
	// resource: dotfiles://mcp/server-card
}
