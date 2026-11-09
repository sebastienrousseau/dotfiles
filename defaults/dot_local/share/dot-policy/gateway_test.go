// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package main

import (
	"strings"
	"testing"
)

const gatewayPolicy = samplePolicy + `
[gateway]
models = ["haiku", "claude-sonnet-*"]
max_input_tokens = 1000
`

func TestDecideRequest(t *testing.T) {
	g := GatewayRules{Models: []string{"haiku", "claude-sonnet-*"}, MaxInputTokens: 1000}
	cases := []struct {
		name, model string
		tokens      int
		want        string
	}{
		{"an allowed alias", "haiku", 10, ""},
		{"an allowed id by glob", "claude-sonnet-4-6", 1000, ""},
		{"a model not listed", "opus", 10, `model "opus" is not in gateway.models`},
		{"a glob does not cross into a longer name", "haiku-x", 10, `model "haiku-x" is not in gateway.models`},
		{"over the cap", "haiku", 1001, "about 1001 input tokens, over gateway.max_input_tokens (1000)"},
	}
	for _, tc := range cases {
		if got := DecideRequest(g, tc.model, tc.tokens); got != tc.want {
			t.Errorf("%s: got %q, want %q", tc.name, got, tc.want)
		}
	}
	if got := DecideRequest(GatewayRules{}, "opus", 1<<30); got != "" {
		t.Errorf("no [gateway] table limits nothing: %q", got)
	}
}

func TestGatewayValidation(t *testing.T) {
	if _, err := ParsePolicy(gatewayPolicy); err != nil {
		t.Fatalf("valid: %v", err)
	}
	for doc, want := range map[string]string{
		samplePolicy + "[gateway]\nmodels = [\"\"]\n":          "gateway.models: an empty pattern",
		samplePolicy + "[gateway]\nmax_input_tokens = -1\n":    "gateway.max_input_tokens: -1 is below 0",
		samplePolicy + "[gateway]\nmax_output_tokens = 10\n":   `unknown key "gateway.max_output_tokens"`,
		samplePolicy + "[gateway]\nmax_input_tokens = \"x\"\n": "max_input_tokens",
	} {
		if _, err := ParsePolicy(doc); err == nil || !strings.Contains(err.Error(), want) {
			t.Errorf("%q: got %v, want %q", doc, err, want)
		}
	}
}

func TestRunGateway(t *testing.T) {
	f := newFixture(t, "")
	if code, out, _ := f.run("", "gateway", "--model", "opus", "--input-tokens", "9"); code != 0 || out != "" {
		t.Fatalf("no policy allows: %d %q", code, out)
	}
	f = newFixture(t, gatewayPolicy)
	if code, out, _ := f.run("", "gateway", "--model", "haiku", "--input-tokens", "9"); code != 0 || out != "" {
		t.Fatalf("allowed: %d %q", code, out)
	}
	code, out, _ := f.run("", "gateway", "--model", "opus", "--input-tokens", "9")
	if code != 1 || out != "dot ai policy: model \"opus\" is not in gateway.models\n" {
		t.Fatalf("denied: %d %q", code, out)
	}
	f = newFixture(t, "schema = \"x\"\n")
	code, out, _ = f.run("", "gateway", "--model", "haiku")
	if code != 1 || !strings.Contains(out, "is invalid") || !strings.Contains(out, "every request is refused") {
		t.Fatalf("an invalid policy refuses (fail closed): %d %q", code, out)
	}
	if code, _, _ := f.run("", "gateway", "--nope"); code != 2 {
		t.Fatalf("a bad flag: %d", code)
	}
	if code, _, errw := f.run("", "gateway", "extra"); code != 2 || !strings.Contains(errw, `unexpected argument "extra"`) {
		t.Fatalf("an argument: %d %q", code, errw)
	}
}

func TestShowGateway(t *testing.T) {
	f := newFixture(t, gatewayPolicy)
	_, out, _ := f.run("", "show")
	if !strings.HasSuffix(out, "gateway.models  haiku, claude-sonnet-*\ngateway.max_input_tokens 1000\n") {
		t.Fatalf("the [gateway] limits: %q", out)
	}
	f = newFixture(t, samplePolicy)
	if _, out, _ := f.run("", "show"); strings.Contains(out, "gateway") {
		t.Fatalf("no [gateway] table, no lines: %q", out)
	}
}
