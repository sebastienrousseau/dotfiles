// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// transcripts.go — reads the session transcripts Claude Code and Codex write
// to disk (~/.claude/projects/<cwd>/<id>.jsonl and
// ~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl) and folds each into one row:
// project, branch, model, what the agent is doing, token use and context fill.
// Only metadata is kept; prompts, replies and tool output are never stored.
// Files are tailed, so a scan reads only what was appended since the last one.
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/charmbracelet/x/ansi"
)

const (
	sessionWindow   = 24 * time.Hour  // transcripts untouched for longer are not listed
	sessionLiveFor  = 5 * time.Minute // written this recently → shown as live
	sessionMaxRows  = 40
	sessionTickRate = 2 * time.Second
	sessionRelist   = 10 * time.Second // between full directory listings, only tracked files are re-stat'ed

	stateWorking = "working" // the model is generating
	stateTool    = "tool"    // a tool call is out: running, or waiting for approval
	stateIdle    = "idle"    // the turn ended; waiting for the user
)

// sessionTailCap bounds the first read of a transcript (Codex rollouts reach
// hundreds of MB). A var so tests can shrink it.
var sessionTailCap int64 = 4 << 20

// AgentSession is one Claude Code or Codex session as read from its transcript.
type AgentSession struct {
	Agent, ID, Path    string
	CWD, Branch, Model string
	Title, State, Tool string
	Last               time.Time // transcript mtime
	InTok, CacheTok    int64     // uncached input (incl. cache writes); cache reads
	OutTok             int64
	CtxTok, CtxWin     int64 // latest prompt size; context window when the agent reports it
	Partial            bool  // Claude only: the file was tail-read, so totals undercount
}

type tailedFile struct {
	offset    int64
	partial   []byte // trailing bytes of an unterminated line
	lastMsg   string // Claude logs one API message per content block, repeating its usage
	lastUsage claudeUsage
	s         AgentSession
}

type sessionScanner struct {
	mu                    sync.Mutex
	claudeRoot, codexRoot string
	now                   func() time.Time
	files                 map[string]*tailedFile
	listed                time.Time
}

func newSessionScanner() *sessionScanner {
	home, _ := os.UserHomeDir()
	claude := os.Getenv("CLAUDE_CONFIG_DIR")
	if claude == "" {
		claude = filepath.Join(home, ".claude")
	}
	codex := os.Getenv("CODEX_HOME")
	if codex == "" {
		codex = filepath.Join(home, ".codex")
	}
	return &sessionScanner{
		claudeRoot: filepath.Join(claude, "projects"),
		codexRoot:  filepath.Join(codex, "sessions"),
		now:        time.Now,
		files:      map[string]*tailedFile{},
	}
}

// Scan returns the sessions written within sessionWindow, most recent first.
func (sc *sessionScanner) Scan() []AgentSession {
	sc.mu.Lock()
	defer sc.mu.Unlock()
	now := sc.now()
	cands := sc.restat(now)
	if now.Sub(sc.listed) >= sessionRelist {
		cands, sc.listed = sc.candidates(now), now
	}
	seen := map[string]bool{}
	var out []AgentSession
	for _, c := range cands {
		seen[c.path] = true
		tf := sc.files[c.path]
		if tf == nil || c.info.Size() < tf.offset { // new, or truncated and rewritten
			tf = &tailedFile{s: AgentSession{Agent: c.agent, Path: c.path, ID: strings.TrimSuffix(filepath.Base(c.path), ".jsonl")}}
			sc.files[c.path] = tf
		}
		tf.s.Last = c.info.ModTime()
		tf.advance(c.path, c.info.Size())
		out = append(out, tf.s)
	}
	for p := range sc.files {
		if !seen[p] {
			delete(sc.files, p)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Last.After(out[j].Last) })
	return out[:min(len(out), sessionMaxRows)]
}

type candidate struct {
	agent, path string
	info        fs.FileInfo
}

// restat re-checks only the files already tracked; listing every Claude
// project directory costs tens of milliseconds.
func (sc *sessionScanner) restat(now time.Time) []candidate {
	var out []candidate
	for p, tf := range sc.files {
		if info, err := os.Stat(p); err == nil && now.Sub(info.ModTime()) <= sessionWindow {
			out = append(out, candidate{tf.s.Agent, p, info})
		}
	}
	return out
}

func (sc *sessionScanner) candidates(now time.Time) []candidate {
	var out []candidate
	// Subagent transcripts sit a level deeper (<id>/subagents/) and are not read.
	projects, _ := os.ReadDir(sc.claudeRoot)
	for _, p := range projects {
		if p.IsDir() {
			out = appendRecent(out, "claude", filepath.Join(sc.claudeRoot, p.Name()), now)
		}
	}
	// Codex files rollouts by start date, so a session started before
	// yesterday is missed even if it is still being written.
	for _, day := range []time.Time{now, now.AddDate(0, 0, -1)} {
		out = appendRecent(out, "codex", filepath.Join(sc.codexRoot, day.Format("2006/01/02")), now)
	}
	return out
}

func appendRecent(out []candidate, agent, dir string, now time.Time) []candidate {
	entries, _ := os.ReadDir(dir)
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".jsonl") {
			continue
		}
		info, err := e.Info()
		if err != nil || now.Sub(info.ModTime()) > sessionWindow {
			continue
		}
		out = append(out, candidate{agent, filepath.Join(dir, e.Name()), info})
	}
	return out
}

// advance parses the complete lines between the last offset and size.
func (tf *tailedFile) advance(path string, size int64) {
	if size <= tf.offset {
		return
	}
	f, err := os.Open(path)
	if err != nil {
		return
	}
	defer func() { _ = f.Close() }()
	if size-tf.offset > sessionTailCap {
		if tf.offset == 0 && tf.s.Agent == "codex" {
			tf.apply(firstLine(f)) // session_meta: id, cwd, branch
		}
		// The read may start mid-line; that fragment fails to parse and is dropped.
		tf.offset, tf.partial = size-sessionTailCap, nil
		tf.s.Partial = tf.s.Agent == "claude" // Codex token totals are cumulative
	}
	buf := make([]byte, size-tf.offset)
	n, _ := f.ReadAt(buf, tf.offset)
	tf.offset += int64(n)
	lines := bytes.Split(append(tf.partial, buf[:n]...), []byte{'\n'})
	tf.partial = bytes.Clone(lines[len(lines)-1])
	for _, ln := range lines[:len(lines)-1] {
		tf.apply(ln)
	}
}

func firstLine(f *os.File) []byte {
	buf := make([]byte, min(sessionTailCap, 1<<20))
	n, _ := f.ReadAt(buf, 0)
	line, _, _ := bytes.Cut(buf[:n], []byte{'\n'})
	return line
}

func (tf *tailedFile) apply(ln []byte) {
	if len(bytes.TrimSpace(ln)) == 0 {
		return
	}
	if tf.s.Agent == "codex" {
		tf.applyCodex(ln)
		return
	}
	tf.applyClaude(ln)
}

func setIf(dst *string, v string) {
	if v != "" {
		*dst = v
	}
}

// ── Claude Code ─────────────────────────────────────────────────────────────

type claudeUsage struct {
	Input      int64 `json:"input_tokens"`
	CacheWrite int64 `json:"cache_creation_input_tokens"`
	CacheRead  int64 `json:"cache_read_input_tokens"`
	Output     int64 `json:"output_tokens"`
}

type claudeMessage struct {
	ID         string          `json:"id"`
	Model      string          `json:"model"`
	StopReason string          `json:"stop_reason"`
	Usage      *claudeUsage    `json:"usage"`
	Content    json.RawMessage `json:"content"`
}

type claudeEntry struct {
	Type      string         `json:"type"`
	Subtype   string         `json:"subtype"`
	CWD       string         `json:"cwd"`
	GitBranch string         `json:"gitBranch"`
	Sidechain bool           `json:"isSidechain"`
	AITitle   string         `json:"aiTitle"`
	Message   *claudeMessage `json:"message"`
}

type contentBlock struct {
	Type string `json:"type"`
	Name string `json:"name"`
	Text string `json:"text"`
}

func (tf *tailedFile) applyClaude(ln []byte) {
	var e claudeEntry
	if json.Unmarshal(ln, &e) != nil || e.Sidechain {
		return
	}
	s := &tf.s
	setIf(&s.CWD, e.CWD)
	setIf(&s.Branch, e.GitBranch)
	setIf(&s.Title, e.AITitle)
	switch {
	case e.Type == "user" && e.Message != nil:
		s.State, s.Tool = claudeUserState(e.Message.Content), ""
	case e.Type == "assistant" && e.Message != nil:
		tf.claudeAssistant(e.Message)
	case e.Type == "system" && e.Subtype == "turn_duration":
		s.State, s.Tool = stateIdle, ""
	}
}

// claudeUserState: a prompt or tool result starts model work; an interrupt ends it.
func claudeUserState(content json.RawMessage) string {
	var blocks []contentBlock
	if json.Unmarshal(content, &blocks) == nil {
		for _, b := range blocks {
			if b.Type == "text" && strings.HasPrefix(b.Text, "[Request interrupted") {
				return stateIdle
			}
		}
	}
	return stateWorking
}

func (tf *tailedFile) claudeAssistant(m *claudeMessage) {
	s := &tf.s
	if m.Model != "" && m.Model != "<synthetic>" {
		s.Model = m.Model
	}
	if m.Usage != nil {
		if m.ID == tf.lastMsg { // same message again: replace its earlier count
			tf.addUsage(tf.lastUsage, -1)
		}
		tf.lastMsg, tf.lastUsage = m.ID, *m.Usage
		tf.addUsage(*m.Usage, 1)
		s.CtxTok = m.Usage.Input + m.Usage.CacheWrite + m.Usage.CacheRead
	}
	var blocks []contentBlock
	_ = json.Unmarshal(m.Content, &blocks)
	for _, b := range blocks {
		if b.Type == "tool_use" {
			s.State, s.Tool = stateTool, b.Name
			return
		}
	}
	switch m.StopReason {
	case "end_turn", "stop_sequence", "max_tokens", "refusal":
		s.State, s.Tool = stateIdle, ""
	default:
		s.State = stateWorking
	}
}

func (tf *tailedFile) addUsage(u claudeUsage, sign int64) {
	tf.s.InTok += sign * (u.Input + u.CacheWrite)
	tf.s.CacheTok += sign * u.CacheRead
	tf.s.OutTok += sign * u.Output
}

// ── Codex ───────────────────────────────────────────────────────────────────

type codexUsage struct {
	Input  int64 `json:"input_tokens"`
	Cached int64 `json:"cached_input_tokens"`
	Output int64 `json:"output_tokens"`
	Total  int64 `json:"total_tokens"`
}

type codexPayload struct {
	Type  string `json:"type"`
	ID    string `json:"id"`
	CWD   string `json:"cwd"`
	Model string `json:"model"`
	Name  string `json:"name"`
	Git   *struct {
		Branch string `json:"branch"`
	} `json:"git"`
	Info *struct {
		Total  codexUsage `json:"total_token_usage"`
		Last   codexUsage `json:"last_token_usage"`
		Window int64      `json:"model_context_window"`
	} `json:"info"`
}

type codexEntry struct {
	Type    string       `json:"type"`
	Payload codexPayload `json:"payload"`
}

func (tf *tailedFile) applyCodex(ln []byte) {
	var e codexEntry
	if json.Unmarshal(ln, &e) != nil {
		return
	}
	p, s := &e.Payload, &tf.s
	switch e.Type {
	case "session_meta":
		setIf(&s.ID, p.ID)
		setIf(&s.CWD, p.CWD)
		if p.Git != nil {
			setIf(&s.Branch, p.Git.Branch)
		}
	case "turn_context":
		setIf(&s.Model, p.Model)
		setIf(&s.CWD, p.CWD)
	case "event_msg":
		tf.codexEvent(p)
	case "response_item":
		switch p.Type {
		case "function_call", "custom_tool_call", "local_shell_call":
			s.State, s.Tool = stateTool, p.Name
		case "function_call_output", "custom_tool_call_output":
			s.State, s.Tool = stateWorking, ""
		}
	}
}

func (tf *tailedFile) codexEvent(p *codexPayload) {
	s := &tf.s
	switch p.Type {
	case "task_started":
		s.State, s.Tool = stateWorking, ""
	case "task_complete", "turn_aborted":
		s.State, s.Tool = stateIdle, ""
	case "token_count":
		if p.Info == nil {
			return
		}
		t := p.Info.Total
		s.InTok, s.CacheTok, s.OutTok = t.Input-t.Cached, t.Cached, t.Output
		s.CtxTok, s.CtxWin = p.Info.Last.Total, p.Info.Window
	}
}

// ── rendering ───────────────────────────────────────────────────────────────

const sessionRowsShown = 8

// renderSessionRows draws the ⁵sessions table for one agent.
func renderSessionRows(all []AgentSession, agent string, now time.Time) []string {
	var picked []AgentSession
	live := 0
	for _, s := range all {
		if s.Agent == agent {
			picked = append(picked, s)
			if now.Sub(s.Last) < sessionLiveFor {
				live++
			}
		}
	}
	rows := []string{titleSt.Render(fmt.Sprintf("╭─ ⁵sessions · %s · %d live · %d in 24h · read from transcripts ─╮", agent, live, len(picked)))}
	if len(picked) == 0 {
		return append(rows, dimSt.Render("   (no "+agent+" sessions written in the last 24h)"))
	}
	rows = append(rows, groupSt.Render("   "+sessionCols("STATE", "AGE", "PROJECT", "BRANCH", "MODEL", "CONTEXT", "OUT", "TITLE")))
	for _, s := range picked[:min(len(picked), sessionRowsShown)] {
		rows = append(rows, renderSessionRow(s, now))
	}
	return rows
}

func renderSessionRow(s AgentSession, now time.Time) string {
	state := s.State
	if s.State == stateTool && s.Tool != "" {
		state = "tool:" + s.Tool
	}
	out := humanTok(s.OutTok)
	if s.Partial {
		out = "≥" + out
	}
	line := sessionCols(state, humanAge(now.Sub(s.Last)), filepath.Base(s.CWD), s.Branch,
		strings.TrimPrefix(s.Model, "claude-"), contextLabel(s), out, s.Title)
	if now.Sub(s.Last) < sessionLiveFor {
		return okSt.Render(" ● ") + bodySt.Render(line)
	}
	return dimSt.Render(" ○ " + line)
}

// sessionCols lays out one row; every field is sanitised and fitted to its column.
func sessionCols(f ...string) string {
	widths := []int{14, 4, 16, 16, 16, 14, 6}
	var b strings.Builder
	for i, w := range widths {
		b.WriteString(padTo(oneLine(f[i]), w) + " ")
	}
	b.WriteString(oneLine(f[len(widths)]))
	return b.String()
}

func oneLine(s string) string {
	return strings.NewReplacer("\n", " ", "\t", " ").Replace(clean(s))
}

func padTo(s string, w int) string {
	s = ansi.Truncate(s, w, "…")
	return s + strings.Repeat(" ", max(w-ansi.StringWidth(s), 0))
}

func contextLabel(s AgentSession) string {
	if s.CtxWin <= 0 {
		return humanTok(s.CtxTok)
	}
	return fmt.Sprintf("%s/%s %d%%", humanTok(s.CtxTok), humanTok(s.CtxWin), s.CtxTok*100/s.CtxWin)
}

func humanTok(n int64) string {
	switch {
	case n < 1000:
		return strconv.FormatInt(n, 10)
	case n < 10_000:
		return strings.TrimSuffix(fmt.Sprintf("%.1f", float64(n)/1000), ".0") + "k"
	case n < 1_000_000:
		return fmt.Sprintf("%dk", n/1000)
	default:
		return fmt.Sprintf("%.1fM", float64(n)/1e6)
	}
}

func humanAge(d time.Duration) string {
	switch {
	case d < time.Minute:
		return fmt.Sprintf("%ds", int(d.Seconds()))
	case d < time.Hour:
		return fmt.Sprintf("%dm", int(d.Minutes()))
	case d < 24*time.Hour:
		return fmt.Sprintf("%dh", int(d.Hours()))
	default:
		return fmt.Sprintf("%dd", int(d.Hours()/24))
	}
}
