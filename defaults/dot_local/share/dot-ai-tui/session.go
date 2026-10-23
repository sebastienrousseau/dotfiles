// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// session.go — Palette, slash commands, gateway health, sqlite spend/history,
// streaming, session persistence, and desktop notification helpers.
package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/x/ansi"
)

type paletteItem struct {
	label, desc, kind string
}

var cockpitCmds = []paletteItem{
	{"/help", "list commands", "cockpit"},
	{"/eco", "btop telemetry", "cockpit"},
	{"/corral", "corralctl workspace", "cockpit"},
	{"/mcp", "passmcp security audit", "cockpit"},
	{"/draft", "grounded C2PA synthesis", "cockpit"},
	{"/model", "switch model", "cockpit"},
	{"/style", "set steering style", "cockpit"},
	{"/tool", "switch tool", "cockpit"},
	{"/resume", "restore last session", "cockpit"},
	{"/save", "save this session", "cockpit"},
	{"/clear", "clear the chat", "cockpit"},
	{"/serve", "start the gateway", "cockpit"},
	{"/cost", "spend report", "cockpit"},
	{"/exit", "quit the cockpit", "cockpit"},
}

var toolCmds = map[string][]paletteItem{
	"claude":       {{"/compact", "summarise context", "session"}, {"/model", "switch model", "session"}, {"/resume", "resume a session", "session"}, {"/agents", "manage subagents", "session"}, {"/mcp", "MCP servers", "session"}, {"/usage", "usage & limits", "session"}, {"/init", "generate CLAUDE.md", "session"}},
	"codex":        {{"/model", "switch model", "session"}, {"/approvals", "approval mode", "session"}, {"/status", "session status", "session"}, {"/mcp", "MCP servers", "session"}},
	"aider":        {{"/add", "add files", "session"}, {"/drop", "drop files", "session"}, {"/diff", "show diff", "session"}, {"/commit", "commit changes", "session"}, {"/undo", "undo last edit", "session"}, {"/model", "switch model", "session"}},
	"opencode":     {{"/model", "switch model", "session"}, {"/share", "share session", "session"}, {"/undo", "undo", "session"}},
	"goose":        {{"/mode", "set agent mode", "session"}, {"/extension", "manage extensions", "session"}, {"/model", "switch model", "session"}},
	"crush":        {{"/model", "switch model", "session"}, {"/help", "list commands", "session"}, {"/compact", "summarise context", "session"}},
	"amp":          {{"/help", "list commands", "session"}, {"/thread", "manage threads", "session"}},
	"cursor-agent": {{"/model", "switch model", "session"}, {"/help", "list commands", "session"}},
	"grok":         {{"/model", "switch model", "session"}, {"/plan", "plan-first mode", "session"}, {"/mcp", "MCP servers", "session"}},
	"copilot":      {{"/model", "switch model", "session"}, {"/clear", "clear context", "session"}},
	"qwen":         {{"/model", "switch model", "session"}, {"/clear", "clear", "session"}},
	"corralctl":    {{"/sync", "sync forge repos", "session"}, {"/doctor", "refresh Finder tags", "session"}},
	"passmcp":      {{"/check", "9-phase MCP audit", "session"}, {"/graph", "capability risk graph", "session"}},
	"draft":        {{"/verify", "verify C2PA provenance", "session"}},
}

func (m model) palette() []paletteItem {
	if m.focus != "input" {
		return nil
	}
	v := strings.ToLower(strings.TrimSpace(m.input.Value()))
	if !strings.HasPrefix(v, "/") {
		return nil
	}
	seen := map[string]bool{}
	var out []paletteItem
	add := func(items []paletteItem) {
		for _, it := range items {
			if seen[it.label] {
				continue
			}
			if v == "/" || strings.HasPrefix(it.label, v) {
				seen[it.label] = true
				out = append(out, it)
			}
		}
	}
	add(cockpitCmds)
	add(toolCmds[m.tools[m.cursor].name])
	return out
}

func (m model) renderPalette(pal []paletteItem, w int) string {
	sel := clampi(m.palSel, 0, len(pal)-1)
	var b strings.Builder
	for i, it := range pal {
		name := fmt.Sprintf("%-11s", it.label)
		row := dimSt.Render("  ") + bodySt.Render(name) + dimSt.Render(it.desc)
		if it.kind == "session" {
			row += dimSt.Render("  → " + m.tools[m.cursor].name + " session")
		}
		if i == sel {
			row = selSt.Render("▌ "+name) + bodySt.Render(it.desc)
			if it.kind == "session" {
				row += dimSt.Render("  → " + m.tools[m.cursor].name + " session")
			}
		}
		b.WriteString(ansi.Truncate(row, w, "…") + "\n")
	}
	return strings.TrimRight(b.String(), "\n")
}

func (m model) handleSlash(cmd string) (tea.Model, tea.Cmd) {
	f := strings.Fields(cmd)
	name := f[0]
	arg := strings.TrimSpace(strings.TrimPrefix(cmd, name))
	sys := func(s string) { m.transcript = append(m.transcript, line{who: "sys", text: s}) }
	switch name {
	case "/help", "/?":
		sys("cockpit: /eco · /corral · /mcp · /draft · /model <name> · /style <name|off> · /tool <name> · /resume · /save · /serve · /cost · /clear · /exit")
		sys("keys: [1-6] run action · [←→/hl] select action · [c] corralctl · [v] passmcp · [d] draft · [b] btop deck")
	case "/clear":
		m.transcript = nil
	case "/eco", "/top":
		snap := sampleEcosystem()
		sys(renderBrailleSparkline(m.cpuHist, 4) + " " + formatBtopBar(snap))
	case "/corral", "/mcp", "/draft":
		return m, dotExec(strings.TrimPrefix(name, "/"), arg)
	case "/model":
		m.handleSlashModel(arg, sys)
	case "/resume":
		m.handleSlashResume(sys)
	case "/save":
		saveSession(m.transcript)
		sys("session saved")
	case "/quit", "/q", "/exit":
		return m, tea.Quit
	case "/style":
		m.handleSlashStyle(arg, sys)
	case "/tool":
		m.handleSlashTool(arg, sys)
	case "/serve", "/cost":
		return m, dotExec(strings.TrimPrefix(name, "/"))
	default:
		sys("unknown command: " + name + "  (try /help)")
	}
	return m, nil
}

func (m *model) handleSlashResume(sys func(string)) {
	if s := loadSession(); len(s) == 0 {
		sys("no saved session to resume")
	} else {
		m.transcript = s
		sys(fmt.Sprintf("resumed last session (%d lines)", len(s)))
	}
}

func (m *model) handleSlashStyle(arg string, sys func(string)) {
	if arg == "" || arg == "off" {
		m.style = ""
		sys("style cleared")
	} else {
		m.style = arg
		sys("style → " + arg)
	}
}

func (m *model) handleSlashTool(arg string, sys func(string)) {
	for i, t := range m.tools {
		if t.name == arg {
			m.cursor = i
			m.actionIdx = 0
			sys("tool → " + arg)
			return
		}
	}
	sys("unknown tool: " + arg + "  (Tab to browse the fleet)")
}

func (m *model) handleSlashModel(arg string, sys func(string)) {
	switch arg {
	case "":
		sys("models: " + strings.TrimSpace(strings.Join(models, " ")+" (blank = default)") + " — current: " + modelLabel(m.aiModel))
	case "default", "off":
		m.aiModel = ""
		sys("model → default")
	default:
		m.aiModel = arg
		sys("model → " + arg)
	}
}

func gatewayURL(host, port string) string {
	return fmt.Sprintf("http://%s:%s", host, port)
}

func gatewayBase() string {
	return gatewayURL(envOr("DOT_AI_HOST", "127.0.0.1"), envOr("DOT_AI_PORT", "3456"))
}

func envOr(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func dbPath() string {
	if v := os.Getenv("XDG_DATA_HOME"); v != "" {
		return filepath.Join(v, "dotfiles-ai.db")
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".local", "share", "dotfiles-ai.db")
}

func refresh() tea.Msg {
	out := refreshMsg{tools: make([]tool, len(fleet)), ecoSnap: sampleEcosystem()}
	copy(out.tools, fleet)
	for i := range out.tools {
		_, err := exec.LookPath(out.tools[i].bin)
		out.tools[i].installed = err == nil
	}
	client := http.Client{Timeout: 1500 * time.Millisecond}
	if resp, err := client.Get(gatewayBase() + "/health"); err == nil {
		defer func() { _ = resp.Body.Close() }()
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		out.gatewayUp = resp.StatusCode == 200 && strings.Contains(string(body), "healthy")
		out.gatewayMsg = map[bool]string{true: gatewayBase(), false: "unhealthy"}[out.gatewayUp]
	} else {
		out.gatewayMsg = "off"
	}
	db := dbPath()
	today := time.Now().UTC().Format("2006-01-02") + "T00:00:00Z"
	if v := sqlite(db, fmt.Sprintf("SELECT COALESCE(printf('$%%.2f',SUM(cost_usd)),'$0.00') FROM runs WHERE ts >= '%s';", today)); v != "" {
		out.costToday = v
	} else {
		out.costToday = "$0.00"
	}
	if rows := sqlite(db, "SELECT substr(ts,12,5)||'  '||delegate||'  '||COALESCE(project,'') FROM runs ORDER BY id DESC LIMIT 8;"); rows != "" {
		out.recent = strings.Split(strings.TrimRight(rows, "\n"), "\n")
	}
	return out
}

func sqlite(db, query string) string {
	if _, err := os.Stat(db); err != nil {
		return ""
	}
	b, err := exec.Command("sqlite3", "-batch", "-init", "/dev/null", "-noheader", db, query).Output()
	if err != nil {
		return ""
	}
	return clean(filterSqliteOutput(b))
}

func filterSqliteOutput(b []byte) string {
	var keep []string
	for _, ln := range strings.Split(strings.TrimSpace(string(b)), "\n") {
		if t := strings.TrimSpace(ln); strings.HasPrefix(t, "Run Time:") || strings.HasPrefix(t, ".") {
			continue
		}
		keep = append(keep, ln)
	}
	return strings.TrimSpace(strings.Join(keep, "\n"))
}

func buildPrompt(history []line, prompt string) string {
	if len(history) == 0 {
		return prompt
	}
	var b strings.Builder
	b.WriteString("Continue this conversation. Reply only as the assistant, concisely.\n\n")
	for _, l := range history {
		if l.who == "sys" || l.text == "" {
			continue
		}
		role := "Assistant"
		if l.who == "you" {
			role = "User"
		}
		b.WriteString(role + ": " + l.text + "\n\n")
	}
	b.WriteString("User: " + prompt + "\n\nAssistant:")
	return b.String()
}

func startStream(toolName, style, aiModel string, history []line, prompt string) (chan streamMsg, tea.Cmd) {
	ch := make(chan streamMsg, 64)
	go func() {
		args := []string{"ai"}
		if toolName != "" && toolName != "claude" {
			args = append(args, toolName)
		}
		if style != "" {
			args = append(args, "--style", style)
		}
		args = append(args, buildPrompt(history, prompt))
		cmd := execCommand("dot", args...)
		cmd.Env = append(os.Environ(), "DOT_AI_RAW=1")
		if aiModel != "" {
			cmd.Env = append(cmd.Env, "ANTHROPIC_MODEL="+aiModel)
		}
		stdout, err := cmd.StdoutPipe()
		if err != nil {
			ch <- streamMsg{err: err, done: true}
			return
		}
		if err := cmd.Start(); err != nil {
			ch <- streamMsg{err: err, done: true}
			return
		}
		pumpChunks(stdout, ch)
		_ = cmd.Wait()
		ch <- streamMsg{done: true}
	}()
	return ch, waitForChunk(ch)
}

func waitForChunk(ch chan streamMsg) tea.Cmd {
	return func() tea.Msg { return <-ch }
}

var models = []string{"", "opus", "sonnet", "haiku"}

func modelLabel(m string) string {
	if m == "" {
		return "default"
	}
	return m
}

func nextModel(cur string) string {
	for i, m := range models {
		if m == cur {
			return models[(i+1)%len(models)]
		}
	}
	return models[0]
}

func nowUnix() int64 { return time.Now().Unix() }

type sessLine struct{ Who, Text string }

func sessionPath() string {
	base := envOr("XDG_STATE_HOME", filepath.Join(os.Getenv("HOME"), ".local", "state"))
	return filepath.Join(base, "dot-ai-tui", "session.json")
}

var marshalSession = func(s []sessLine) ([]byte, error) { return json.Marshal(s) }

func saveSession(lines []line) {
	s := make([]sessLine, 0, len(lines))
	for _, l := range lines {
		s = append(s, sessLine{l.who, l.text})
	}
	b, err := marshalSession(s)
	if err != nil {
		return
	}
	p := sessionPath()
	if os.MkdirAll(filepath.Dir(p), 0o700) != nil {
		return
	}
	_ = os.WriteFile(p, b, 0o600)
}

func loadSession() []line {
	b, err := os.ReadFile(sessionPath())
	if err != nil {
		return nil
	}
	return parseSession(b)
}

func parseSession(b []byte) []line {
	var s []sessLine
	if json.Unmarshal(b, &s) != nil {
		return nil
	}
	out := make([]line, 0, len(s))
	for _, x := range s {
		out = append(out, line{who: clean(x.Who), text: clean(x.Text)})
	}
	return out
}

func notify(title, body string) {
	_ = notifyCmd(runtime.GOOS, title, body).Start()
}

func notifyCmd(goos, title, body string) *exec.Cmd {
	switch goos {
	case "darwin":
		return execCommand("osascript", "-e",
			fmt.Sprintf("display notification %q with title %q", body, title))
	default:
		return execCommand("notify-send", title, body)
	}
}

func execDone(error) tea.Msg { return refresh() }

func dotExec(args ...string) tea.Cmd {
	c := execCommand("dot", append([]string{"ai"}, args...)...)
	c.Env = append(os.Environ(), "DOT_AI_RAW=1")
	return tea.ExecProcess(c, execDone)
}
