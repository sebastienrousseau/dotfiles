// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// prices.go — list prices, per million tokens in USD, for the models whose
// transcripts dot ai cost reads. A cost is what the tokens would cost at
// these prices: on a subscription it is the API equivalent, not a bill.
//
// Claude: the Claude API's first-party rates
// (platform.claude.com/docs/en/about-claude/pricing, read 2026-11-09). A
// 5-minute cache write is 1.25x input and a 1-hour one 2x; a cache read is
// the model's own read price. Fast mode doubles a price, and US-only
// inference adds 10%. Checked against Claude Code's own cost-state: see
// prices_test.go.
// Codex: OpenAI's Standard tier, short context
// (developers.openai.com/api/docs/pricing, read 2026-11-09).
package main

import (
	"regexp"
	"strings"
)

// price is one model's rates; a long rate applies when a request's prompt
// (input, cache writes and cache reads) is over longFrom tokens.
type price struct {
	in, out, read          float64
	longFrom               int64
	longIn, longOut, lRead float64
}

var claudePrices = map[string]price{
	"claude-fable-5-1":  {in: 10, out: 50, read: 0.25},
	"claude-mythos-5-1": {in: 10, out: 50, read: 0.25},
	"claude-fable-5":    {in: 10, out: 50, read: 1},
	"claude-mythos-5":   {in: 10, out: 50, read: 1},
	"claude-opus-5-5":   {in: 4, out: 20, read: 0.20},
	"claude-opus-5":     {in: 5, out: 25, read: 0.50},
	"claude-opus-4-8":   {in: 5, out: 25, read: 0.50},
	"claude-opus-4-7":   {in: 5, out: 25, read: 0.50},
	"claude-opus-4-6":   {in: 5, out: 25, read: 0.50},
	"claude-opus-4-5":   {in: 5, out: 25, read: 0.50},
	"claude-opus-4-1":   {in: 15, out: 75, read: 1.50},
	"claude-opus-4":     {in: 15, out: 75, read: 1.50},
	"claude-sonnet-5-5": {in: 2, out: 10, read: 0.10},
	"claude-sonnet-5":   {in: 2, out: 10, read: 0.20},
	"claude-sonnet-4-6": {in: 3, out: 15, read: 0.30},
	"claude-sonnet-4-5": {in: 3, out: 15, read: 0.30},
	"claude-sonnet-4":   {in: 3, out: 15, read: 0.30},
	"claude-haiku-5-5": {in: 0.10, out: 0.50, read: 0.01,
		longFrom: 100_000, longIn: 0.50, longOut: 2.50, lRead: 0.05},
	"claude-haiku-4-5": {in: 1, out: 5, read: 0.10},
}

var codexPrices = map[string]price{
	"gpt-5.5": {in: 5, out: 30, read: 0.50,
		longFrom: 272_000, longIn: 10, longOut: 45, lRead: 1},
	"gpt-5.6-sol":   {in: 4, out: 20, read: 0.40},
	"gpt-5.6-terra": {in: 2, out: 12, read: 0.20},
	"gpt-5.6-luna":  {in: 0.20, out: 1.20, read: 0.02},
	"gpt-5.4":       {in: 2.50, out: 15, read: 0.25},
	"gpt-5.4-mini":  {in: 0.75, out: 4.50, read: 0.075},
	"gpt-5.4-nano":  {in: 0.20, out: 1.25, read: 0.02},
	"gpt-5.3-codex": {in: 1.75, out: 14, read: 0.175},
	"gpt-5.2":       {in: 1.75, out: 14, read: 0.175},
	"gpt-5.1":       {in: 1.25, out: 10, read: 0.125},
	"gpt-5":         {in: 1.25, out: 10, read: 0.125},
	"gpt-5-mini":    {in: 0.25, out: 2, read: 0.025},
	"gpt-5-nano":    {in: 0.05, out: 0.40, read: 0.005},
}

// tokenUse is the tokens of one request, or a sum of them. Input is the
// uncached input; cached input is CacheRead.
type tokenUse struct {
	Input        int64 `json:"input"`
	CacheWrite5m int64 `json:"cache_write_5m"`
	CacheWrite1h int64 `json:"cache_write_1h"`
	CacheRead    int64 `json:"cache_read"`
	Output       int64 `json:"output"`
}

func (u tokenUse) prompt() int64 { return u.Input + u.CacheWrite5m + u.CacheWrite1h + u.CacheRead }

func (u *tokenUse) add(v tokenUse, sign int64) {
	u.Input += sign * v.Input
	u.CacheWrite5m += sign * v.CacheWrite5m
	u.CacheWrite1h += sign * v.CacheWrite1h
	u.CacheRead += sign * v.CacheRead
	u.Output += sign * v.Output
}

// datedID ends in a release date (claude-haiku-4-5-20251001).
var datedID = regexp.MustCompile(`-20[0-9]{6}$`)

// priceUse: the USD cost of one request's tokens on model, and whether the
// model has a price. agent picks the table (claude or codex); mult is the
// request's surcharge (fast mode, US-only inference), 1 for none.
func priceUse(agent, model string, u tokenUse, mult float64) (float64, bool) {
	table := claudePrices
	if agent == "codex" {
		table = codexPrices
	}
	p, ok := table[datedID.ReplaceAllString(strings.TrimSpace(model), "")]
	if !ok {
		return 0, false
	}
	in, out, read := p.in, p.out, p.read
	if p.longFrom > 0 && u.prompt() > p.longFrom {
		in, out, read = p.longIn, p.longOut, p.lRead
	}
	usd := (float64(u.Input)*in + float64(u.CacheWrite5m)*in*1.25 +
		float64(u.CacheWrite1h)*in*2 + float64(u.CacheRead)*read + float64(u.Output)*out) / 1e6
	return usd * mult, true
}
