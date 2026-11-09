// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package main

import (
	"strings"
	"testing"
)

func TestShow(t *testing.T) {
	f := newFixture(t, "")
	if code, out, _ := f.run("", "show"); code != 0 || !strings.HasSuffix(out, "ai-policy.toml: none, so nothing is enforced\n") {
		t.Fatalf("no policy: %d %q", code, out)
	}
	f = newFixture(t, samplePolicy)
	f.env["DOT_AGENT_PROFILE"] = "apply"
	code, out, _ := f.run("", "show", "--agent", "codex")
	want := "policy          " + f.home + "/.config/dotfiles/ai-policy.toml\n" +
		"modes           apply, ask (default ask)\n" +
		"active          apply, for codex\n" +
		"tools           read, search, shell\n" +
		"tools_deny      mcp__github__*\n" +
		"paths_allow     {cwd}/**, /tmp/**\n" +
		"paths_deny      ~/.ssh/**, **/.env\n" +
		"hosts_allow     github.com, *.github.com\n" +
		"commands_deny   rm -rf *, git push --force*, sudo *\n"
	if code != 0 || out != want {
		t.Fatalf("apply for codex: %d\n%s\nwant\n%s", code, out, want)
	}
	if _, out, _ := f.run("", "show", "--mode", "ask"); !strings.Contains(out, "active          ask, for claude\ntools           read, search\n") {
		t.Fatalf("--mode: %q", out)
	}
	if code, _, errw := f.run("", "show", "--mode", "nope"); code != 1 || !strings.Contains(errw, `mode "nope" has no rules`) {
		t.Fatalf("an undefined mode: %d %q", code, errw)
	}
	f = newFixture(t, "schema = \"x\"\n")
	if code, _, errw := f.run("", "show"); code != 1 || !strings.Contains(errw, `schema is "x"`) {
		t.Fatalf("invalid: %d %q", code, errw)
	}
	if code, _, _ := f.run("", "show", "--nope"); code != 2 {
		t.Fatalf("a bad flag: %d", code)
	}
}
