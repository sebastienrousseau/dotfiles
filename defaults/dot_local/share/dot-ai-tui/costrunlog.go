// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// costrunlog.go — runs of other delegates (the /vibe skill's Mistral Vibe,
// say) from the run log, dotfiles-ai.db, with the cost each logged. Claude
// and Codex runs there are left out: their transcripts are read instead.
package main

import (
	"regexp"
	"strconv"
	"strings"
	"time"
)

var plainAgent = regexp.MustCompile(`^[a-z][a-z0-9-]{0,31}$`)

// runLogSessions: each run on or after from (a local date) as a session of
// its own, read with the sqlite3 CLI; none when the log or sqlite3 is
// missing.
func runLogSessions(db, from string, loc *time.Location) []*sessionCost {
	if loc == nil {
		loc = time.Local
	}
	// from is our own YYYY-MM-DD; a day early covers the time zones.
	start, err := time.ParseInLocation("2006-01-02", from, loc)
	if err != nil {
		return nil
	}
	q := "SELECT id, ts, delegate, model, tokens_in, tokens_out, cost_usd FROM runs WHERE ts >= '" +
		start.AddDate(0, 0, -1).UTC().Format("2006-01-02") + "' AND delegate NOT IN ('claude', 'codex');"
	var out []*sessionCost
	for _, ln := range strings.Split(sqlite(db, q), "\n") {
		if sc := runLogSession(ln, from, loc); sc != nil {
			out = append(out, sc)
		}
	}
	return out
}

// runLogSession: one "id|ts|delegate|model|in|out|cost" row, or nil.
func runLogSession(ln, from string, loc *time.Location) *sessionCost {
	f := strings.Split(ln, "|")
	if len(f) != 7 || !plainAgent.MatchString(f[2]) {
		return nil
	}
	t, err := time.Parse(time.RFC3339, f[1])
	if err != nil {
		return nil
	}
	day := t.In(loc).Format("2006-01-02")
	if day < from {
		return nil
	}
	in, _ := strconv.ParseInt(f[4], 10, 64)
	out, _ := strconv.ParseInt(f[5], 10, 64)
	usd, _ := strconv.ParseFloat(f[6], 64)
	r := &costRow{Day: day, Model: f[3], Requests: 1, Use: tokenUse{Input: in, Output: out}, USD: usd}
	return &sessionCost{Agent: f[2], Session: "run-" + f[0], Rows: map[string]*costRow{day + "|" + f[3]: r}}
}
