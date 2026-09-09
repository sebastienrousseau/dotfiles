// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
package main

import (
	"errors"
	"path/filepath"
	"strings"
	"testing"
)

// TestResourceResolvers pins where each published URI is looked up. The table
// is the contract: a resource that silently resolved somewhere else would
// serve another tree's policy without any visible symptom.
func TestResourceResolvers(t *testing.T) {
	root := "/repo"
	e := fakeEnv(map[string]string{"DOT_MCP_REPO_ROOT": root, "__wd": "/", "__home": "/home/u"},
		filepath.Join(root, rootMarker),
		"/repo/defaults/dot_config/dotfiles/mcp-policy.json",
		"/repo/defaults/dot_config/dotfiles/mcp-registry.json",
		"/repo/defaults/dot_config/dotfiles/agent-profiles.json",
	)
	want := map[string]string{
		"dotfiles://mcp/policy":      "/repo/defaults/dot_config/dotfiles/mcp-policy.json",
		"dotfiles://mcp/registry":    "/repo/defaults/dot_config/dotfiles/mcp-registry.json",
		"dotfiles://mcp/server-card": "/repo/.well-known/mcp/server-card.json",
		"dotfiles://agent/profiles":  "/repo/defaults/dot_config/dotfiles/agent-profiles.json",
		"dotfiles://agent/card":      "/repo/.well-known/agent-card.json",
	}
	got := map[string]string{}
	for _, r := range defaultResources() {
		got[r.URI] = r.resolve(e)
		if r.MIMEType != "application/json" {
			t.Errorf("%s: mimeType = %q", r.URI, r.MIMEType)
		}
	}
	if len(got) != len(want) {
		t.Fatalf("resolved %d resources, want %d", len(got), len(want))
	}
	for uri, path := range want {
		if got[uri] != path {
			t.Errorf("%s resolved to %q, want %q", uri, got[uri], path)
		}
	}
}

// TestResourceEnvOverridesAreHonoured pins that the resource surface reads the
// same overrides the bash commands do, so the two cannot disagree about which
// file is authoritative.
func TestResourceEnvOverridesAreHonoured(t *testing.T) {
	e := fakeEnv(map[string]string{
		"MCP_POLICY_CONFIG":    "/o/policy.json",
		"MCP_REGISTRY_CONFIG":  "/o/registry.json",
		"AGENT_PROFILE_CONFIG": "/o/profiles.json",
		"__wd":                 "/",
		"__home":               "/h",
	})
	want := map[string]string{
		"dotfiles://mcp/policy":     "/o/policy.json",
		"dotfiles://mcp/registry":   "/o/registry.json",
		"dotfiles://agent/profiles": "/o/profiles.json",
	}
	for _, r := range defaultResources() {
		if expected, ok := want[r.URI]; ok {
			if got := r.resolve(e); got != expected {
				t.Errorf("%s resolved to %q, want %q", r.URI, got, expected)
			}
		}
	}
}

// TestReadResource covers the four outcomes of a read against a fake reader.
func TestReadResource(t *testing.T) {
	e := fakeEnv(map[string]string{"MCP_POLICY_CONFIG": "/policy.json", "__wd": "/", "__home": "/h"})
	policy := resource{
		URI: "dotfiles://mcp/policy", Name: "mcp-policy", MIMEType: "application/json",
		resolve: func(e environment) string { return e.configPath("MCP_POLICY_CONFIG", "mcp-policy.json") },
	}
	unresolvable := resource{URI: "dotfiles://x", resolve: func(environment) string { return "" }}

	got, rerr := readResource(policy, e, func(string) ([]byte, error) { return []byte("{}"), nil })
	if rerr != nil {
		t.Fatalf("unexpected error: %v", rerr)
	}
	if got.Text != "{}" || got.URI != policy.URI || got.Name != "mcp-policy" {
		t.Fatalf("contents = %+v", got)
	}

	if _, rerr = readResource(unresolvable, e, nil); rerr == nil || !strings.Contains(rerr.Message, "unavailable") {
		t.Fatalf("rerr = %v, want an unavailable error", rerr)
	}

	_, rerr = readResource(policy, e, func(string) ([]byte, error) { return nil, errors.New("permission denied") })
	if rerr == nil || rerr.Code != codeResourceNotOK {
		t.Fatalf("rerr = %v, want %d", rerr, codeResourceNotOK)
	}

	_, rerr = readResource(policy, e, func(string) ([]byte, error) { return make([]byte, maxResourceBytes+1), nil })
	if rerr == nil || !strings.Contains(rerr.Message, "too large") {
		t.Fatalf("rerr = %v, want a size error", rerr)
	}
}

// TestOSReadFileSeam exercises the production reader once.
func TestOSReadFileSeam(t *testing.T) {
	if _, err := osReadFile(filepath.Join(t.TempDir(), "absent.json")); err == nil {
		t.Fatal("expected an error reading a missing file")
	}
}
