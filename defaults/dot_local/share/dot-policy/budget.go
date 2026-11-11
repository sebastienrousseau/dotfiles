// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// BudgetRules is the policy's [budget] table (plan P1.3): what agents may
// spend, at the API list prices dot ai cost show reports. DailyUSD caps
// today's spend across every session, SessionUSD one session's; 0 is no
// cap. At 80% an agent's next prompt carries a warning, at 100% it is
// blocked.
type BudgetRules struct {
	DailyUSD   float64 `toml:"daily_usd"`
	SessionUSD float64 `toml:"session_usd"`
}

func (b BudgetRules) validate() error {
	if b.DailyUSD < 0 {
		return fmt.Errorf("budget.daily_usd: %v is below 0", b.DailyUSD)
	}
	if b.SessionUSD < 0 {
		return fmt.Errorf("budget.session_usd: %v is below 0", b.SessionUSD)
	}
	return nil
}

func (b BudgetRules) set() bool { return b.DailyUSD > 0 || b.SessionUSD > 0 }

// Spend is what dot-ai-tui cost --spend reports: today's cost across every
// session, and one session's.
type Spend struct{ Today, Session float64 }

// warnAt is the share of a budget at which a prompt carries a warning.
const warnAt = 0.8

// DecideBudget is why a prompt must be blocked, else a warning to show
// with it, else neither.
func DecideBudget(b BudgetRules, s Spend) (block, warn string) {
	caps := []struct {
		limit, spent      float64
		name, where, when string
	}{
		{b.DailyUSD, s.Today, "daily", "today", " today"},
		{b.SessionUSD, s.Session, "session", "in this session", ""},
	}
	for _, c := range caps {
		if c.limit > 0 && c.spent >= c.limit {
			return fmt.Sprintf("the %s budget of $%.2f is spent ($%.2f %s)", c.name, c.limit, c.spent, c.where), ""
		}
	}
	for _, c := range caps {
		if c.limit > 0 && c.spent >= warnAt*c.limit {
			return "", fmt.Sprintf("$%.2f of the %s budget of $%.2f is spent%s (%.0f%%)", c.spent, c.name, c.limit, c.when, 100*c.spent/c.limit)
		}
	}
	return "", ""
}

// promptEvent: a hook event that comes before the agent works on a prompt.
func promptEvent(e string) bool { return e == "UserPromptSubmit" || e == "BeforeAgent" }

// spendOf runs dot-ai-tui cost --spend for agent/session key; a seam for
// tests. dot-ai-tui is $DOT_AI_TUI_BIN, else ~/.local/bin/dot-ai-tui.
var spendOf = func(getenv func(string) string, key string) (Spend, error) {
	bin := getenv("DOT_AI_TUI_BIN")
	if bin == "" {
		bin = filepath.Join(getenv("HOME"), ".local", "bin", "dot-ai-tui")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	var out bytes.Buffer
	cmd := exec.CommandContext(ctx, bin, "cost", "--spend", key)
	cmd.Stdout = &out
	if err := cmd.Run(); err != nil {
		return Spend{}, fmt.Errorf("%s: %w", bin, err)
	}
	return parseSpend(out.String())
}

func parseSpend(text string) (Spend, error) {
	var s Spend
	seen := 0
	for _, line := range strings.Split(strings.TrimSpace(text), "\n") {
		k, v, _ := strings.Cut(line, "\t")
		f, err := strconv.ParseFloat(v, 64)
		if err != nil {
			continue
		}
		switch k {
		case "today":
			s.Today, seen = f, seen|1
		case "session":
			s.Session, seen = f, seen|2
		}
	}
	if seen != 3 {
		return s, errors.New("dot-ai-tui cost --spend gave no today and session lines")
	}
	return s, nil
}

// decidePrompt is the verdict on a prompt: blocked (with why), warned, or
// neither. Without [budget], nothing is asked; a budget whose spend cannot
// be read blocks, as a policy that cannot be checked does.
func decidePrompt(p *Policy, agent, session string, getenv func(string) string) (block, warn string) {
	if !p.Budget.set() {
		return "", ""
	}
	s, err := spendOf(getenv, agent+"/"+session)
	if err != nil {
		return fmt.Sprintf("dot ai policy: [budget] is set but the spend could not be read (%v); prompts are blocked until it can (dot ai cost show)", err), ""
	}
	block, warn = DecideBudget(p.Budget, s)
	if block != "" {
		return "dot ai policy: " + block, ""
	}
	if warn != "" {
		return "", "dot ai policy: " + warn
	}
	return "", ""
}

// writePromptDecision prints a prompt verdict as the agent reads it:
// Claude Code and Codex block with decision "block", Gemini CLI with
// "deny"; a warning is a systemMessage. Neither prints nothing, or {} for
// Gemini CLI.
func writePromptDecision(out io.Writer, agent, block, warn string) {
	v := map[string]any{}
	switch {
	case block != "" && agent == "gemini":
		v["decision"], v["reason"] = "deny", block
	case block != "":
		v["decision"], v["reason"] = "block", block
	case warn != "":
		v["systemMessage"] = warn
	case agent != "gemini":
		return
	}
	_ = json.NewEncoder(out).Encode(v)
}
