// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// claudecost.go — Claude Code's own cost figure. A transcript does not log
// every request a session makes, so pricing it alone can undercount: on one
// long multi-agent session it found $232 of the $374 Claude Code reported.
// Claude Code writes a cost-state entry with what its current run (since it
// started or resumed the session) cost per model. Where that is more than
// the session's transcripts show for the same run, the difference is
// counted as well, on the day of the cost-state, with no requests or tokens.
package main

import (
	"encoding/json"
	"sort"
	"time"
)

// reqStamp: one Claude request's time (Unix seconds), model and cost.
type reqStamp struct {
	T     int64   `json:"t"`
	Model string  `json:"m"`
	USD   float64 `json:"usd"`
}

// claudeCostState: the last cost-state of a transcript.
type claudeCostState struct {
	Start  int64              `json:"start"` // Unix seconds the run began
	Day    string             `json:"day"`
	Models map[string]float64 `json:"models"`
}

// stamp records a request's time and cost; a repeat replaces the last one.
func (fl *fileLedger) stamp(repeat bool, ts, model string, usd float64) {
	t, err := time.Parse(time.RFC3339Nano, ts)
	if err != nil {
		return
	}
	fl.LastTime = ts
	s := reqStamp{T: t.Unix(), Model: model, USD: usd}
	if repeat && len(fl.Stamps) > 0 {
		fl.Stamps[len(fl.Stamps)-1] = s
		return
	}
	fl.Stamps = append(fl.Stamps, s)
}

func (ix *costIndex) applyCostState(fl *fileLedger, ln []byte, mod time.Time) {
	var e struct {
		Type       string `json:"type"`
		StartTime  int64  `json:"startTime"`
		ModelUsage map[string]struct {
			CostUSD float64 `json:"costUSD"`
		} `json:"modelUsage"`
	}
	if json.Unmarshal(ln, &e) != nil || e.Type != "cost-state" || e.StartTime <= 0 {
		return
	}
	st := &claudeCostState{Start: e.StartTime / 1000, Day: ix.day(fl.LastTime, mod), Models: map[string]float64{}}
	for m, u := range e.ModelUsage {
		st.Models[m] = u.CostUSD
	}
	fl.State = st
}

// sessionCost: one session's ledger rows, merged across its files.
type sessionCost struct {
	Agent, Session string
	Rows           map[string]*costRow
}

// sessions merges the files of each session (a Claude session's subagents
// are files of their own) and adds what Claude Code reported beyond them.
func (ix *costIndex) sessions() []*sessionCost {
	by := map[string]*sessionCost{}
	var stamps = map[string][]reqStamp{}
	var states = map[string][]*claudeCostState{}
	for _, fl := range ix.Files {
		if fl.Session == "" {
			continue
		}
		k := fl.Agent + "/" + fl.Session
		sc := by[k]
		if sc == nil {
			sc = &sessionCost{Agent: fl.Agent, Session: fl.Session, Rows: map[string]*costRow{}}
			by[k] = sc
		}
		for key, r := range fl.Rows {
			sc.addRow(key, r)
		}
		stamps[k] = append(stamps[k], fl.Stamps...)
		if fl.State != nil {
			states[k] = append(states[k], fl.State)
		}
	}
	out := make([]*sessionCost, 0, len(by))
	for k, sc := range by {
		for _, st := range states[k] {
			sc.addUnlogged(st, stamps[k])
		}
		out = append(out, sc)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Agent+out[i].Session < out[j].Agent+out[j].Session })
	return out
}

func (sc *sessionCost) addRow(key string, r *costRow) {
	t := sc.Rows[key]
	if t == nil {
		t = &costRow{Day: r.Day, Model: r.Model}
		sc.Rows[key] = t
	}
	t.Requests += r.Requests
	t.Use.add(r.Use, 1)
	t.USD += r.USD
	t.Unpriced += r.Unpriced
}

// addUnlogged counts, per model, what a run's cost-state reports beyond the
// requests the transcripts logged since the run began.
func (sc *sessionCost) addUnlogged(st *claudeCostState, stamps []reqStamp) {
	logged := map[string]float64{}
	for _, s := range stamps {
		if s.T >= st.Start {
			logged[s.Model] += s.USD
		}
	}
	for m, reported := range st.Models {
		if extra := reported - logged[m]; extra > 1e-6 {
			sc.addRow(st.Day+"|"+m, &costRow{Day: st.Day, Model: m, USD: extra})
		}
	}
}
