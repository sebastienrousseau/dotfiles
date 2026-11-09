// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package main

import (
	"errors"
	"fmt"
	"os"
	"regexp"
	"sort"

	"github.com/BurntSushi/toml"
)

// Schema is the only policy schema this binary reads.
const Schema = "ai-policy.v1"

// Rules is what one mode allows. Every list holds globs (see glob.go).
// Tools is an allow-list: a tool runs only when a pattern names its class
// (shell, read, write, search, fetch, mcp) or its own name, so an empty
// list allows nothing. The other allow-lists are open when empty; a deny
// match always wins.
type Rules struct {
	Tools         []string `toml:"tools"`
	ToolsDeny     []string `toml:"tools_deny"`
	PathsAllow    []string `toml:"paths_allow"`
	PathsDeny     []string `toml:"paths_deny"`
	HostsAllow    []string `toml:"hosts_allow"`
	HostsDeny     []string `toml:"hosts_deny"`
	CommandsAllow []string `toml:"commands_allow"`
	CommandsDeny  []string `toml:"commands_deny"`
}

// ruleFields names each Rules list by its TOML key, for overrides and
// validation.
func (r *Rules) ruleFields() map[string]*[]string {
	return map[string]*[]string{
		"tools": &r.Tools, "tools_deny": &r.ToolsDeny,
		"paths_allow": &r.PathsAllow, "paths_deny": &r.PathsDeny,
		"hosts_allow": &r.HostsAllow, "hosts_deny": &r.HostsDeny,
		"commands_allow": &r.CommandsAllow, "commands_deny": &r.CommandsDeny,
	}
}

// AgentRules overrides a mode's rules for one agent.
type AgentRules struct {
	Mode map[string]Rules `toml:"mode"`
}

// Policy is ~/.config/dotfiles/ai-policy.toml.
type Policy struct {
	Schema      string                `toml:"schema"`
	DefaultMode string                `toml:"default_mode"`
	Mode        map[string]Rules      `toml:"mode"`
	Agent       map[string]AgentRules `toml:"agent"`
	Gateway     GatewayRules          `toml:"gateway"`
	meta        toml.MetaData
}

var nameRe = regexp.MustCompile(`^[a-z][a-z0-9-]{0,31}$`)

// ErrNoPolicy says the policy file does not exist: nothing is enforced.
var ErrNoPolicy = errors.New("no policy file")

// LoadPolicy reads and validates the file at path. A missing file is
// ErrNoPolicy; anything else that is wrong with it is an error, which the
// caller turns into a denial (fail closed).
func LoadPolicy(path string) (*Policy, error) {
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return nil, ErrNoPolicy
	}
	if err != nil {
		return nil, err
	}
	return ParsePolicy(string(data))
}

// ParsePolicy decodes and validates a policy document.
func ParsePolicy(doc string) (*Policy, error) {
	var p Policy
	md, err := toml.Decode(doc, &p)
	if err != nil {
		return nil, err
	}
	p.meta = md
	if keys := md.Undecoded(); len(keys) > 0 {
		return nil, fmt.Errorf("unknown key %q", keys[0].String())
	}
	return &p, p.validate()
}

func (p *Policy) validate() error {
	if p.Schema != Schema {
		return fmt.Errorf("schema is %q, want %q", p.Schema, Schema)
	}
	if len(p.Mode) == 0 {
		return errors.New("no [mode.<name>] rules")
	}
	if _, ok := p.Mode[p.DefaultMode]; !ok {
		return fmt.Errorf("default_mode %q has no [mode.%s] rules", p.DefaultMode, p.DefaultMode)
	}
	for name, r := range p.Mode {
		if err := validateRules("mode."+name, name, r); err != nil {
			return err
		}
	}
	if err := p.Gateway.validate(); err != nil {
		return err
	}
	return p.validateAgents()
}

func (p *Policy) validateAgents() error {
	for agent, ar := range p.Agent {
		if !nameRe.MatchString(agent) {
			return fmt.Errorf("agent %q: not a plain name", agent)
		}
		for name, r := range ar.Mode {
			if _, ok := p.Mode[name]; !ok {
				return fmt.Errorf("agent.%s.mode.%s: no [mode.%s] to override", agent, name, name)
			}
			if err := validateRules("agent."+agent+".mode."+name, name, r); err != nil {
				return err
			}
		}
	}
	return nil
}

func validateRules(where, name string, r Rules) error {
	if !nameRe.MatchString(name) {
		return fmt.Errorf("%s: %q is not a plain name", where, name)
	}
	for key, list := range r.ruleFields() {
		for _, pat := range *list {
			if pat == "" {
				return fmt.Errorf("%s.%s: an empty pattern", where, key)
			}
		}
	}
	return nil
}

// Modes lists the modes the policy defines, sorted.
func (p *Policy) Modes() []string {
	out := make([]string, 0, len(p.Mode))
	for name := range p.Mode {
		out = append(out, name)
	}
	sort.Strings(out)
	return out
}

// RulesFor is the mode's rules with the agent's overrides applied: each
// list the agent's table sets replaces the mode's.
func (p *Policy) RulesFor(agent, mode string) (Rules, error) {
	base, ok := p.Mode[mode]
	if !ok {
		return Rules{}, fmt.Errorf("mode %q has no rules", mode)
	}
	over, ok := p.Agent[agent].Mode[mode]
	if !ok {
		return base, nil
	}
	dst, src := base.ruleFields(), over.ruleFields()
	for key, list := range src {
		if p.meta.IsDefined("agent", agent, "mode", mode, key) {
			*dst[key] = *list
		}
	}
	return base, nil
}
