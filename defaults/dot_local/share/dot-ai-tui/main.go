// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// dot-ai — the `dot ai` cockpit. A glamorous, chat-centric Bubble Tea TUI for
// the AI fleet, modelled on Charm's aesthetic. Pick a tool on the left, chat
// with it on the right (prompts run through `dot ai <tool>`), and watch the
// gateway + cost in the header. Actions shell out to the `dot ai` verbs so
// behaviour has a single source of truth. Deployed to ~/.local/bin/dot-ai-tui.
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

	"github.com/alecthomas/chroma/v2/quick"
	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/x/ansi"
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
	{name: "crush", bin: "crush", group: "agents"},
	{name: "amp", bin: "amp", group: "agents"},
	{name: "cursor-agent", bin: "cursor-agent", group: "agents"},
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

// ── theme (Charm-flavoured) ─────────────────────────────────────────────────
var (
	violet = lipgloss.Color("#7D56F4")
	mauve  = lipgloss.Color("#B69CFF")
	pink   = lipgloss.Color("#EE6FF8")
	green  = lipgloss.Color("#56D364")
	amber  = lipgloss.Color("#F2C14E")
	red    = lipgloss.Color("#FF6E6E")
	text   = lipgloss.AdaptiveColor{Light: "#1A1A2E", Dark: "#EDEDFB"}
	muted  = lipgloss.Color("#8A8AA8")
	faint  = lipgloss.Color("#56566E")
	border = lipgloss.Color("#322A4A")

	logoSt   = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("#FFFFFF")).Background(violet).Padding(0, 1)
	tagSt    = lipgloss.NewStyle().Foreground(mauve).Italic(true)
	titleSt  = lipgloss.NewStyle().Bold(true).Foreground(violet)
	chipOK   = lipgloss.NewStyle().Foreground(lipgloss.Color("#0B1F12")).Background(green).Padding(0, 1).Bold(true)
	chipOff  = lipgloss.NewStyle().Foreground(text).Background(faint).Padding(0, 1)
	chipCost = lipgloss.NewStyle().Foreground(lipgloss.Color("#241A05")).Background(amber).Padding(0, 1).Bold(true)
	groupSt  = lipgloss.NewStyle().Foreground(muted).Bold(true)
	okSt     = lipgloss.NewStyle().Foreground(green)
	offSt    = lipgloss.NewStyle().Foreground(faint)
	dimSt    = lipgloss.NewStyle().Foreground(muted)
	selSt    = lipgloss.NewStyle().Foreground(pink).Bold(true)
	youSt    = lipgloss.NewStyle().Foreground(mauve).Bold(true)
	botSt    = lipgloss.NewStyle().Foreground(green).Bold(true)
	bodySt   = lipgloss.NewStyle().Foreground(text)
	panel    = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(border).Padding(0, 1)
	panelHot = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(violet).Padding(0, 1)
	keySt    = lipgloss.NewStyle().Foreground(mauve).Bold(true)
	keyDesc  = lipgloss.NewStyle().Foreground(faint)
)

type line struct {
	who  string // "you" | tool name | "sys"
	text string
}

// paletteItem is one entry in the `/` command palette. kind "cockpit" runs in
// the chat; kind "session" opens the tool's native REPL where it applies.
type paletteItem struct {
	label, desc, kind string
}

// Cockpit commands work in the in-chat one-shot mode.
var cockpitCmds = []paletteItem{
	{"/help", "list commands", "cockpit"},
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

// Common native REPL commands per provider — for familiarity. Selecting one
// opens the tool's session (overlapping cockpit labels are filtered out).
var toolCmds = map[string][]paletteItem{
	"claude":       {{"/compact", "summarise context", "session"}, {"/model", "switch model", "session"}, {"/resume", "resume a session", "session"}, {"/agents", "manage subagents", "session"}, {"/mcp", "MCP servers", "session"}, {"/usage", "usage & limits", "session"}, {"/init", "generate CLAUDE.md", "session"}},
	"codex":        {{"/model", "switch model", "session"}, {"/approvals", "approval mode", "session"}, {"/status", "session status", "session"}, {"/mcp", "MCP servers", "session"}},
	"aider":        {{"/add", "add files", "session"}, {"/drop", "drop files", "session"}, {"/diff", "show diff", "session"}, {"/commit", "commit changes", "session"}, {"/undo", "undo last edit", "session"}, {"/model", "switch model", "session"}},
	"opencode":     {{"/model", "switch model", "session"}, {"/share", "share session", "session"}, {"/undo", "undo", "session"}},
	"goose":        {{"/mode", "set agent mode", "session"}, {"/extension", "manage extensions", "session"}, {"/model", "switch model", "session"}},
	"crush":        {{"/model", "switch model", "session"}, {"/help", "list commands", "session"}, {"/compact", "summarise context", "session"}},
	"amp":          {{"/help", "list commands", "session"}, {"/thread", "manage threads", "session"}},
	"cursor-agent": {{"/model", "switch model", "session"}, {"/help", "list commands", "session"}},
	"copilot":      {{"/model", "switch model", "session"}, {"/clear", "clear context", "session"}},
	"qwen":         {{"/model", "switch model", "session"}, {"/clear", "clear", "session"}},
}

func clampi(v, lo, hi int) int {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}

// execCommand is indirected so tests can substitute a harmless command.
var execCommand = exec.Command

type refreshMsg struct {
	tools      []tool
	gatewayUp  bool
	gatewayMsg string
	costToday  string
	recent     []string
}

type streamMsg struct {
	chunk string
	done  bool
	err   error
}

type model struct {
	tools         []tool
	cursor        int
	gatewayUp     bool
	gatewayMsg    string
	costToday     string
	recent        []string
	width, height int
	focus         string // "fleet" | "input"
	input         textinput.Model
	spin          spinner.Model
	transcript    []line
	running       bool
	status        string
	style         string // active steering style (--style)
	streamCh      chan streamMsg
	palSel        int    // selected index in the `/` command palette
	aiModel       string // model override ("" = tool default)
	runStart      int64  // unix start of the in-flight turn (for notify)
}

// palette returns the filtered command list when the input begins with "/".
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
				continue // cockpit label wins over a duplicate tool label
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

func gatewayBase() string {
	return fmt.Sprintf("http://%s:%s", envOr("DOT_AI_HOST", "127.0.0.1"), envOr("DOT_AI_PORT", "3456"))
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

// ── data gathering (off the UI thread) ──────────────────────────────────────
func refresh() tea.Msg {
	out := refreshMsg{tools: make([]tool, len(fleet))}
	copy(out.tools, fleet)
	for i := range out.tools {
		_, err := exec.LookPath(out.tools[i].bin)
		out.tools[i].installed = err == nil
	}
	client := http.Client{Timeout: 1500 * time.Millisecond}
	if resp, err := client.Get(gatewayBase() + "/health"); err == nil {
		defer resp.Body.Close()
		body, _ := io.ReadAll(resp.Body)
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
	// -init /dev/null skips ~/.sqliterc (which may enable .timer/.headers and
	// pollute output); -batch -noheader keep it machine-readable.
	b, err := exec.Command("sqlite3", "-batch", "-init", "/dev/null", "-noheader", db, query).Output()
	if err != nil {
		return ""
	}
	// Defensive: drop any stray "Run Time:"/dot-prefixed meta lines.
	var keep []string
	for _, ln := range strings.Split(strings.TrimSpace(string(b)), "\n") {
		if strings.HasPrefix(ln, "Run Time:") || strings.HasPrefix(strings.TrimSpace(ln), ".") {
			continue
		}
		keep = append(keep, ln)
	}
	return strings.TrimSpace(strings.Join(keep, "\n"))
}

// buildPrompt flattens prior turns into the prompt so the conversation has
// context (multi-turn) for a fresh one-shot.
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

// startStream runs `dot ai [tool] [--style s] "<prompt>"` in raw mode and
// feeds its stdout to the channel chunk-by-chunk, so the reply streams into
// the transcript live (no screen takeover, no banner pollution).
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
		buf := make([]byte, 512)
		for {
			n, rerr := stdout.Read(buf)
			if n > 0 {
				ch <- streamMsg{chunk: string(buf[:n])}
			}
			if rerr != nil {
				break
			}
		}
		_ = cmd.Wait()
		ch <- streamMsg{done: true}
	}()
	return ch, waitForChunk(ch)
}

func waitForChunk(ch chan streamMsg) tea.Cmd {
	return func() tea.Msg { return <-ch }
}

// models — the model overrides offered by the picker. "" means the tool's
// default (no override). Applied to the Claude engine via ANTHROPIC_MODEL.
var models = []string{"", "opus", "sonnet", "haiku"}

func modelLabel(m string) string {
	if m == "" {
		return "default"
	}
	return m
}

// nextModel returns the model after the given one in the cycle.
func nextModel(cur string) string {
	for i, m := range models {
		if m == cur {
			return models[(i+1)%len(models)]
		}
	}
	return models[0]
}

func nowUnix() int64 { return time.Now().Unix() }

// ── session persistence ─────────────────────────────────────────────────────
type sessLine struct{ Who, Text string }

func sessionPath() string {
	base := envOr("XDG_STATE_HOME", filepath.Join(os.Getenv("HOME"), ".local", "state"))
	return filepath.Join(base, "dot-ai-tui", "session.json")
}

func saveSession(lines []line) {
	s := make([]sessLine, 0, len(lines))
	for _, l := range lines {
		s = append(s, sessLine{l.who, l.text})
	}
	b, err := json.Marshal(s)
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
	var s []sessLine
	if json.Unmarshal(b, &s) != nil {
		return nil
	}
	out := make([]line, 0, len(s))
	for _, x := range s {
		out = append(out, line{who: x.Who, text: x.Text})
	}
	return out
}

// notify fires a best-effort desktop notification (macOS osascript / Linux
// notify-send); failures are silent.
func notify(title, body string) {
	var c *exec.Cmd
	switch runtime.GOOS {
	case "darwin":
		c = execCommand("osascript", "-e",
			fmt.Sprintf("display notification %q with title %q", body, title))
	default:
		c = execCommand("notify-send", title, body)
	}
	_ = c.Start()
}

// highlight syntax-colours fenced ``` code blocks (and inline diffs) with
// chroma, leaving prose untouched.
func highlight(text string) string {
	if !strings.Contains(text, "```") {
		return text
	}
	parts := strings.Split(text, "```")
	var b strings.Builder
	for i, p := range parts {
		if i%2 == 0 {
			b.WriteString(p)
			continue
		}
		lang, code := "", p
		if nl := strings.IndexByte(p, '\n'); nl >= 0 {
			lang, code = strings.TrimSpace(p[:nl]), p[nl+1:]
		}
		var hb strings.Builder
		if err := quick.Highlight(&hb, code, lang, "terminal256", "github-dark"); err == nil {
			b.WriteString(hb.String())
		} else {
			b.WriteString(code)
		}
	}
	return b.String()
}

// execDone is the post-exec callback — refresh after an interactive command.
func execDone(error) tea.Msg { return refresh() }

// dotExec suspends the TUI for an interactive `dot ai <args…>` then refreshes.
func dotExec(args ...string) tea.Cmd {
	c := execCommand("dot", append([]string{"ai"}, args...)...)
	return tea.ExecProcess(c, execDone)
}

func newModel() model {
	t := make([]tool, len(fleet))
	copy(t, fleet)

	ti := textinput.New()
	ti.Placeholder = "ask the selected tool…  (/help · Tab to browse)"
	ti.Prompt = "❯ "
	ti.PromptStyle = lipgloss.NewStyle().Foreground(pink).Bold(true)
	ti.TextStyle = bodySt
	ti.PlaceholderStyle = lipgloss.NewStyle().Foreground(faint)
	ti.CharLimit = 2000

	sp := spinner.New()
	sp.Spinner = spinner.Dot
	sp.Style = lipgloss.NewStyle().Foreground(pink)

	return model{tools: t, focus: "fleet", input: ti, spin: sp}
}

func (m model) Init() tea.Cmd { return tea.Batch(refresh, textinput.Blink) }

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmds []tea.Cmd
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		m.input.Width = m.rightWidth() - 4
	case refreshMsg:
		m.tools, m.gatewayUp, m.gatewayMsg = msg.tools, msg.gatewayUp, msg.gatewayMsg
		m.costToday, m.recent = msg.costToday, msg.recent
		m.status = ""
	case spinner.TickMsg:
		if m.running {
			var c tea.Cmd
			m.spin, c = m.spin.Update(msg)
			cmds = append(cmds, c)
		}
	case streamMsg:
		if len(m.transcript) == 0 {
			return m, nil
		}
		last := len(m.transcript) - 1
		if msg.err != nil {
			m.transcript[last].text = "error: " + msg.err.Error()
			m.running, m.streamCh = false, nil
			return m, nil
		}
		if msg.chunk != "" {
			m.transcript[last].text += msg.chunk
		}
		if msg.done {
			m.transcript[last].text = strings.TrimSpace(m.transcript[last].text)
			if m.transcript[last].text == "" {
				m.transcript[last].text = "(no output — is the tool installed and authenticated?)"
			}
			m.running, m.streamCh = false, nil
			saveSession(m.transcript) // persist for /resume
			// Desktop notification for replies that took a while (≥8s).
			if m.runStart > 0 && nowUnix()-m.runStart >= 8 {
				notify("dot ai · "+m.transcript[last].who, "reply ready")
			}
			m.runStart = 0
			return m, nil
		}
		return m, waitForChunk(m.streamCh)
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c":
			return m, tea.Quit
		case "tab":
			if m.focus == "fleet" {
				m.focus = "input"
				m.input.Focus()
				return m, textinput.Blink
			}
			// In chat: tab completes the open palette instead of toggling.
			if len(m.palette()) > 0 {
				return m.updateInput(msg)
			}
			m.focus = "fleet"
			m.input.Blur()
			return m, nil
		}
		if m.focus == "input" {
			return m.updateInput(msg)
		}
		return m.updateFleet(msg)
	}
	return m, tea.Batch(cmds...)
}

func (m model) updateFleet(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "q", "esc":
		return m, tea.Quit
	case "up", "k":
		if m.cursor > 0 {
			m.cursor--
		}
	case "down", "j":
		if m.cursor < len(m.tools)-1 {
			m.cursor++
		}
	case "enter":
		// Open the tool's full native session (all its own commands —
		// /exit, /clear, /model, … — work there). Suspends the TUI.
		return m, dotExec("chat", m.tools[m.cursor].name)
	case "/", "p":
		// Jump into the quick in-cockpit chat input.
		m.focus = "input"
		m.input.Focus()
		if msg.String() == "/" {
			m.input.SetValue("/")
		}
		return m, textinput.Blink
	case "c", "r":
		m.status = "refreshing…"
		return m, refresh
	case "i":
		return m, dotExec("install", m.tools[m.cursor].name)
	case "m":
		m.aiModel = nextModel(m.aiModel)
		m.status = "model → " + modelLabel(m.aiModel)
	case "s":
		if m.gatewayUp {
			return m, dotExec("serve", "stop")
		}
		return m, dotExec("serve")
	}
	return m, nil
}

func (m model) updateInput(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	pal := m.palette()
	switch msg.String() {
	case "esc":
		if len(pal) > 0 { // close the palette first
			m.input.SetValue("")
			m.palSel = 0
			return m, nil
		}
		m.focus = "fleet"
		m.input.Blur()
		return m, nil
	case "up", "ctrl+p":
		if len(pal) > 0 {
			m.palSel = clampi(m.palSel-1, 0, len(pal)-1)
			return m, nil
		}
	case "down", "ctrl+n":
		if len(pal) > 0 {
			m.palSel = clampi(m.palSel+1, 0, len(pal)-1)
			return m, nil
		}
	case "tab": // complete the input to the selected command
		if len(pal) > 0 {
			m.input.SetValue(pal[clampi(m.palSel, 0, len(pal)-1)].label + " ")
			m.palSel = 0
			return m, nil
		}
	case "enter":
		if len(pal) > 0 { // run the selected palette command
			it := pal[clampi(m.palSel, 0, len(pal)-1)]
			m.input.SetValue("")
			m.palSel = 0
			if it.kind == "cockpit" {
				return m.handleSlash(it.label)
			}
			m.transcript = append(m.transcript, line{who: "sys",
				text: "opening " + m.tools[m.cursor].name + " session — " + it.label + " works there"})
			return m, dotExec("chat", m.tools[m.cursor].name)
		}
		q := strings.TrimSpace(m.input.Value())
		if q == "" {
			return m, nil
		}
		m.input.SetValue("")
		if strings.HasPrefix(q, "/") {
			return m.handleSlash(q)
		}
		if m.running {
			return m, nil
		}
		t := m.tools[m.cursor]
		history := append([]line(nil), m.transcript...)
		m.transcript = append(m.transcript, line{who: "you", text: q})
		m.transcript = append(m.transcript, line{who: t.name, text: ""})
		m.running = true
		m.runStart = nowUnix()
		ch, cmd := startStream(t.name, m.style, m.aiModel, history, q)
		m.streamCh = ch
		return m, tea.Batch(cmd, m.spin.Tick)
	}
	var c tea.Cmd
	m.input, c = m.input.Update(msg)
	m.palSel = 0
	return m, c
}

// handleSlash interprets in-chat slash commands.
func (m model) handleSlash(cmd string) (tea.Model, tea.Cmd) {
	f := strings.Fields(cmd)
	name := f[0]
	arg := strings.TrimSpace(strings.TrimPrefix(cmd, name))
	sys := func(s string) { m.transcript = append(m.transcript, line{who: "sys", text: s}) }
	switch name {
	case "/help", "/?":
		sys("cockpit: /model <name> · /style <name|off> · /tool <name> · /resume · /save · /serve · /cost · /clear · /exit")
		sys("for a tool's own commands (/exit, /compact, …) press Enter on the fleet to open its session")
	case "/clear":
		m.transcript = nil
	case "/model":
		if arg == "" {
			sys("models: " + strings.TrimSpace(strings.Join(models, " ")+" (blank = default)") + " — current: " + modelLabel(m.aiModel))
		} else if arg == "default" || arg == "off" {
			m.aiModel = ""
			sys("model → default")
		} else {
			m.aiModel = arg
			sys("model → " + arg)
		}
	case "/resume":
		s := loadSession()
		if len(s) == 0 {
			sys("no saved session to resume")
		} else {
			m.transcript = s
			sys(fmt.Sprintf("resumed last session (%d lines)", len(s)))
		}
	case "/save":
		saveSession(m.transcript)
		sys("session saved")
	case "/quit", "/q", "/exit":
		return m, tea.Quit
	case "/style":
		if arg == "" || arg == "off" {
			m.style, _ = "", arg
			sys("style cleared")
		} else {
			m.style = arg
			sys("style → " + arg)
		}
	case "/tool":
		for i, t := range m.tools {
			if t.name == arg {
				m.cursor = i
				sys("tool → " + arg)
				return m, nil
			}
		}
		sys("unknown tool: " + arg + "  (Tab to browse the fleet)")
	case "/serve":
		return m, dotExec("serve")
	case "/cost":
		return m, dotExec("cost")
	default:
		sys("unknown command: " + name + "  (try /help)")
	}
	return m, nil
}

// ── layout helpers ──────────────────────────────────────────────────────────
func (m model) leftWidth() int {
	w := m.width / 4
	if w < 18 {
		w = 18
	}
	if w > 26 {
		w = 26
	}
	return w
}
func (m model) rightWidth() int { return m.width - m.leftWidth() - 5 }

func (m model) View() string {
	if m.width < 40 || m.height < 12 || len(m.tools) == 0 {
		return "  loading dot ai…"
	}

	// Header: logo + tagline + gateway/cost chips.
	gw := chipOff.Render("○ gateway off")
	if m.gatewayUp {
		gw = chipOK.Render("● " + m.gatewayMsg)
	}
	left := logoSt.Render("◆ dot ai") + "  " + tagSt.Render("AI fleet cockpit")
	if m.aiModel != "" {
		left += dimSt.Render("  · model ") + selSt.Render(m.aiModel)
	}
	if m.style != "" {
		left += dimSt.Render("  · style ") + selSt.Render(m.style)
	}
	right := gw + " " + chipCost.Render("today "+m.costToday)
	gap := m.width - lipgloss.Width(left) - lipgloss.Width(right) - 2
	if gap < 1 {
		gap = 1
	}
	header := " " + left + strings.Repeat(" ", gap) + right

	bodyH := m.height - 5 // height >= 12 is guaranteed above, so bodyH >= 7

	// Left: the fleet, as lines, then windowed so it never overflows the
	// panel height and the cursor stays visible.
	var rows []string
	cursorRow := 0
	lastGroup := ""
	for i, t := range m.tools {
		if t.group != lastGroup {
			rows = append(rows, groupSt.Render(strings.ToUpper(t.group)))
			lastGroup = t.group
		}
		dot := offSt.Render("○")
		if t.installed {
			dot = okSt.Render("●")
		}
		if i == m.cursor {
			cursorRow = len(rows)
			rows = append(rows, selSt.Render("▌")+dot+" "+selSt.Render(t.name))
		} else {
			rows = append(rows, " "+dot+" "+bodySt.Render(t.name))
		}
	}
	rows = windowRows(rows, cursorRow, bodyH)
	leftStyle := panel
	if m.focus == "fleet" {
		leftStyle = panelHot
	}
	leftPane := leftStyle.Width(m.leftWidth()).Height(bodyH).Render(strings.Join(rows, "\n"))

	// Right: chat transcript + input.
	t := m.tools[m.cursor]
	rw := m.rightWidth()
	var cb strings.Builder
	cb.WriteString(titleSt.Render(strings.ToUpper(t.name)))
	state := offSt.Render(" not installed — i to install")
	if t.installed {
		state = dimSt.Render(" · ready")
	}
	cb.WriteString(state + "\n\n")
	pal := m.palette()
	if len(pal) > 8 {
		pal = pal[:8]
	}
	cb.WriteString(m.renderTranscript(rw-2, bodyH-5-len(pal)))
	cb.WriteString("\n")
	if len(pal) > 0 {
		cb.WriteString(m.renderPalette(pal, rw-2) + "\n")
	}
	if m.running {
		cb.WriteString(m.spin.View() + dimSt.Render(" "+t.name+" is thinking…"))
	} else {
		cb.WriteString(m.input.View())
	}
	rightStyle := panel
	if m.focus == "input" {
		rightStyle = panelHot
	}
	rightPane := rightStyle.Width(rw).Height(bodyH).Render(cb.String())

	body := lipgloss.JoinHorizontal(lipgloss.Top, leftPane, rightPane)

	// Footer keybar.
	var keys []struct{ k, d string }
	if m.focus == "input" {
		keys = []struct{ k, d string }{
			{"⏎", "send"}, {"/help", "cmds"}, {"esc", "fleet"}, {"/exit", "quit"},
		}
	} else {
		keys = []struct{ k, d string }{
			{"↑↓", "move"}, {"⏎", "open session"}, {"tab", "quick chat"},
			{"m", "model"}, {"s", "serve"}, {"i", "install"}, {"q", "quit"},
		}
	}
	var fbar strings.Builder
	for i, kv := range keys {
		if i > 0 {
			fbar.WriteString(keyDesc.Render("  ·  "))
		}
		fbar.WriteString(keySt.Render(kv.k) + " " + keyDesc.Render(kv.d))
	}
	footer := " " + fbar.String()
	if m.status != "" {
		footer = " " + dimSt.Render(m.status) + footer
	}

	return strings.Join([]string{header, body, footer}, "\n")
}

// windowRows returns at most h rows from rows, scrolled so that the row at
// `cursor` stays visible.
func windowRows(rows []string, cursor, h int) []string {
	if h < 1 {
		h = 1
	}
	if len(rows) <= h {
		return rows
	}
	start := cursor - h/2
	if start < 0 {
		start = 0
	}
	if start+h > len(rows) {
		start = len(rows) - h
	}
	return rows[start : start+h]
}

// renderTranscript returns exactly h lines (padded at the top) so the input
// box pins to the bottom of the chat panel — a proper chat feel.
func (m model) renderTranscript(w, h int) string {
	if h < 1 {
		h = 1
	}
	var lines []string
	if len(m.transcript) == 0 {
		lines = append(lines, dimSt.Render("Quick chat with ")+titleSt.Render(m.tools[m.cursor].name)+
			dimSt.Render(" — type below, Enter to send (/help for commands)."))
		lines = append(lines, dimSt.Render("For a full session (with the tool's own /exit, /model …) press Enter on the fleet."))
		if len(m.recent) > 0 {
			lines = append(lines, "", groupSt.Render("RECENT"))
			for _, r := range m.recent {
				lines = append(lines, dimSt.Render("  "+r))
			}
		}
	} else {
		for _, l := range m.transcript {
			var tag, content string
			hasCode := false
			switch l.who {
			case "you":
				tag, content = youSt.Render("you ▸ "), bodySt.Render(l.text)
			case "sys":
				tag, content = dimSt.Render("· "), dimSt.Render(l.text)
			default:
				tag, content = botSt.Render(l.who+" ▸ "), highlight(l.text)
				hasCode = strings.Contains(l.text, "```")
			}
			if hasCode {
				// Code carries chroma ANSI — truncate (don't lipgloss-wrap,
				// which would strip the colours).
				for i, ln := range strings.Split(content, "\n") {
					if i == 0 {
						ln = tag + ln
					}
					lines = append(lines, ansi.Truncate(ln, w, "…"))
				}
			} else {
				wrapped := lipgloss.NewStyle().Width(w).Render(tag + content)
				lines = append(lines, strings.Split(wrapped, "\n")...)
			}
		}
	}
	// Keep the tail; pad the top so content sits at the bottom.
	if len(lines) > h {
		lines = lines[len(lines)-h:]
	}
	for len(lines) < h {
		lines = append([]string{""}, lines...)
	}
	return strings.Join(lines, "\n")
}

// renderSnapshot prints one frame at a fixed size — for previews and
// non-TTY/CI rendering. Enabled with DOT_AI_SNAPSHOT=1.
func renderSnapshot() {
	m := newModel()
	mm, _ := m.Update(tea.WindowSizeMsg{Width: 94, Height: 26})
	m = mm.(model)
	if r, ok := refresh().(refreshMsg); ok {
		mm, _ = m.Update(r)
		m = mm.(model)
	}
	m.transcript = []line{
		{who: "you", text: "show me a typed fetch wrapper"},
		{who: "claude", text: "Here's a small typed wrapper:\n```ts\nexport async function getJSON<T>(url: string): Promise<T> {\n  const r = await fetch(url);\n  if (!r.ok) throw new Error(r.statusText);\n  return r.json();\n}\n```\nCall it with `getJSON<User>(\"/api/me\")`."},
	}
	m.style = "architect"
	m.focus = "input"
	m.input.SetValue("/") // show the command palette in the preview
	fmt.Println(m.View())
}

func run() error {
	if os.Getenv("DOT_AI_SNAPSHOT") != "" {
		renderSnapshot()
		return nil
	}
	_, err := tea.NewProgram(newModel(), tea.WithAltScreen()).Run()
	return err
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "dot-ai-tui:", err)
		os.Exit(1)
	}
}
