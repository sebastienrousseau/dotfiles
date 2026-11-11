// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package main

import (
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const budgetPolicy = samplePolicy + `
[budget]
daily_usd = 5
session_usd = 2
`

func TestBudgetParsesAndValidates(t *testing.T) {
	p, err := ParsePolicy(budgetPolicy)
	if err != nil {
		t.Fatal(err)
	}
	if p.Budget != (BudgetRules{DailyUSD: 5, SessionUSD: 2}) {
		t.Fatalf("budget: %+v", p.Budget)
	}
	for _, bad := range []string{"daily_usd = -1", "session_usd = -0.5"} {
		if _, err := ParsePolicy(samplePolicy + "\n[budget]\n" + bad + "\n"); err == nil || !strings.Contains(err.Error(), "budget.") {
			t.Errorf("%s: %v", bad, err)
		}
	}
}

func TestDecideBudget(t *testing.T) {
	b := BudgetRules{DailyUSD: 5, SessionUSD: 2}
	cases := []struct {
		name        string
		s           Spend
		block, warn string
	}{
		{"well under", Spend{Today: 1, Session: 0.5}, "", ""},
		{"just under 80%", Spend{Today: 3.99, Session: 1.59}, "", ""},
		{"80% of the day", Spend{Today: 4, Session: 0}, "", "$4.00 of the daily budget of $5.00 is spent today (80%)"},
		{"80% of the session", Spend{Today: 1, Session: 1.7}, "", "$1.70 of the session budget of $2.00 is spent (85%)"},
		{"the day is spent", Spend{Today: 5, Session: 1.9}, "the daily budget of $5.00 is spent ($5.00 today)", ""},
		{"the session is spent", Spend{Today: 4.5, Session: 2.3}, "the session budget of $2.00 is spent ($2.30 in this session)", ""},
	}
	for _, tc := range cases {
		block, warn := DecideBudget(b, tc.s)
		if block != tc.block || warn != tc.warn {
			t.Errorf("%s: got %q / %q", tc.name, block, warn)
		}
	}
	// A cap of 0 is no cap.
	if block, warn := DecideBudget(BudgetRules{SessionUSD: 2}, Spend{Today: 999}); block != "" || warn != "" {
		t.Errorf("no daily cap: %q / %q", block, warn)
	}
}

// promptCall is a UserPromptSubmit payload; the prompt itself is never read.
const promptCall = `{"hook_event_name":"UserPromptSubmit","session_id":"s-1","prompt":"secret plans","cwd":"/work"}`

func withSpend(t *testing.T, s Spend, err error) *[]string {
	t.Helper()
	var asked []string
	old := spendOf
	spendOf = func(_ func(string) string, key string) (Spend, error) {
		asked = append(asked, key)
		return s, err
	}
	t.Cleanup(func() { spendOf = old })
	return &asked
}

func decoded(t *testing.T, out string) map[string]string {
	t.Helper()
	v := map[string]string{}
	if err := json.Unmarshal([]byte(out), &v); err != nil {
		t.Fatalf("not JSON: %q", out)
	}
	return v
}

func TestCheckBlocksAPromptOverBudget(t *testing.T) {
	f := newFixture(t, budgetPolicy)
	asked := withSpend(t, Spend{Today: 5.12, Session: 1}, nil)
	_, out, _ := f.run(promptCall, "check", "--agent", "claude")
	v := decoded(t, out)
	if v["decision"] != "block" || v["reason"] != "dot ai policy: the daily budget of $5.00 is spent ($5.12 today)" {
		t.Fatalf("claude: %v", v)
	}
	if len(*asked) != 1 || (*asked)[0] != "claude/s-1" {
		t.Fatalf("asked for %v", *asked)
	}
	_, out, _ = f.run(strings.Replace(promptCall, "UserPromptSubmit", "BeforeAgent", 1), "check", "--agent", "gemini")
	if v := decoded(t, out); v["decision"] != "deny" || !strings.Contains(v["reason"], "daily budget") {
		t.Fatalf("gemini: %v", v)
	}
	_, out, _ = f.run(promptCall, "check", "--agent", "codex")
	if v := decoded(t, out); v["decision"] != "block" {
		t.Fatalf("codex: %v", v)
	}
}

func TestCheckWarnsAPromptNearTheBudget(t *testing.T) {
	f := newFixture(t, budgetPolicy)
	withSpend(t, Spend{Today: 4.1, Session: 0}, nil)
	_, out, _ := f.run(promptCall, "check", "--agent", "claude")
	v := decoded(t, out)
	if v["systemMessage"] != "dot ai policy: $4.10 of the daily budget of $5.00 is spent today (82%)" || v["decision"] != "" {
		t.Fatalf("claude: %v", v)
	}
}

func TestCheckLetsAPromptThroughUnderBudgetOrWithoutOne(t *testing.T) {
	withSpend(t, Spend{Today: 1}, nil)
	for _, policy := range []string{budgetPolicy, samplePolicy} {
		f := newFixture(t, policy)
		if _, out, _ := f.run(promptCall, "check", "--agent", "claude"); out != "" {
			t.Errorf("claude: %q", out)
		}
		if _, out, _ := f.run(promptCall, "check", "--agent", "gemini"); strings.TrimSpace(out) != "{}" {
			t.Errorf("gemini: %q", out)
		}
	}
	// No policy file at all: nothing is enforced.
	if _, out, _ := newFixture(t, "").run(promptCall, "check", "--agent", "gemini"); strings.TrimSpace(out) != "{}" {
		t.Errorf("no policy: %q", out)
	}
	// No [budget]: the spend is never asked for.
	asked := withSpend(t, Spend{}, errors.New("never"))
	f := newFixture(t, samplePolicy)
	if _, out, _ := f.run(promptCall, "check"); out != "" || len(*asked) != 0 {
		t.Errorf("no budget: %q %v", out, *asked)
	}
}

func TestCheckBlocksAPromptWhenTheSpendCannotBeRead(t *testing.T) {
	f := newFixture(t, budgetPolicy)
	withSpend(t, Spend{}, errors.New("dot-ai-tui is not installed"))
	_, out, _ := f.run(promptCall, "check", "--agent", "claude")
	v := decoded(t, out)
	if v["decision"] != "block" || !strings.Contains(v["reason"], "dot-ai-tui is not installed") {
		t.Fatalf("%v", v)
	}
	// An invalid policy blocks a prompt as it denies a tool call.
	f = newFixture(t, "schema = 1")
	if v := decoded(t, mustOut(f.run(promptCall, "check"))); v["decision"] != "block" || !strings.Contains(v["reason"], "invalid") {
		t.Fatalf("invalid policy: %v", v)
	}
}

func TestAToolCallStillGoesByTheToolRules(t *testing.T) {
	f := newFixture(t, budgetPolicy)
	asked := withSpend(t, Spend{Today: 99}, nil)
	_, out, _ := f.run(writeCall, "check", "--mode", "ask")
	if !strings.Contains(reasonOf(t, out), "(mode ask)") || len(*asked) != 0 {
		t.Fatalf("%q %v", out, *asked)
	}
}

func TestShowPrintsTheBudget(t *testing.T) {
	f := newFixture(t, budgetPolicy)
	_, out, _ := f.run("", "show")
	for _, want := range []string{"budget.daily_usd $5.00", "budget.session_usd $2.00"} {
		if !strings.Contains(out, want) {
			t.Errorf("missing %q in\n%s", want, out)
		}
	}
}

func TestSpendOfRunsTheCostReport(t *testing.T) {
	f := newFixture(t, "")
	bin := f.write("bin/dot-ai-tui", "#!/bin/sh\nprintf '%s\\n' \"$*\" >\"$0.args\"\nprintf 'today\\t4.5\\nsession\\t1.25\\n'\n")
	if err := os.Chmod(bin, 0o755); err != nil {
		t.Fatal(err)
	}
	f.env["DOT_AI_TUI_BIN"] = bin
	s, err := spendOf(func(k string) string { return f.env[k] }, "claude/s-1")
	if err != nil || s != (Spend{Today: 4.5, Session: 1.25}) {
		t.Fatalf("%+v %v", s, err)
	}
	if args, _ := os.ReadFile(bin + ".args"); string(args) != "cost --spend claude/s-1\n" {
		t.Fatalf("args: %q", args)
	}
	// Without DOT_AI_TUI_BIN: ~/.local/bin/dot-ai-tui, here missing.
	delete(f.env, "DOT_AI_TUI_BIN")
	if _, err := spendOf(func(k string) string { return f.env[k] }, "claude/s-1"); err == nil ||
		!strings.Contains(err.Error(), filepath.Join(f.home, ".local", "bin", "dot-ai-tui")) {
		t.Fatalf("missing binary: %v", err)
	}
}

func TestParseSpendNeedsBothLines(t *testing.T) {
	if s, err := parseSpend("today\t1\nsession\t2\n"); err != nil || s != (Spend{1, 2}) {
		t.Fatalf("%+v %v", s, err)
	}
	for _, bad := range []string{"", "today\t1\n", "session\t2\n", "today\tx\nsession\t2\n"} {
		if _, err := parseSpend(bad); err == nil {
			t.Errorf("%q: want an error", bad)
		}
	}
}
