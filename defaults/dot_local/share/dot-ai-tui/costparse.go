// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// costparse.go — the usage in one line of a Claude Code transcript, a Codex
// rollout or the gateway's usage log. Lines without usage are skipped
// before they are decoded.
package main

import (
	"bytes"
	"encoding/json"
	"time"
)

var (
	markUsage      = []byte(`"usage"`)
	markTokenCount = []byte(`"token_count"`)
	markTurn       = []byte(`"turn_context"`)
	markMeta       = []byte(`"session_meta"`)
	markCostState  = []byte(`"type":"cost-state"`)
)

type claudeUsageEntry struct {
	Input      int64 `json:"input_tokens"`
	CacheWrite int64 `json:"cache_creation_input_tokens"`
	CacheRead  int64 `json:"cache_read_input_tokens"`
	Output     int64 `json:"output_tokens"`
	Creation   *struct {
		W5m int64 `json:"ephemeral_5m_input_tokens"`
		W1h int64 `json:"ephemeral_1h_input_tokens"`
	} `json:"cache_creation"`
	Speed string `json:"speed"`
	Geo   string `json:"inference_geo"`
}

type claudeCostEntry struct {
	Type      string `json:"type"`
	SessionID string `json:"sessionId"`
	Timestamp string `json:"timestamp"`
	Message   *struct {
		ID    string            `json:"id"`
		Model string            `json:"model"`
		Usage *claudeUsageEntry `json:"usage"`
	} `json:"message"`
}

// applyClaudeCost counts an assistant message's usage. Claude Code logs one
// API message once per content block, repeating its usage: the id says so.
func (ix *costIndex) applyClaudeCost(path string, fl *fileLedger, ln []byte, mod time.Time) {
	if bytes.Contains(ln, markCostState) {
		ix.applyCostState(fl, ln, mod)
		return
	}
	var e claudeCostEntry
	if !bytes.Contains(ln, markUsage) || json.Unmarshal(ln, &e) != nil || !e.billed() {
		return
	}
	fl.claimSession(e.SessionID, path)
	m := e.Message
	u := m.Usage.tokens()
	usd, ok := priceUse("claude", m.Model, u, surcharge(m.Usage.Speed, m.Usage.Geo))
	repeat := m.ID != "" && m.ID == fl.Last.ID
	fl.count(m.ID, ix.day(e.Timestamp, mod), m.Model, u, usd, ok)
	fl.stamp(repeat, e.Timestamp, m.Model, usd)
}

// billed: an assistant message with usage, from a real model.
func (e *claudeCostEntry) billed() bool {
	m := e.Message
	return e.Type == "assistant" && m != nil && m.Usage != nil && m.Model != "" && m.Model != "<synthetic>"
}

// tokens: the usage as tokenUse, the cache writes split by lifetime when the
// split adds up.
func (us *claudeUsageEntry) tokens() tokenUse {
	u := tokenUse{Input: us.Input, CacheWrite5m: us.CacheWrite, CacheRead: us.CacheRead, Output: us.Output}
	if c := us.Creation; c != nil && c.W5m+c.W1h == us.CacheWrite {
		u.CacheWrite5m, u.CacheWrite1h = c.W5m, c.W1h
	}
	return u
}

// claimSession: the file's session is the first id it names, else its name.
func (fl *fileLedger) claimSession(id, path string) {
	if fl.Session != "" {
		return
	}
	fl.Session = id
	if fl.Session == "" {
		fl.Session = sessionFromPath(path)
	}
}

// surcharge: fast mode doubles a price; US-only inference adds 10%.
func surcharge(speed, geo string) float64 {
	m := 1.0
	if speed == "fast" {
		m = 2
	}
	if geo == "us" {
		m *= 1.1
	}
	return m
}

type codexCostEntry struct {
	Timestamp string `json:"timestamp"`
	Type      string `json:"type"`
	Payload   struct {
		Type  string `json:"type"`
		ID    string `json:"id"`
		Model string `json:"model"`
		Info  *struct {
			Total struct {
				Input  int64 `json:"input_tokens"`
				Cached int64 `json:"cached_input_tokens"`
				Output int64 `json:"output_tokens"`
			} `json:"total_token_usage"`
		} `json:"info"`
	} `json:"payload"`
}

// codexMarks: the only rollout lines worth decoding.
var codexMarks = [][]byte{markTokenCount, markTurn, markMeta}

// applyCodexCost: Codex reports cumulative totals, so a request is what
// they grew by; the same totals again are no request.
func (ix *costIndex) applyCodexCost(path string, fl *fileLedger, ln []byte, mod time.Time) {
	var e codexCostEntry
	if !containsAny(ln, codexMarks) || json.Unmarshal(ln, &e) != nil {
		return
	}
	p := &e.Payload
	switch {
	case e.Type == "session_meta":
		setIf(&fl.Session, p.ID)
	case e.Type == "turn_context":
		setIf(&fl.Model, p.Model)
	case e.Type == "event_msg" && p.Type == "token_count" && p.Info != nil:
		t := p.Info.Total
		d := fl.codexGrowth(tokenUse{Input: t.Input - t.Cached, CacheRead: t.Cached, Output: t.Output})
		if d == (tokenUse{}) {
			return
		}
		fl.claimSession("", path)
		usd, ok := priceUse("codex", fl.Model, d, 1)
		fl.count("", ix.day(e.Timestamp, mod), fl.Model, d, usd, ok)
	}
}

// codexGrowth: what the totals grew by since the last; all of them when
// they restarted.
func (fl *fileLedger) codexGrowth(total tokenUse) tokenUse {
	d := total
	d.add(fl.Totals, -1)
	if d.Input < 0 || d.CacheRead < 0 || d.Output < 0 {
		d = total
	}
	fl.Totals = total
	return d
}

func containsAny(ln []byte, marks [][]byte) bool {
	for _, m := range marks {
		if bytes.Contains(ln, m) {
			return true
		}
	}
	return false
}

// gatewayUse: one line of the gateway's usage log (dot-ai-serve). cost_usd
// is Claude Code's own figure for the request when it reported one.
type gatewayUse struct {
	Time    string   `json:"time"`
	Model   string   `json:"model"`
	Tokens  tokenUse `json:"tokens"`
	CostUSD *float64 `json:"cost_usd"`
}

func (ix *costIndex) applyGatewayCost(fl *fileLedger, ln []byte, mod time.Time) {
	var g gatewayUse
	if json.Unmarshal(ln, &g) != nil || g.Model == "" {
		return
	}
	fl.Session = "gateway"
	usd, ok := priceUse("claude", g.Model, g.Tokens, 1)
	if g.CostUSD != nil {
		usd, ok = *g.CostUSD, true
	}
	fl.count("", ix.day(g.Time, mod), g.Model, g.Tokens, usd, ok)
}
