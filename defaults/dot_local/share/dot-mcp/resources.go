// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// The resource surface: the JSON documents that describe this workstation's
// agent and MCP governance posture. Resources are a closed table of URIs, each
// bound to a resolver — a client can never name a path, so there is no
// traversal surface and nothing outside these five files is readable.
package main

import (
	"fmt"
	"io"
	"os"
)

// resource is one entry of the resource table.
type resource struct {
	URI         string `json:"uri"`
	Name        string `json:"name"`
	Title       string `json:"title"`
	Description string `json:"description"`
	MIMEType    string `json:"mimeType"`
	// resolve returns the absolute path backing the URI, or "" when the
	// document is not present in this deployment.
	resolve func(environment) string `json:"-"`
}

// resourceContents is one entry of a resources/read result.
type resourceContents struct {
	URI      string `json:"uri"`
	Name     string `json:"name"`
	MIMEType string `json:"mimeType"`
	Text     string `json:"text"`
}

// defaultResources is the resource table. It is the reason
// `capabilities.resources` is true in the server card: these are the documents
// an agent needs to reason about what it is allowed to do on this machine.
func defaultResources() []resource {
	return []resource{
		{
			URI:         "dotfiles://mcp/policy",
			Name:        "mcp-policy",
			Title:       "MCP policy",
			Description: "Launcher allowlist, blocked filesystem roots, blocked argument patterns and required tokens enforced by mcp-doctor.",
			MIMEType:    "application/json",
			resolve:     func(e environment) string { return e.configPath("MCP_POLICY_CONFIG", "mcp-policy.json") },
		},
		{
			URI:         "dotfiles://mcp/registry",
			Name:        "mcp-registry",
			Title:       "MCP registry",
			Description: "The MCP servers this workstation tracks, with transport, launcher and pinned package for each.",
			MIMEType:    "application/json",
			resolve:     func(e environment) string { return e.configPath("MCP_REGISTRY_CONFIG", "mcp-registry.json") },
		},
		{
			URI:         "dotfiles://mcp/server-card",
			Name:        "mcp-server-card",
			Title:       "MCP server card",
			Description: "This server's own discovery card: transport, capabilities and tool manifest.",
			MIMEType:    "application/json",
			resolve:     func(e environment) string { return e.wellKnownPath("mcp/server-card.json") },
		},
		{
			URI:         "dotfiles://agent/profiles",
			Name:        "agent-profiles",
			Title:       "Agent profiles",
			Description: "The ask/plan/apply/audit operating profiles: approval mode, filesystem and network posture, step budget and MCP profile.",
			MIMEType:    "application/json",
			resolve:     func(e environment) string { return e.configPath("AGENT_PROFILE_CONFIG", "agent-profiles.json") },
		},
		{
			URI:         "dotfiles://agent/card",
			Name:        "agent-card",
			Title:       "A2A agent card",
			Description: "The A2A v0.3 card describing this workstation agent's skills, authentication and entrypoints.",
			MIMEType:    "application/json",
			resolve:     func(e environment) string { return e.wellKnownPath("agent-card.json") },
		},
	}
}

// maxResourceBytes caps a resource read. These are configuration documents;
// anything larger is a symptom, not a payload worth streaming to a model.
const maxResourceBytes = 1 << 20

// readResource loads the document behind one resource entry. A read error
// carries the host path, so the client gets only the URI and logf (stderr)
// gets the detail.
func readResource(r resource, e environment, readFile func(string) ([]byte, error),
	logf func(string, ...any),
) (resourceContents, *rpcError) {
	path := r.resolve(e)
	if path == "" {
		return resourceContents{}, newRPCError(codeResourceNotOK, "resource unavailable",
			fmt.Sprintf("%s: no dotfiles checkout could be resolved", r.URI))
	}
	b, err := readFile(path)
	if err != nil {
		if logf != nil {
			logf("resources/read %s: %v", r.URI, err)
		}
		return resourceContents{}, newRPCError(codeResourceNotOK, "resource unavailable",
			r.URI+": could not be read")
	}
	if len(b) > maxResourceBytes {
		return resourceContents{}, newRPCError(codeResourceNotOK, "resource too large",
			fmt.Sprintf("%s: %d bytes exceeds the %d byte limit", r.URI, len(b), maxResourceBytes))
	}
	return resourceContents{URI: r.URI, Name: r.Name, MIMEType: r.MIMEType, Text: string(b)}, nil
}

// osReadFile is the production file reader seam. It reads at most one byte
// past maxResourceBytes, enough for readResource to refuse an oversized file
// without loading it into memory.
var osReadFile = func(path string) ([]byte, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	return io.ReadAll(io.LimitReader(f, maxResourceBytes+1))
}
