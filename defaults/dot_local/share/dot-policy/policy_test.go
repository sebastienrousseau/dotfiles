// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package main

import (
	"errors"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

const samplePolicy = `
schema = "ai-policy.v1"
default_mode = "ask"

[mode.ask]
tools = ["read", "search"]

[mode.apply]
tools = ["*"]
tools_deny = ["mcp__github__*"]
paths_allow = ["{cwd}/**", "/tmp/**"]
paths_deny = ["~/.ssh/**", "**/.env"]
hosts_allow = ["github.com", "*.github.com"]
commands_deny = ["rm -rf *", "git push --force*", "sudo *"]

[agent.codex.mode.apply]
tools = ["read", "search", "shell"]
commands_allow = []
`

func mustParse(t *testing.T, doc string) *Policy {
	t.Helper()
	p, err := ParsePolicy(doc)
	if err != nil {
		t.Fatalf("ParsePolicy: %v", err)
	}
	return p
}

func TestParsePolicyAcceptsTheSample(t *testing.T) {
	p := mustParse(t, samplePolicy)
	if got := p.Modes(); !reflect.DeepEqual(got, []string{"apply", "ask"}) {
		t.Fatalf("Modes() = %v", got)
	}
}

func TestParsePolicyRejects(t *testing.T) {
	cases := map[string]string{
		"not toml":          `schema = `,
		"wrong schema":      "schema = \"ai-policy.v2\"\ndefault_mode = \"ask\"\n[mode.ask]\ntools = []\n",
		"no modes":          "schema = \"ai-policy.v1\"\ndefault_mode = \"ask\"\n",
		"default undefined": "schema = \"ai-policy.v1\"\ndefault_mode = \"plan\"\n[mode.ask]\ntools = []\n",
		"unknown key":       "schema = \"ai-policy.v1\"\ndefault_mode = \"ask\"\n[mode.ask]\ntool = [\"read\"]\n",
		"bad mode name":     "schema = \"ai-policy.v1\"\ndefault_mode = \"Ask\"\n[mode.Ask]\ntools = []\n",
		"empty pattern":     "schema = \"ai-policy.v1\"\ndefault_mode = \"ask\"\n[mode.ask]\ntools = [\"\"]\n",
		"bad agent name":    "schema = \"ai-policy.v1\"\ndefault_mode = \"ask\"\n[mode.ask]\ntools = []\n[agent.\"../x\".mode.ask]\ntools = []\n",
		"agent mode absent": "schema = \"ai-policy.v1\"\ndefault_mode = \"ask\"\n[mode.ask]\ntools = []\n[agent.codex.mode.apply]\ntools = []\n",
		"agent bad pattern": "schema = \"ai-policy.v1\"\ndefault_mode = \"ask\"\n[mode.ask]\ntools = []\n[agent.codex.mode.ask]\npaths_deny = [\"\"]\n",
	}
	for name, doc := range cases {
		if _, err := ParsePolicy(doc); err == nil {
			t.Errorf("%s: accepted", name)
		}
	}
}

func TestLoadPolicy(t *testing.T) {
	dir := t.TempDir()
	if _, err := LoadPolicy(filepath.Join(dir, "none.toml")); !errors.Is(err, ErrNoPolicy) {
		t.Fatalf("missing file: %v, want ErrNoPolicy", err)
	}
	if _, err := LoadPolicy(dir); err == nil || errors.Is(err, ErrNoPolicy) {
		t.Fatalf("a directory: %v, want a read error", err)
	}
	f := filepath.Join(dir, "p.toml")
	if err := os.WriteFile(f, []byte(samplePolicy), 0o600); err != nil {
		t.Fatal(err)
	}
	if _, err := LoadPolicy(f); err != nil {
		t.Fatalf("sample: %v", err)
	}
}

func TestRulesForAppliesOnlyTheKeysAnAgentSets(t *testing.T) {
	p := mustParse(t, samplePolicy)
	r, err := p.RulesFor("codex", "apply")
	if err != nil {
		t.Fatal(err)
	}
	if !reflect.DeepEqual(r.Tools, []string{"read", "search", "shell"}) {
		t.Errorf("tools = %v, want the codex override", r.Tools)
	}
	if len(r.CommandsAllow) != 0 {
		t.Errorf("commands_allow = %v, want the override's empty list", r.CommandsAllow)
	}
	if !reflect.DeepEqual(r.CommandsDeny, p.Mode["apply"].CommandsDeny) {
		t.Errorf("commands_deny = %v, want the mode's", r.CommandsDeny)
	}
	if got := p.Mode["apply"].Tools; !reflect.DeepEqual(got, []string{"*"}) {
		t.Errorf("the mode's own rules changed: %v", got)
	}
	if r, _ := p.RulesFor("claude", "apply"); !reflect.DeepEqual(r.Tools, []string{"*"}) {
		t.Errorf("claude has no override, got %v", r.Tools)
	}
	if r, _ := p.RulesFor("codex", "ask"); !reflect.DeepEqual(r.Tools, []string{"read", "search"}) {
		t.Errorf("codex has no ask override, got %v", r.Tools)
	}
	if _, err := p.RulesFor("claude", "audit"); err == nil || !strings.Contains(err.Error(), `"audit"`) {
		t.Errorf("an undefined mode: %v", err)
	}
}
