// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package main

import (
	"errors"
	"fmt"
	"io"
	"strings"
)

// ruleOrder is the order show prints a mode's lists in.
var ruleOrder = []string{
	"tools", "tools_deny", "paths_allow", "paths_deny",
	"hosts_allow", "hosts_deny", "commands_allow", "commands_deny",
}

// runShow is `dot-policy show [--agent A] [--mode M] [--policy F]`: the
// policy file, its modes, and the rules in force for the agent in the
// active mode, one non-empty list a line.
func runShow(args []string, out, errw io.Writer, getenv func(string) string) int {
	o, err := parseOpts("show", args, errw)
	if err != nil {
		return 2
	}
	path := policyPath(o, getenv)
	p, err := LoadPolicy(path)
	if errors.Is(err, ErrNoPolicy) {
		fmt.Fprintf(out, "%s: none, so nothing is enforced\n", path)
		return 0
	}
	if err == nil {
		err = showPolicy(out, p, path, o, getenv)
	}
	if err != nil {
		fmt.Fprintf(errw, "%s: %v\n", path, err)
		return 1
	}
	return 0
}

func showPolicy(out io.Writer, p *Policy, path string, o opts, getenv func(string) string) error {
	mode := activeMode(o, p, getenv)
	rules, err := p.RulesFor(o.agent, mode)
	if err != nil {
		return err
	}
	line := func(key, value string) { fmt.Fprintf(out, "%-15s %s\n", key, value) }
	line("policy", path)
	line("modes", fmt.Sprintf("%s (default %s)", strings.Join(p.Modes(), ", "), p.DefaultMode))
	line("active", fmt.Sprintf("%s, for %s", mode, o.agent))
	fields := rules.ruleFields()
	for _, key := range ruleOrder {
		if list := *fields[key]; len(list) > 0 {
			line(key, strings.Join(list, ", "))
		}
	}
	return nil
}
