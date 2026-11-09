// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// costreport.go — `dot-ai-tui cost` (dot ai cost show): what agent sessions
// cost, in all, per agent, host, day, model or session, or for one session.
//
//	dot-ai-tui cost [--by agent|host|day|model|session] [--days N] [--json]
//	dot-ai-tui cost --session ID [--days N] [--json]
//
// --json prints ai/cost-report.v1 (schemas/cli/ai-cost-report.v1.schema.json);
// --tsv prints a key<TAB>cost line per group, for dot ai status.
package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"sort"
	"strconv"
	"strings"
	"time"
)

const costReportSchema = "ai/cost-report.v1"

const costUsage = "usage: dot ai cost show [--by agent|host|day|model|session] [--session ID] [--days N] [--json]"

type costOpts struct {
	by, session string
	days        int
	json, tsv   bool
}

// costRowJSON: one group of an ai/cost-report.v1 report. InputTokens counts
// all prompt tokens: uncached, cache writes and cache reads.
type costRowJSON struct {
	Key            string  `json:"key,omitempty"`
	Sessions       int     `json:"sessions"`
	Requests       int64   `json:"requests"`
	InputTokens    int64   `json:"input_tokens"`
	CacheRead      int64   `json:"cache_read_tokens"`
	CacheWrite     int64   `json:"cache_write_tokens"`
	OutputTokens   int64   `json:"output_tokens"`
	CostUSD        float64 `json:"cost_usd"`
	UnpricedTokens int64   `json:"unpriced_tokens"`
	sessions       map[string]bool
}

type costReportJSON struct {
	Schema    string        `json:"schema"`
	Generated string        `json:"generated"`
	Host      string        `json:"host"`
	Days      int           `json:"days"`
	By        string        `json:"by"`
	Session   string        `json:"session,omitempty"`
	Agent     string        `json:"agent,omitempty"`
	Rows      []costRowJSON `json:"rows"`
	Total     costRowJSON   `json:"total"`
	Unpriced  []string      `json:"unpriced_models"`
}

// costFlags: the flags that take a value, and what each sets.
var costFlags = map[string]func(*costOpts, string) bool{
	"--by":      func(o *costOpts, v string) bool { o.by = v; return true },
	"--session": func(o *costOpts, v string) bool { o.session, o.by = v, "model"; return true },
	"--days":    setDays,
	"--since":   setDays,
}

func setDays(o *costOpts, v string) bool {
	n, err := strconv.Atoi(v)
	o.days = n
	return err == nil && n >= 1
}

func parseCostArgs(args []string) (costOpts, error) {
	o := costOpts{by: "agent", days: 30}
	bad := fmt.Errorf("%s", costUsage)
	for i := 0; i < len(args); i++ {
		switch a := args[i]; {
		case a == "--json":
			o.json = true
		case a == "--tsv":
			o.tsv = true
		case costFlags[a] != nil && i+1 < len(args):
			i++
			if !costFlags[a](&o, args[i]) {
				return o, bad
			}
		default:
			return o, bad
		}
	}
	switch o.by {
	case "agent", "host", "day", "model", "session":
		return o, nil
	}
	return o, bad
}

// runCost: the `cost` subcommand, on this user's transcripts.
func runCost(args []string, out io.Writer) error {
	host, _ := os.Hostname()
	host, _, _ = strings.Cut(host, ".")
	return costReport(defaultCostRoots(), time.Now(), time.Local, host, args, out)
}

func costReport(rt costRoots, now time.Time, loc *time.Location, host string, args []string, out io.Writer) error {
	o, err := parseCostArgs(args)
	if err != nil {
		return err
	}
	from := now.In(loc).AddDate(0, 0, 1-o.days).Format("2006-01-02")
	ix := loadCostIndex(rt, now, o.days+1, loc)
	_ = ix.save(rt.cache)
	sessions := append(ix.sessions(), runLogSessions(rt.runlog, from, loc)...)
	rep := costReportJSON{Schema: costReportSchema, Generated: now.UTC().Format(time.RFC3339),
		Host: host, Days: o.days, By: o.by, Rows: []costRowJSON{}, Unpriced: []string{}}
	if o.session != "" {
		sc, err := pickSession(sessions, o.session)
		if err != nil {
			return err
		}
		sessions, rep.Session, rep.Agent = []*sessionCost{sc}, sc.Session, sc.Agent
	}
	groupCost(&rep, sessions, from)
	if o.tsv {
		for _, r := range rep.Rows {
			fmt.Fprintf(out, "%s\t%.6f\n", oneLine(r.Key), r.CostUSD)
		}
		return nil
	}
	if o.json {
		return json.NewEncoder(out).Encode(rep)
	}
	printCost(out, rep)
	return nil
}

// pickSession: the one session whose id is id or starts with it.
func pickSession(all []*sessionCost, id string) (*sessionCost, error) {
	var hit []*sessionCost
	for _, sc := range all {
		if sc.Session == id {
			return sc, nil
		}
		if strings.HasPrefix(sc.Session, id) {
			hit = append(hit, sc)
		}
	}
	switch len(hit) {
	case 0:
		return nil, fmt.Errorf("no session %s in the transcripts read", id)
	case 1:
		return hit[0], nil
	}
	return nil, fmt.Errorf("%s matches %d sessions: give more of the id", id, len(hit))
}

// groupCost folds the rows on or after from into rep, grouped by rep.By.
func groupCost(rep *costReportJSON, sessions []*sessionCost, from string) {
	groups := map[string]*costRowJSON{}
	unpriced := map[string]bool{}
	rep.Total.sessions = map[string]bool{}
	for _, sc := range sessions {
		for _, r := range sc.Rows {
			if r.Day < from {
				continue
			}
			key := groupKey(rep, sc, r)
			g := groups[key]
			if g == nil {
				g = &costRowJSON{Key: key, sessions: map[string]bool{}}
				groups[key] = g
			}
			sid := sc.Agent + "/" + sc.Session
			g.addCost(sid, r)
			rep.Total.addCost(sid, r)
			if r.Unpriced > 0 {
				unpriced[r.Model] = true
			}
		}
	}
	for _, g := range groups {
		rep.Rows = append(rep.Rows, *g)
	}
	sortRows(rep.By, rep.Rows)
	for m := range unpriced {
		rep.Unpriced = append(rep.Unpriced, m)
	}
	sort.Strings(rep.Unpriced)
}

func groupKey(rep *costReportJSON, sc *sessionCost, r *costRow) string {
	switch rep.By {
	case "host":
		return rep.Host
	case "day":
		return r.Day
	case "model":
		return r.Model
	case "session":
		return sc.Agent + "/" + sc.Session
	}
	return sc.Agent
}

func (g *costRowJSON) addCost(sid string, r *costRow) {
	g.sessions[sid] = true
	g.Sessions = len(g.sessions)
	g.Requests += r.Requests
	g.InputTokens += r.Use.prompt()
	g.CacheRead += r.Use.CacheRead
	g.CacheWrite += r.Use.CacheWrite5m + r.Use.CacheWrite1h
	g.OutputTokens += r.Use.Output
	g.CostUSD += r.USD
	g.UnpricedTokens += r.Unpriced
}

// sortRows: days newest first, everything else costliest first.
func sortRows(by string, rows []costRowJSON) {
	sort.Slice(rows, func(i, j int) bool {
		if by == "day" {
			return rows[i].Key > rows[j].Key
		}
		if rows[i].CostUSD != rows[j].CostUSD {
			return rows[i].CostUSD > rows[j].CostUSD
		}
		return rows[i].Key < rows[j].Key
	})
}

func printCost(out io.Writer, rep costReportJSON) {
	span := fmt.Sprintf("last %d days", rep.Days)
	if rep.Days == 1 {
		span = "last 1 day"
	}
	if len(rep.Rows) == 0 {
		fmt.Fprintf(out, "No agent usage in the %s.\n", span)
		return
	}
	if rep.Session != "" {
		fmt.Fprintf(out, "Session %s (%s), %s\n\n", rep.Session, rep.Agent, span)
	}
	cols := "%-20s %8s %9s %9s %9s %11s\n"
	fmt.Fprintf(out, cols, strings.ToUpper(rep.By), "SESSIONS", "REQUESTS", "INPUT", "OUTPUT", "COST")
	for _, r := range rep.Rows {
		fmt.Fprintf(out, cols, padTo(oneLine(r.Key), 20), itoa(r.Sessions), humanTok(r.Requests),
			humanTok(r.InputTokens), humanTok(r.OutputTokens), money(r.CostUSD))
	}
	t := rep.Total
	fmt.Fprintf(out, cols, "total", itoa(t.Sessions), humanTok(t.Requests), humanTok(t.InputTokens),
		humanTok(t.OutputTokens), money(t.CostUSD))
	fmt.Fprintf(out, "\nOver the %s, at API list prices: on a subscription, what the tokens would cost, not a bill.\n", span)
	if t.UnpricedTokens > 0 {
		fmt.Fprintf(out, "%d tokens on models with no price: %s\n", t.UnpricedTokens, strings.Join(rep.Unpriced, ", "))
	}
}

func itoa(n int) string { return strconv.Itoa(n) }

func money(usd float64) string { return fmt.Sprintf("$%.2f", usd) }
