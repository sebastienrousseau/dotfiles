// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// costindex.go — what each agent session cost, read from the transcripts
// Claude Code and Codex keep (transcripts.go reads the same files for the
// cockpit) and from the gateway's usage log. Each file folds into rows of
// tokens and USD per day and model, kept in a cache
// ($XDG_CACHE_HOME/dot/ai/cost-index.json) with the offset read so far, so a
// later run reads only what was appended. Only usage is read: prompts,
// replies and tool output never are.
package main

import (
	"bytes"
	"encoding/json"
	"io/fs"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const costIndexVersion = 1

// costRow: one file's tokens and cost on one day, on one model.
type costRow struct {
	Day      string   `json:"day"`
	Model    string   `json:"model"`
	Requests int64    `json:"requests"`
	Use      tokenUse `json:"tokens"`
	USD      float64  `json:"usd"`
	Unpriced int64    `json:"unpriced"` // tokens on a model with no price
}

// lastReq: the last request counted, so a repeat of it replaces it.
type lastReq struct {
	ID       string   `json:"id"`
	Key      string   `json:"key"`
	Use      tokenUse `json:"tokens"`
	USD      float64  `json:"usd"`
	Unpriced int64    `json:"unpriced"`
}

// fileLedger: one transcript, as read so far.
type fileLedger struct {
	Agent   string              `json:"agent"`
	Session string              `json:"session"`
	Size    int64               `json:"size"`
	Offset  int64               `json:"offset"`
	Partial string              `json:"partial"` // an unterminated last line
	Last    lastReq             `json:"last"`
	Model   string              `json:"model"`  // Codex: the turn's model
	Totals  tokenUse            `json:"totals"` // Codex: cumulative tokens
	Rows    map[string]*costRow `json:"rows"`
	// Claude: each request's time, model and cost, and Claude Code's own
	// figure for its last run (claudecost.go).
	Stamps   []reqStamp       `json:"stamps,omitempty"`
	State    *claudeCostState `json:"state,omitempty"`
	LastTime string           `json:"last_time,omitempty"`
}

type costIndex struct {
	Version int                    `json:"version"`
	Files   map[string]*fileLedger `json:"files"`
	loc     *time.Location
}

// costRoots: where the transcripts, the gateway's logs (a directory), the
// cache and the run log are.
type costRoots struct{ claude, codex, gateway, cache, runlog string }

func defaultCostRoots() costRoots {
	home, _ := os.UserHomeDir()
	rt := costRoots{
		claude:  filepath.Join(envOr("CLAUDE_CONFIG_DIR", filepath.Join(home, ".claude")), "projects"),
		codex:   filepath.Join(envOr("CODEX_HOME", filepath.Join(home, ".codex")), "sessions"),
		gateway: filepath.Join(envOr("XDG_STATE_HOME", filepath.Join(home, ".local", "state")), "dot", "ai", "serve"),
		cache:   filepath.Join(envOr("XDG_CACHE_HOME", filepath.Join(home, ".cache")), "dot", "ai", "cost-index.json"),
		runlog:  dbPath(),
	}
	return rt
}

// loadCostIndex: the cache brought up to date with every transcript written
// in the last days days. A cache that does not load is rebuilt.
func loadCostIndex(rt costRoots, now time.Time, days int, loc *time.Location) *costIndex {
	ix := &costIndex{}
	if b, err := os.ReadFile(rt.cache); err != nil || json.Unmarshal(b, ix) != nil || ix.Version != costIndexVersion {
		ix = &costIndex{}
	}
	ix.Version, ix.loc = costIndexVersion, loc
	old := ix.Files
	ix.Files = map[string]*fileLedger{}
	since := now.AddDate(0, 0, -days)
	for _, c := range costCandidates(rt, since, now) {
		fl := old[c.path]
		if fl == nil || c.info.Size() < fl.Offset { // new, or rewritten
			fl = &fileLedger{Agent: c.agent, Rows: map[string]*costRow{}}
		}
		fl.Size = c.info.Size()
		ix.Files[c.path] = fl
		ix.advance(c.path, fl, c.info.ModTime())
	}
	return ix
}

// save writes the index privately and atomically; a failure only costs the
// next run a full read.
func (ix *costIndex) save(path string) error {
	b, err := json.Marshal(ix)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, b, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

// costCandidates: the files modified since since. Claude keeps a session's
// subagents in <project>/<session>/subagents/; Codex files rollouts by the
// day they started, so every day in the window is listed.
func costCandidates(rt costRoots, since, now time.Time) []candidate {
	var out []candidate
	keep := func(agent, path string, info fs.FileInfo) {
		if !info.IsDir() && strings.HasSuffix(path, ".jsonl") && !info.ModTime().Before(since) {
			out = append(out, candidate{agent, path, info})
		}
	}
	walkJSONL(rt.claude, 3, func(p string, i fs.FileInfo) { keep("claude", p, i) })
	for d := since.AddDate(0, 0, -1); !d.After(now.AddDate(0, 0, 1)); d = d.AddDate(0, 0, 1) {
		walkJSONL(filepath.Join(rt.codex, d.Format("2006/01/02")), 0, func(p string, i fs.FileInfo) { keep("codex", p, i) })
	}
	// The gateway's usage log, and the ones it set aside (usage-*.jsonl).
	walkJSONL(rt.gateway, 0, func(p string, i fs.FileInfo) {
		if strings.HasPrefix(filepath.Base(p), "usage") {
			keep("gateway", p, i)
		}
	})
	return out
}

// walkJSONL calls fn on every .jsonl file in dir, down to depth levels below.
func walkJSONL(dir string, depth int, fn func(string, fs.FileInfo)) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return
	}
	for _, e := range entries {
		p := filepath.Join(dir, e.Name())
		if e.IsDir() && depth > 0 {
			walkJSONL(p, depth-1, fn)
		} else if info, err := e.Info(); err == nil && strings.HasSuffix(e.Name(), ".jsonl") {
			fn(p, info)
		}
	}
}

// advance folds the complete lines appended since the last read.
func (ix *costIndex) advance(path string, fl *fileLedger, mod time.Time) {
	if fl.Size <= fl.Offset {
		return
	}
	f, err := os.Open(path)
	if err != nil {
		return
	}
	defer func() { _ = f.Close() }()
	buf := make([]byte, fl.Size-fl.Offset)
	n, _ := f.ReadAt(buf, fl.Offset)
	fl.Offset += int64(n)
	lines := bytes.Split(append([]byte(fl.Partial), buf[:n]...), []byte{'\n'})
	fl.Partial = string(lines[len(lines)-1])
	for _, ln := range lines[:len(lines)-1] {
		ix.apply(path, fl, ln, mod)
	}
}

func (ix *costIndex) apply(path string, fl *fileLedger, ln []byte, mod time.Time) {
	switch fl.Agent {
	case "claude":
		ix.applyClaudeCost(path, fl, ln, mod)
	case "codex":
		ix.applyCodexCost(path, fl, ln, mod)
	default:
		ix.applyGatewayCost(fl, ln, mod)
	}
}

// day: the local day of an RFC 3339 time, else of the file's mtime.
func (ix *costIndex) day(ts string, mod time.Time) string {
	t, err := time.Parse(time.RFC3339Nano, ts)
	if err != nil {
		t = mod
	}
	return t.In(ix.loc).Format("2006-01-02")
}

// count adds one request's tokens and cost to its row; a repeat of the last
// request (same id) replaces it.
func (fl *fileLedger) count(id, day, model string, u tokenUse, usd float64, priced bool) {
	if id != "" && id == fl.Last.ID {
		if r := fl.Rows[fl.Last.Key]; r != nil {
			r.Requests--
			r.Use.add(fl.Last.Use, -1)
			r.USD -= fl.Last.USD
			r.Unpriced -= fl.Last.Unpriced
		}
	}
	key := day + "|" + model
	r := fl.Rows[key]
	if r == nil {
		r = &costRow{Day: day, Model: model}
		fl.Rows[key] = r
	}
	r.Requests++
	r.Use.add(u, 1)
	var unpriced int64
	if !priced {
		unpriced = u.prompt() + u.Output
	}
	r.USD += usd
	r.Unpriced += unpriced
	fl.Last = lastReq{ID: id, Key: key, Use: u, USD: usd, Unpriced: unpriced}
}

func sessionFromPath(path string) string {
	return strings.TrimSuffix(filepath.Base(path), ".jsonl")
}
