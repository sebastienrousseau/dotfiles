// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// dot-ai — the `dot ai` cockpit. A Bubble Tea TUI that unifies the AI fleet,
// the local Claude gateway, and run cost/telemetry in one screen. Actions
// shell out to the `dot ai` verbs (chat/install/serve) so behaviour has a
// single source of truth. Built on `chezmoi apply` via mise (see the
// run_onchange build step) and deployed to ~/.local/bin/dot-ai-tui.
package main

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

type tool struct {
	name, bin, group string
	installed        bool
}

// The fleet, in display order, grouped by role.
var fleet = []tool{
	{name: "claude", bin: "claude", group: "agents"},
	{name: "codex", bin: "codex", group: "agents"},
	{name: "copilot", bin: "copilot", group: "agents"},
	{name: "goose", bin: "goose", group: "agents"},
	{name: "opencode", bin: "opencode", group: "coding"},
	{name: "aider", bin: "aider", group: "coding"},
	{name: "autohand", bin: "autohand", group: "coding"},
	{name: "vibe", bin: "vibe", group: "coding"},
	{name: "qwen", bin: "qwen", group: "coding"},
	{name: "zai", bin: "zai", group: "coding"},
	{name: "agy", bin: "agy", group: "general"},
	{name: "sgpt", bin: "sgpt", group: "general"},
	{name: "ollama", bin: "ollama", group: "local"},
	{name: "kiro-cli", bin: "kiro-cli", group: "cloud"},
}

type refreshMsg struct {
	tools      []tool
	gatewayUp  bool
	gatewayMsg string
	costToday  string
	recent     []string
}

type model struct {
	tools         []tool
	cursor        int
	gatewayUp     bool
	gatewayMsg    string
	costToday     string
	recent        []string
	width, height int
	status        string
}

// ── styling ────────────────────────────────────────────────────────────────
var (
	cAccent  = lipgloss.Color("12")
	cOK      = lipgloss.Color("10")
	cDim     = lipgloss.Color("8")
	cWarn    = lipgloss.Color("11")
	titleSt  = lipgloss.NewStyle().Bold(true).Foreground(cAccent)
	groupSt  = lipgloss.NewStyle().Bold(true).Foreground(cDim)
	selSt    = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("0")).Background(cAccent)
	okSt     = lipgloss.NewStyle().Foreground(cOK)
	dimSt    = lipgloss.NewStyle().Foreground(cDim)
	warnSt   = lipgloss.NewStyle().Foreground(cWarn)
	paneSt   = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(cDim).Padding(0, 1)
	footerSt = lipgloss.NewStyle().Foreground(cDim)
)

func gatewayBase() string {
	host := envOr("DOT_AI_HOST", "127.0.0.1")
	port := envOr("DOT_AI_PORT", "3456")
	return fmt.Sprintf("http://%s:%s", host, port)
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

// refresh gathers fleet/gateway/cost state (runs off the UI thread).
func refresh() tea.Msg {
	out := refreshMsg{tools: make([]tool, len(fleet))}
	copy(out.tools, fleet)
	for i := range out.tools {
		_, err := exec.LookPath(out.tools[i].bin)
		out.tools[i].installed = err == nil
	}

	// Gateway health.
	client := http.Client{Timeout: 1500 * time.Millisecond}
	if resp, err := client.Get(gatewayBase() + "/health"); err == nil {
		defer resp.Body.Close()
		body, _ := io.ReadAll(resp.Body)
		out.gatewayUp = resp.StatusCode == 200 && strings.Contains(string(body), "healthy")
		if out.gatewayUp {
			out.gatewayMsg = "serving " + gatewayBase()
		} else {
			out.gatewayMsg = "unhealthy"
		}
	} else {
		out.gatewayMsg = "off"
	}

	// Cost + recent runs from the SQLite log (via the sqlite3 CLI; absent DB
	// or table is fine — we just show zeroes).
	db := dbPath()
	today := time.Now().UTC().Format("2006-01-02") + "T00:00:00Z"
	if v := sqlite(db, fmt.Sprintf(
		"SELECT COALESCE(printf('$%%.2f',SUM(cost_usd)),'$0.00') FROM runs WHERE ts >= '%s';", today)); v != "" {
		out.costToday = v
	} else {
		out.costToday = "$0.00"
	}
	rows := sqlite(db, "SELECT substr(ts,12,5)||'  '||delegate||'  '||COALESCE(project,'')||'  '||"+
		"COALESCE(printf('$%.4f',cost_usd),'-')||'  '||CASE exit_code WHEN 0 THEN 'ok' ELSE 'x' END "+
		"FROM runs ORDER BY id DESC LIMIT 12;")
	if rows != "" {
		out.recent = strings.Split(strings.TrimRight(rows, "\n"), "\n")
	}
	return out
}

func sqlite(db, query string) string {
	if _, err := os.Stat(db); err != nil {
		return ""
	}
	cmd := exec.Command("sqlite3", "-noheader", db, query)
	b, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

func (m model) Init() tea.Cmd { return refresh }

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
	case refreshMsg:
		m.tools, m.gatewayUp, m.gatewayMsg = msg.tools, msg.gatewayUp, msg.gatewayMsg
		m.costToday, m.recent = msg.costToday, msg.recent
		m.status = ""
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c", "esc":
			return m, tea.Quit
		case "up", "k":
			if m.cursor > 0 {
				m.cursor--
			}
		case "down", "j":
			if m.cursor < len(m.tools)-1 {
				m.cursor++
			}
		case "c", "r":
			m.status = "refreshing…"
			return m, refresh
		case "enter":
			t := m.tools[m.cursor]
			return m, dotExec("chat", t.name)
		case "i":
			t := m.tools[m.cursor]
			return m, dotExec("install", t.name)
		case "s":
			if m.gatewayUp {
				return m, dotExec("serve", "stop")
			}
			return m, dotExec("serve")
		}
	}
	return m, nil
}

// dotExec suspends the TUI, runs `dot ai <args…>`, then refreshes.
func dotExec(args ...string) tea.Cmd {
	c := exec.Command("dot", append([]string{"ai"}, args...)...)
	return tea.ExecProcess(c, func(error) tea.Msg { return refresh() })
}

func (m model) View() string {
	if m.width == 0 {
		return "loading…"
	}
	gw := warnSt.Render("○ gateway off")
	if m.gatewayUp {
		gw = okSt.Render("● " + m.gatewayMsg)
	}
	header := titleSt.Render("dot ai") + "   " + gw +
		dimSt.Render("   ·   today ") + okSt.Render(m.costToday)

	// Left: fleet list grouped.
	var left strings.Builder
	lastGroup := ""
	for i, t := range m.tools {
		if t.group != lastGroup {
			if lastGroup != "" {
				left.WriteString("\n")
			}
			left.WriteString(groupSt.Render("▸ "+t.group) + "\n")
			lastGroup = t.group
		}
		mark := dimSt.Render("○")
		if t.installed {
			mark = okSt.Render("●")
		}
		row := fmt.Sprintf("%s %-12s", mark, t.name)
		if i == m.cursor {
			row = selSt.Render(fmt.Sprintf("%s %-12s", mark, t.name))
		}
		left.WriteString("  " + row + "\n")
	}

	// Right: selected tool + recent runs.
	t := m.tools[m.cursor]
	state := warnSt.Render("not installed — press i to install")
	if t.installed {
		state = okSt.Render("installed")
	}
	var right strings.Builder
	right.WriteString(titleSt.Render(strings.ToUpper(t.name)) + "  " + dimSt.Render("("+t.group+")") + "\n")
	right.WriteString("status   " + state + "\n")
	right.WriteString("route    " + dimSt.Render(routeLine(m, t)) + "\n\n")
	right.WriteString(groupSt.Render("RECENT") + "\n")
	if len(m.recent) == 0 {
		right.WriteString(dimSt.Render("  no runs yet — start one with enter") + "\n")
	} else {
		for _, r := range m.recent {
			right.WriteString("  " + r + "\n")
		}
	}

	colW := (m.width - 8) / 2
	if colW < 20 {
		colW = 20
	}
	leftPane := paneSt.Width(colW).Render(left.String())
	rightPane := paneSt.Width(colW).Render(right.String())
	body := lipgloss.JoinHorizontal(lipgloss.Top, leftPane, rightPane)

	footer := footerSt.Render("↑↓ move  ⏎ chat  i install  s serve  c refresh  q quit")
	if m.status != "" {
		footer = footerSt.Render(m.status) + "   " + footer
	}
	return header + "\n" + body + "\n" + footer
}

func routeLine(m model, t tool) string {
	if t.name == "claude" {
		return "native session (never proxied)"
	}
	if m.gatewayUp {
		return "via local gateway when serving"
	}
	return "own provider (gateway off)"
}

func main() {
	p := tea.NewProgram(model{}, tea.WithAltScreen())
	if _, err := p.Run(); err != nil {
		fmt.Fprintln(os.Stderr, "dot-ai-tui:", err)
		os.Exit(1)
	}
}
