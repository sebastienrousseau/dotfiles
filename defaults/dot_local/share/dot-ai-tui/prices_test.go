// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
package main

import (
	"math"
	"testing"
)

func near(t *testing.T, want, got float64, what string) {
	t.Helper()
	if math.Abs(want-got) > 1e-9 {
		t.Errorf("%s: want %.10f, got %.10f", what, want, got)
	}
}

// Claude Code's own cost-state for a one-turn claude -p on claude-haiku-5-5
// (2.1.319): totalCostUSD 0.00420683 for these tokens.
func TestClaudeCostMatchesClaudesOwnFigure(t *testing.T) {
	u := tokenUse{Input: 2, CacheWrite1h: 20454, CacheRead: 11383, Output: 4}
	usd, ok := priceUse("claude", "claude-haiku-5-5", u, 1)
	if !ok {
		t.Fatal("claude-haiku-5-5 is priced")
	}
	near(t, 0.00420683, usd, "haiku 5.5")
}

// The same for one turn of claude-sonnet-5-5 (cost-state 0.1717714): its
// cache reads are $0.10, not the $0.20 of Sonnet 5.
func TestSonnet55CostMatchesClaudesOwnFigure(t *testing.T) {
	u := tokenUse{Input: 2, CacheWrite1h: 27101, CacheRead: 11334, Output: 6223}
	usd, _ := priceUse("claude", "claude-sonnet-5-5", u, 1)
	near(t, 0.1717714, usd, "sonnet 5.5")
}

func TestClaudeCachePricesPerModel(t *testing.T) {
	cases := []struct {
		model string
		u     tokenUse
		want  float64
	}{
		// 5-minute writes are 1.25x input, 1-hour writes 2x.
		{"claude-sonnet-5-5", tokenUse{CacheWrite5m: 1e6}, 2.50},
		{"claude-sonnet-5-5", tokenUse{CacheWrite1h: 1e6}, 4.00},
		// Reads: 0.025x on Fable 5.1, 0.05x on Opus 5.5, 0.1x elsewhere.
		{"claude-fable-5-1", tokenUse{CacheRead: 1e6}, 0.25},
		{"claude-opus-5-5", tokenUse{CacheRead: 1e6}, 0.20},
		{"claude-sonnet-5-5", tokenUse{CacheRead: 1e6}, 0.10},
		{"claude-sonnet-5", tokenUse{CacheRead: 1e6}, 0.20},
		{"claude-opus-4-1", tokenUse{Input: 1e6, Output: 1e6}, 90},
		{"claude-fable-5", tokenUse{CacheRead: 1e6}, 1.00},
		{"claude-sonnet-4-6", tokenUse{Input: 1e6, Output: 1e6}, 18.00},
		// A dated id is priced as its model.
		{"claude-haiku-4-5-20251001", tokenUse{Input: 1e6, Output: 1e6}, 6.00},
	}
	for _, c := range cases {
		got, ok := priceUse("claude", c.model, c.u, 1)
		if !ok {
			t.Errorf("%s: not priced", c.model)
		}
		near(t, c.want, got, c.model)
	}
}

func TestLongPromptsAndFastModeCostMore(t *testing.T) {
	// Haiku 5.5 above 100K prompt tokens: $0.50 / $2.50.
	u := tokenUse{Input: 1000, CacheRead: 100_000, Output: 1e6}
	got, _ := priceUse("claude", "claude-haiku-5-5", u, 1)
	near(t, 1000*0.50/1e6+100_000*0.05/1e6+2.50, got, "haiku 5.5 long")
	// Exactly 100K is the short price.
	u = tokenUse{Input: 100_000}
	got, _ = priceUse("claude", "claude-haiku-5-5", u, 1)
	near(t, 0.01, got, "haiku 5.5 at 100K")
	// Fast mode doubles Opus 5.5: $8 / $40.
	got, _ = priceUse("claude", "claude-opus-5-5", tokenUse{Input: 1e6, Output: 1e6}, 2)
	near(t, 48, got, "opus 5.5 fast")
	// US-only inference: 1.1x.
	got, _ = priceUse("claude", "claude-opus-5-5", tokenUse{Input: 1e6}, 1.1)
	near(t, 4.4, got, "opus 5.5 us")
}

func TestCodexPrices(t *testing.T) {
	// gpt-5.5: $5 in, $0.50 cached, $30 out; above 272K input $10 / $1 / $45.
	got, ok := priceUse("codex", "gpt-5.5", tokenUse{Input: 100_000, CacheRead: 100_000, Output: 1e6}, 1)
	if !ok {
		t.Fatal("gpt-5.5 is priced")
	}
	near(t, 0.5+0.05+30, got, "gpt-5.5")
	got, _ = priceUse("codex", "gpt-5.5", tokenUse{Input: 1000, CacheRead: 272_000, Output: 1e6}, 1)
	near(t, 1000*10/1e6+272_000*1/1e6+45, got, "gpt-5.5 long")
	got, _ = priceUse("codex", "gpt-5.3-codex", tokenUse{Output: 1e6}, 1)
	near(t, 14, got, "gpt-5.3-codex")
}

func TestUnknownModelsAreNotPriced(t *testing.T) {
	// A Codex id is not a Claude price, and the reverse.
	for _, m := range []string{"", "claude-opus-9", "claude-opus-5-5x", "gpt-5.5", "<synthetic>"} {
		if usd, ok := priceUse("claude", m, tokenUse{Input: 1e6}, 1); ok || usd != 0 {
			t.Errorf("claude %q: want unpriced, got %v %v", m, usd, ok)
		}
	}
	for _, m := range []string{"gpt-5.5x", "gpt-9", "claude-opus-5-5"} {
		if _, ok := priceUse("codex", m, tokenUse{Input: 1}, 1); ok {
			t.Errorf("codex %q: want unpriced", m)
		}
	}
}
