// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// The card-truth tests. .well-known/mcp/server-card.json is a published
// promise: a client reads it and decides how to connect and what to expect.
// These tests fail when the promise and the server drift apart in either
// direction — a declared tool that is not served, or a served tool that is not
// declared.
package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

// repoRootFromTest locates the checkout this module lives in. When the module
// has been deployed to ~/.local/share (chezmoi's target), the cards are not
// alongside it and these tests skip: they are a repository gate, not a runtime
// requirement.
func repoRootFromTest(t *testing.T) string {
	t.Helper()
	root, err := filepath.Abs(filepath.Join("..", "..", "..", ".."))
	if err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(root, rootMarker)); err != nil {
		t.Skipf("not running inside a dotfiles checkout (%v)", err)
	}
	return root
}

// serverCard is the subset of the published card these tests police.
type serverCard struct {
	CardVersion      string   `json:"cardVersion"`
	Name             string   `json:"name"`
	Version          string   `json:"version"`
	ProtocolVersions []string `json:"protocolVersions"`
	Transport        struct {
		Stdio struct {
			Command string   `json:"command"`
			Args    []string `json:"args"`
		} `json:"stdio"`
	} `json:"transport"`
	Capabilities map[string]bool `json:"capabilities"`
	Security     struct {
		Mutates bool `json:"mutates"`
	} `json:"security"`
	Tools []struct {
		Name        string `json:"name"`
		Description string `json:"description"`
		ReadOnly    bool   `json:"readOnly"`
	} `json:"tools"`
	Resources []struct {
		URI         string `json:"uri"`
		Description string `json:"description"`
	} `json:"resources"`
	Implementation struct {
		Module string `json:"module"`
		Binary string `json:"binary"`
	} `json:"implementation"`
}

// loadServerCard reads and decodes the published card.
func loadServerCard(t *testing.T) serverCard {
	t.Helper()
	path := filepath.Join(repoRootFromTest(t), ".well-known", "mcp", "server-card.json")
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read %s: %v", path, err)
	}
	var card serverCard
	if err := json.Unmarshal(b, &card); err != nil {
		t.Fatalf("%s is not valid JSON: %v", path, err)
	}
	return card
}

// TestServerCardMatchesRegistry is the central guard: the card's tool list and
// the registry the server serves must name exactly the same tools.
func TestServerCardMatchesRegistry(t *testing.T) {
	card := loadServerCard(t)
	served := map[string]bool{}
	for _, tl := range defaultTools() {
		served[tl.Name] = true
	}
	declared := map[string]bool{}
	for _, entry := range card.Tools {
		declared[entry.Name] = true
		if entry.Description == "" {
			t.Errorf("card tool %q has no description", entry.Name)
		}
		if !entry.ReadOnly {
			t.Errorf("card tool %q is not marked read-only, but every served tool is", entry.Name)
		}
		if !served[entry.Name] {
			t.Errorf("card declares tool %q, which the server does not serve", entry.Name)
		}
	}
	for name := range served {
		if !declared[name] {
			t.Errorf("server serves tool %q, which the card does not declare", name)
		}
	}
}

// TestServerCardMatchesResources is the same guard for the resource surface,
// which is why capabilities.resources may say true.
func TestServerCardMatchesResources(t *testing.T) {
	card := loadServerCard(t)
	served := map[string]bool{}
	for _, r := range defaultResources() {
		served[r.URI] = true
	}
	declared := map[string]bool{}
	for _, entry := range card.Resources {
		declared[entry.URI] = true
		if entry.Description == "" {
			t.Errorf("card resource %q has no description", entry.URI)
		}
		if !served[entry.URI] {
			t.Errorf("card declares resource %q, which the server does not serve", entry.URI)
		}
	}
	for uri := range served {
		if !declared[uri] {
			t.Errorf("server serves resource %q, which the card does not declare", uri)
		}
	}
}

// TestServerCardCapabilitiesAreImplemented pins each declared capability to
// something the server actually does — and pins `prompts` to false, because it
// does not.
func TestServerCardCapabilitiesAreImplemented(t *testing.T) {
	card := loadServerCard(t)
	want := map[string]bool{
		"tools":     len(defaultTools()) > 0,
		"resources": len(defaultResources()) > 0,
		"prompts":   false, // no prompts/* handler exists
		"logging":   true,  // logging/setLevel + notifications/message
	}
	if len(card.Capabilities) != len(want) {
		t.Fatalf("card declares %d capabilities, want %d", len(card.Capabilities), len(want))
	}
	for name, expected := range want {
		if card.Capabilities[name] != expected {
			t.Errorf("capabilities.%s = %v, want %v", name, card.Capabilities[name], expected)
		}
	}
	if card.Security.Mutates {
		t.Error("the card claims the server mutates state; every tool is read-only")
	}
}

// TestServerCardTransportLaunchesTheServer pins the exact command a client
// would run. This is the field that was untrue before the server existed.
func TestServerCardTransportLaunchesTheServer(t *testing.T) {
	card := loadServerCard(t)
	if card.Transport.Stdio.Command != "dot" {
		t.Errorf("transport command = %q, want \"dot\"", card.Transport.Stdio.Command)
	}
	want := []string{"mcp", "serve"}
	if len(card.Transport.Stdio.Args) != len(want) {
		t.Fatalf("transport args = %v, want %v", card.Transport.Stdio.Args, want)
	}
	for i := range want {
		if card.Transport.Stdio.Args[i] != want[i] {
			t.Fatalf("transport args = %v, want %v", card.Transport.Stdio.Args, want)
		}
	}
}

// TestServerCardProtocolVersionsAreSupported pins the negotiation table.
func TestServerCardProtocolVersionsAreSupported(t *testing.T) {
	card := loadServerCard(t)
	if len(card.ProtocolVersions) != len(supportedProtocolVersions) {
		t.Fatalf("card lists %v, server supports %v", card.ProtocolVersions, supportedProtocolVersions)
	}
	for i, v := range card.ProtocolVersions {
		if v != supportedProtocolVersions[i] {
			t.Errorf("protocolVersions[%d] = %q, want %q", i, v, supportedProtocolVersions[i])
		}
	}
}

// TestVersionMatchesServerCard keeps serverInfo.version and the published card
// in step; version-sync.sh rewrites both, and this fails if it misses one.
func TestVersionMatchesServerCard(t *testing.T) {
	card := loadServerCard(t)
	if card.Version != version {
		t.Fatalf("card version = %q, binary version = %q", card.Version, version)
	}
	if card.Name != serverName {
		t.Fatalf("card name = %q, server name = %q", card.Name, serverName)
	}
}

// TestServerCardPointsAtThisModule pins the implementation block, so the card
// names the module a reader would have to open to check any of the above.
func TestServerCardPointsAtThisModule(t *testing.T) {
	card := loadServerCard(t)
	root := repoRootFromTest(t)
	if card.Implementation.Module == "" {
		t.Fatal("card does not name the implementing module")
	}
	if _, err := os.Stat(filepath.Join(root, card.Implementation.Module, "go.mod")); err != nil {
		t.Fatalf("implementation.module %q is not a Go module: %v", card.Implementation.Module, err)
	}
	if card.Implementation.Binary != "dot-mcp" {
		t.Errorf("implementation.binary = %q, want \"dot-mcp\"", card.Implementation.Binary)
	}
}

// TestAgentCardEntrypointMatchesTheTransport covers the other published card:
// the A2A card advertises an `mcp` entrypoint, which must be the command that
// starts this server rather than the old one-shot audit invocation.
func TestAgentCardEntrypointMatchesTheTransport(t *testing.T) {
	path := filepath.Join(repoRootFromTest(t), ".well-known", "agent-card.json")
	b, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read %s: %v", path, err)
	}
	var card struct {
		Version     string            `json:"version"`
		Protocols   []string          `json:"protocols"`
		Entrypoints map[string]string `json:"entrypoints"`
	}
	if err := json.Unmarshal(b, &card); err != nil {
		t.Fatalf("%s is not valid JSON: %v", path, err)
	}
	if got, want := card.Entrypoints["mcp"], "dot mcp serve"; got != want {
		t.Errorf("entrypoints.mcp = %q, want %q", got, want)
	}
	if !containsString(card.Protocols, "mcp") {
		t.Error("the A2A card no longer claims the mcp protocol")
	}
}
