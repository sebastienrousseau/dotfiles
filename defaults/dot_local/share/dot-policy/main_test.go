// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package main

import (
	"bytes"
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

type fixture struct {
	t    *testing.T
	home string
	env  map[string]string
}

func newFixture(t *testing.T, policy string) *fixture {
	home := t.TempDir()
	f := &fixture{t: t, home: home, env: map[string]string{"HOME": home}}
	if policy != "" {
		f.write(".config/dotfiles/ai-policy.toml", policy)
	}
	return f
}

func (f *fixture) write(rel, body string) string {
	p := filepath.Join(f.home, rel)
	if err := os.MkdirAll(filepath.Dir(p), 0o700); err != nil {
		f.t.Fatal(err)
	}
	if err := os.WriteFile(p, []byte(body), 0o600); err != nil {
		f.t.Fatal(err)
	}
	return p
}

func (f *fixture) run(stdin string, args ...string) (int, string, string) {
	var out, errw bytes.Buffer
	code := run(args, strings.NewReader(stdin), &out, &errw, func(k string) string { return f.env[k] })
	return code, out.String(), errw.String()
}

const writeCall = `{"tool_name":"Write","tool_input":{"file_path":"/work/a"},"cwd":"/work"}`
const readCall = `{"tool_name":"Read","tool_input":{"file_path":"/work/a"},"cwd":"/work"}`

func reasonOf(t *testing.T, out string) string {
	t.Helper()
	var v struct {
		H struct {
			Event    string `json:"hookEventName"`
			Decision string `json:"permissionDecision"`
			Reason   string `json:"permissionDecisionReason"`
		} `json:"hookSpecificOutput"`
	}
	if err := json.Unmarshal([]byte(out), &v); err != nil {
		t.Fatalf("not a decision: %q (%v)", out, err)
	}
	if v.H.Event != "PreToolUse" || v.H.Decision != "deny" {
		t.Fatalf("not a PreToolUse deny: %q", out)
	}
	return v.H.Reason
}

func TestCheckWithoutAPolicyAllowsEverything(t *testing.T) {
	f := newFixture(t, "")
	if code, out, _ := f.run(writeCall, "check"); code != 0 || out != "" {
		t.Fatalf("got %d %q, want 0 and nothing", code, out)
	}
	if _, out, _ := f.run(writeCall, "check", "--agent", "gemini"); out != "{}\n" {
		t.Fatalf("gemini allow = %q, want {}", out)
	}
}

func TestCheckDeniesByTheDefaultMode(t *testing.T) {
	f := newFixture(t, samplePolicy)
	code, out, _ := f.run(writeCall, "check")
	if code != 0 {
		t.Fatalf("exit %d", code)
	}
	if r := reasonOf(t, out); !strings.Contains(r, "(mode ask): tool Write (write) is not allowed") {
		t.Fatalf("reason %q", r)
	}
	if _, out, _ := f.run(readCall, "check"); out != "" {
		t.Fatalf("a read in ask mode was denied: %q", out)
	}
}

func TestCheckGeminiDenial(t *testing.T) {
	f := newFixture(t, samplePolicy)
	_, out, _ := f.run(writeCall, "check", "--agent", "gemini")
	var v map[string]string
	if err := json.Unmarshal([]byte(out), &v); err != nil || v["decision"] != "deny" || !strings.Contains(v["reason"], "not allowed") {
		t.Fatalf("gemini deny = %q", out)
	}
}

func TestCheckModeSources(t *testing.T) {
	f := newFixture(t, samplePolicy)
	if _, out, _ := f.run(writeCall, "check", "--mode", "apply"); out != "" {
		t.Fatalf("--mode apply denied: %q", out)
	}
	f.env["DOT_AGENT_PROFILE"] = "apply"
	if _, out, _ := f.run(writeCall, "check"); out != "" {
		t.Fatalf("$DOT_AGENT_PROFILE apply denied: %q", out)
	}
	delete(f.env, "DOT_AGENT_PROFILE")
	f.write(".config/dotfiles/agent-mode.env", "DOT_AGENT_PROFILE=ask\nDOT_AGENT_ROLE=dev\nDOT_AGENT_PROFILE=apply\n")
	if _, out, _ := f.run(writeCall, "check"); out != "" {
		t.Fatalf("the state file's last mode (apply) denied: %q", out)
	}
	f.env["AGENT_STATE_FILE"] = f.write("state.env", "DOT_AGENT_PROFILE=ask\n")
	if _, out, _ := f.run(writeCall, "check"); out == "" {
		t.Fatal("$AGENT_STATE_FILE (ask) allowed a write")
	}
	f.env["AGENT_STATE_FILE"] = f.write("empty.env", "")
	if _, out, _ := f.run(writeCall, "check"); out == "" {
		t.Fatal("an empty state file falls back to default_mode ask, which denies a write")
	}
}

func TestCheckFailsClosed(t *testing.T) {
	f := newFixture(t, "schema = ")
	if r := reasonOf(t, mustOut(f.run(readCall, "check"))); !strings.Contains(r, "is invalid") {
		t.Fatalf("a malformed policy: %q", r)
	}
	f = newFixture(t, samplePolicy)
	if r := reasonOf(t, mustOut(f.run(readCall, "check", "--mode", "audit"))); !strings.Contains(r, `mode "audit" has no rules`) {
		t.Fatalf("an undefined mode: %q", r)
	}
	if r := reasonOf(t, mustOut(f.run("not json", "check"))); !strings.Contains(r, "names no tool call") {
		t.Fatalf("a bad payload: %q", r)
	}
	if r := reasonOf(t, mustOut(f.run(`{"cwd":"/"}`, "check"))); !strings.Contains(r, "names no tool call") {
		t.Fatalf("no tool_name: %q", r)
	}
	if r := reasonOf(t, mustOut(f.run(readCall, "check", "--bogus"))); !strings.Contains(r, "dot-policy:") {
		t.Fatalf("a bad flag: %q", r)
	}
	if r := reasonOf(t, mustOut(f.run(readCall, "check", "extra"))); !strings.Contains(r, `unexpected argument "extra"`) {
		t.Fatalf("an extra argument: %q", r)
	}
}

func mustOut(_ int, out, _ string) string { return out }

func writeFile(path, body string) error { return os.WriteFile(path, []byte(body), 0o600) }

func TestPolicyPathSources(t *testing.T) {
	f := newFixture(t, "")
	alt := f.write("alt.toml", samplePolicy)
	if _, out, _ := f.run(writeCall, "check", "--policy", alt); out == "" {
		t.Fatal("--policy was not read")
	}
	f.env["DOT_AI_POLICY"] = alt
	if _, out, _ := f.run(writeCall, "check"); out == "" {
		t.Fatal("$DOT_AI_POLICY was not read")
	}
	delete(f.env, "DOT_AI_POLICY")
	f.env["XDG_CONFIG_HOME"] = filepath.Join(f.home, "xdg")
	f.write("xdg/dotfiles/ai-policy.toml", samplePolicy)
	if _, out, _ := f.run(writeCall, "check"); out == "" {
		t.Fatal("$XDG_CONFIG_HOME/dotfiles/ai-policy.toml was not read")
	}
}

func TestValidate(t *testing.T) {
	f := newFixture(t, "")
	if code, out, _ := f.run("", "validate"); code != 0 || !strings.Contains(out, "none, so nothing is enforced") {
		t.Fatalf("no policy: %d %q", code, out)
	}
	f = newFixture(t, samplePolicy)
	if code, out, _ := f.run("", "validate"); code != 0 || !strings.Contains(out, "valid; modes apply, ask (default ask), active ask") {
		t.Fatalf("valid: %d %q", code, out)
	}
	f = newFixture(t, "schema = \"x\"\n")
	if code, _, errw := f.run("", "validate"); code != 1 || !strings.Contains(errw, `schema is "x"`) {
		t.Fatalf("invalid: %d %q", code, errw)
	}
	if code, _, _ := f.run("", "validate", "--nope"); code != 2 {
		t.Fatalf("a bad flag: %d", code)
	}
}

func TestRunDispatch(t *testing.T) {
	f := newFixture(t, "")
	if code, _, errw := f.run(""); code != 2 || !strings.Contains(errw, "usage") {
		t.Fatalf("no command: %d %q", code, errw)
	}
	if code, _, errw := f.run("", "nope"); code != 2 || !strings.Contains(errw, `unknown command "nope"`) {
		t.Fatalf("unknown: %d %q", code, errw)
	}
	if code, out, _ := f.run("", "--version"); code != 0 || out != "dot-policy dev\n" {
		t.Fatalf("version: %d %q", code, out)
	}
}

func TestMain_UsesTheExitSeam(t *testing.T) {
	got := -1
	exit = func(c int) { got = c }
	defer func() { exit = os.Exit }()
	args := os.Args
	os.Args = []string{"dot-policy", "--version"}
	defer func() { os.Args = args }()
	main()
	if got != 0 {
		t.Fatalf("exit %d", got)
	}
}
