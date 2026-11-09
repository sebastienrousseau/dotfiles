// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// dot-policy — the enforced AI policy (plan P1.1, ADR-025) behind
// `dot cli hook policy` and `dot ai policy check`.
//
// An agent's PreToolUse hook (Gemini CLI: BeforeTool) runs
// `dot-policy check --agent <id>` with the tool call as JSON on stdin. The
// rules for the active mode in ~/.config/dotfiles/ai-policy.toml (schema
// ai-policy.v1) decide it; a denial is printed in the form that agent
// reads, with the reason, and anything else prints nothing (Gemini CLI:
// {}). It fails closed: a policy file that does not parse or validate, an
// unknown mode or an unreadable call is a denial. With no policy file,
// nothing is enforced.
//
// Subcommands:
//
//	check [--agent A] [--mode M] [--policy F]   decide the call on stdin
//	validate [--policy F]                       check the file, list its modes
//	--version                                   print the version
package main

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

// version is set by the build to the framework version
// (.chezmoitemplates/go-build-command); unset, it is "dev".
var version = "dev"

// exit is os.Exit, a seam for tests.
var exit = os.Exit

// maxCall bounds the payload read from stdin (a patch can be large).
const maxCall = 4 << 20

func main() {
	exit(run(os.Args[1:], os.Stdin, os.Stdout, os.Stderr, os.Getenv))
}

func run(args []string, in io.Reader, out, errw io.Writer, getenv func(string) string) int {
	if len(args) == 0 {
		fmt.Fprintln(errw, "usage: dot-policy check|validate|--version")
		return 2
	}
	switch args[0] {
	case "check":
		return runCheck(args[1:], in, out, errw, getenv)
	case "validate":
		return runValidate(args[1:], out, errw, getenv)
	case "--version":
		fmt.Fprintln(out, "dot-policy", version)
		return 0
	}
	fmt.Fprintf(errw, "dot-policy: unknown command %q\n", args[0])
	return 2
}

type opts struct{ agent, mode, policy string }

func parseOpts(name string, args []string, errw io.Writer) (opts, error) {
	var o opts
	fs := flag.NewFlagSet(name, flag.ContinueOnError)
	fs.SetOutput(errw)
	fs.StringVar(&o.agent, "agent", "claude", "agent whose hook this is")
	fs.StringVar(&o.mode, "mode", "", "mode (default: the active one)")
	fs.StringVar(&o.policy, "policy", "", "policy file")
	if err := fs.Parse(args); err != nil {
		return o, err
	}
	if fs.NArg() > 0 {
		return o, fmt.Errorf("unexpected argument %q", fs.Arg(0))
	}
	return o, nil
}

// policyPath is --policy, else $DOT_AI_POLICY, else
// $XDG_CONFIG_HOME/dotfiles/ai-policy.toml.
func policyPath(o opts, getenv func(string) string) string {
	if o.policy != "" {
		return o.policy
	}
	if p := getenv("DOT_AI_POLICY"); p != "" {
		return p
	}
	return filepath.Join(configHome(getenv), "dotfiles", "ai-policy.toml")
}

func configHome(getenv func(string) string) string {
	if x := getenv("XDG_CONFIG_HOME"); x != "" {
		return x
	}
	return filepath.Join(getenv("HOME"), ".config")
}

// activeMode is --mode, else $DOT_AGENT_PROFILE (dot agent mode run sets
// it), else the last DOT_AGENT_PROFILE= in the agent-mode state file (dot
// agent mode set writes it), else the policy's default_mode.
func activeMode(o opts, p *Policy, getenv func(string) string) string {
	if o.mode != "" {
		return o.mode
	}
	if m := getenv("DOT_AGENT_PROFILE"); m != "" {
		return m
	}
	state := getenv("AGENT_STATE_FILE")
	if state == "" {
		state = filepath.Join(configHome(getenv), "dotfiles", "agent-mode.env")
	}
	if m := lastProfile(state); m != "" {
		return m
	}
	return p.DefaultMode
}

func lastProfile(file string) string {
	data, err := os.ReadFile(file)
	if err != nil {
		return ""
	}
	mode := ""
	for _, line := range strings.Split(string(data), "\n") {
		if v, ok := strings.CutPrefix(line, "DOT_AGENT_PROFILE="); ok {
			mode = strings.TrimSpace(v)
		}
	}
	return mode
}

func runCheck(args []string, in io.Reader, out, errw io.Writer, getenv func(string) string) int {
	o, err := parseOpts("check", args, errw)
	if err != nil {
		writeDecision(out, "", "dot-policy: "+err.Error())
		return 0
	}
	writeDecision(out, o.agent, decideCall(o, in, getenv))
	return 0
}

// decideCall is the denial reason for the call on stdin, or "" to allow.
func decideCall(o opts, in io.Reader, getenv func(string) string) string {
	path := policyPath(o, getenv)
	p, err := LoadPolicy(path)
	if errors.Is(err, ErrNoPolicy) {
		return ""
	}
	if err != nil {
		return fmt.Sprintf("dot ai policy: %s is invalid (%v); every tool call is denied until it is fixed (dot ai policy check)", path, err)
	}
	mode := activeMode(o, p, getenv)
	rules, err := p.RulesFor(o.agent, mode)
	if err != nil {
		return fmt.Sprintf("dot ai policy: %v in %s", err, path)
	}
	var c Call
	if err := json.NewDecoder(io.LimitReader(in, maxCall)).Decode(&c); err != nil || c.Tool == "" {
		return "dot ai policy: the hook payload names no tool call"
	}
	if why := Decide(rules, c, getenv("HOME")); why != "" {
		return fmt.Sprintf("dot ai policy (mode %s): %s", mode, why)
	}
	return ""
}

// writeDecision prints a denial as the agent's hook protocol reads it:
// Gemini CLI's decision/reason, else the PreToolUse permissionDecision that
// Claude Code and Codex read. An allow prints nothing, or {} for Gemini CLI.
func writeDecision(out io.Writer, agent, reason string) {
	var v any
	switch {
	case agent == "gemini" && reason == "":
		v = map[string]any{}
	case agent == "gemini":
		v = map[string]any{"decision": "deny", "reason": reason}
	case reason == "":
		return
	default:
		v = map[string]any{"hookSpecificOutput": map[string]any{
			"hookEventName":            "PreToolUse",
			"permissionDecision":       "deny",
			"permissionDecisionReason": reason,
		}}
	}
	_ = json.NewEncoder(out).Encode(v)
}

func runValidate(args []string, out, errw io.Writer, getenv func(string) string) int {
	o, err := parseOpts("validate", args, errw)
	if err != nil {
		return 2
	}
	path := policyPath(o, getenv)
	p, err := LoadPolicy(path)
	if errors.Is(err, ErrNoPolicy) {
		fmt.Fprintf(out, "%s: none, so nothing is enforced\n", path)
		return 0
	}
	if err != nil {
		fmt.Fprintf(errw, "%s: %v\n", path, err)
		return 1
	}
	fmt.Fprintf(out, "%s: valid; modes %s (default %s), active %s\n",
		path, strings.Join(p.Modes(), ", "), p.DefaultMode, activeMode(o, p, getenv))
	return 0
}
