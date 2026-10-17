// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// dot-ai — the `dot ai` cockpit & btop-grade agentic control plane. Unifies
// the AI fleet with corralctl (multi-forge workspace manager), passmcp (9-repo
// MCP security & risk-graph family), and draft (grounded research & C2PA
// synthesis), plus ISO/IEC 21031:2024 SCI carbon/Joule telemetry.
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

// The fleet, in display order, grouped by role (including ecosystem tools).
var fleet = []tool{
	{name: "claude", bin: "claude", group: "agents"},
	{name: "codex", bin: "codex", group: "agents"},
	{name: "copilot", bin: "copilot", group: "agents"},
	{name: "goose", bin: "goose", group: "agents"},
	{name: "crush", bin: "crush", group: "agents"},
	{name: "amp", bin: "amp", group: "agents"},
	{name: "cursor-agent", bin: "cursor-agent", group: "agents"},
	{name: "grok", bin: "grok", group: "agents"},
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
	{name: "corralctl", bin: "corralctl", group: "ecosystem"},
	{name: "passmcp", bin: "passmcp", group: "ecosystem"},
	{name: "draft", bin: "draft", group: "ecosystem"},
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
	errSt    = lipgloss.NewStyle().Foreground(red).Bold(true)
	bodySt   = lipgloss.NewStyle().Foreground(text)
	panel    = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(border).Padding(0, 1)
	panelHot = lipgloss.NewStyle().Border(lipgloss.RoundedBorder()).BorderForeground(violet).Padding(0, 1)
	keySt    = lipgloss.NewStyle().Foreground(mauve).Bold(true)
	keyDesc  = lipgloss.NewStyle().Foreground(faint)
)

const errPrefix = "error: "

type line struct {
	who  string
	text string
}

type paletteItem struct {
	label, desc, kind string
}

var cockpitCmds = []paletteItem{
	{"/help", "list commands", "cockpit"},
	{"/eco", "btop telemetry & SCI", "cockpit"},
	{"/green", "toggle green UMA mode", "cockpit"},
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

func clampi(v, lo, hi int) int {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}

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
	style         string
	streamCh      chan streamMsg
	palSel        int
	aiModel       string
	runStart      int64
	greenMode     bool
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
	out := refreshMsg{tools: make([]tool, len(fleet))}
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
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		m.input.Width = m.rightWidth() - 4
	case refreshMsg:
		m.tools, m.gatewayUp, m.gatewayMsg = msg.tools, msg.gatewayUp, msg.gatewayMsg
		m.costToday, m.recent, m.status = msg.costToday, msg.recent, ""
	case spinner.TickMsg:
		if m.running {
			var c tea.Cmd
			m.spin, c = m.spin.Update(msg)
			return m, c
		}
	case streamMsg:
		return m.handleStreamMsg(msg)
	case tea.KeyMsg:
		return m.handleKeyMsg(msg)
	}
	return m, nil
}

func (m model) handleStreamMsg(msg streamMsg) (tea.Model, tea.Cmd) {
	if len(m.transcript) == 0 {
		return m, nil
	}
	last := len(m.transcript) - 1
	if msg.err != nil {
		m.transcript[last].text = errPrefix + msg.err.Error()
		m.running, m.streamCh = false, nil
		return m, nil
	}
	if msg.chunk != "" {
		m.transcript[last].text += clean(msg.chunk)
	}
	if msg.done {
		m.transcript[last].text = strings.TrimSpace(m.transcript[last].text)
		if m.transcript[last].text == "" {
			m.transcript[last].text = "(no output — is the tool installed and authenticated?)"
		}
		m.running, m.streamCh = false, nil
		saveSession(m.transcript)
		if m.runStart > 0 && nowUnix()-m.runStart >= 8 {
			notify("dot ai · "+m.transcript[last].who, "reply ready")
		}
		m.runStart = 0
		return m, nil
	}
	return m, waitForChunk(m.streamCh)
}

func (m model) handleKeyMsg(msg tea.KeyMsg) (tea.Model, tea.Cmd) {
	switch msg.String() {
	case "ctrl+c":
		return m, tea.Quit
	case "tab":
		if m.focus == "fleet" {
			m.focus = "input"
			m.input.Focus()
			return m, textinput.Blink
		}
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
		return m, dotExec("chat", m.tools[m.cursor].name)
	case "/", "p":
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
	case "g":
		m.greenMode = !m.greenMode
		m.status = map[bool]string{true: "green mode → on (UMA split-stage)", false: "green mode → off"}[m.greenMode]
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
		if len(pal) > 0 {
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
	case "tab":
		if len(pal) > 0 {
			m.input.SetValue(pal[clampi(m.palSel, 0, len(pal)-1)].label + " ")
			m.palSel = 0
			return m, nil
		}
	case "enter":
		return m.submitInput(pal)
	}
	var c tea.Cmd
	m.input, c = m.input.Update(msg)
	m.palSel = 0
	return m, c
}

func (m model) submitInput(pal []paletteItem) (tea.Model, tea.Cmd) {
	if len(pal) > 0 {
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
	m.transcript = append(m.transcript, line{who: "you", text: q}, line{who: t.name, text: ""})
	m.running, m.runStart = true, nowUnix()
	ch, cmd := startStream(t.name, m.style, m.aiModel, history, q)
	m.streamCh = ch
	return m, tea.Batch(cmd, m.spin.Tick)
}

func (m model) handleSlash(cmd string) (tea.Model, tea.Cmd) {
	f := strings.Fields(cmd)
	name := f[0]
	arg := strings.TrimSpace(strings.TrimPrefix(cmd, name))
	sys := func(s string) { m.transcript = append(m.transcript, line{who: "sys", text: s}) }
	switch name {
	case "/help", "/?":
		sys("cockpit: /eco · /green · /corral · /mcp · /draft · /model <name> · /style <name|off> · /tool <name> · /resume · /save · /serve · /cost · /clear · /exit")
		sys("for a tool's own commands (/exit, /compact, …) press Enter on the fleet to open its session")
	case "/clear":
		m.transcript = nil
	case "/eco", "/top":
		snap := sampleEcosystem()
		sci := computeSCI(1000, 600, 400, 0, 8.5, 380.0)
		spark := renderBrailleSparkline([]float64{12, 28, 45, 30, 62, 40, 22, 18}, 4)
		sys(spark + " " + formatBtopBar(snap, sci, m.greenMode))
	case "/green":
		m.greenMode = !m.greenMode
		sys(map[bool]string{true: "green mode → on (Apple Silicon UMA split-stage + GreenCache)", false: "green mode → off"}[m.greenMode])
	case "/corral":
		return m, dotExec("corral", arg)
	case "/mcp":
		return m, dotExec("mcp", arg)
	case "/draft":
		return m, dotExec("draft", arg)
	case "/model":
		m.handleSlashModel(arg, sys)
	case "/resume":
		if s := loadSession(); len(s) == 0 {
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
			m.style = ""
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

func run() error {
	if len(os.Args) > 1 && os.Args[1] == "--log-event" {
		return logEventCLI(os.Args[2:])
	}
	if os.Getenv("DOT_AI_SNAPSHOT") != "" {
		renderSnapshot()
		return nil
	}
	_, err := tea.NewProgram(newModel(), tea.WithAltScreen()).Run()
	return err
}

var (
	exit       = os.Exit
	runProgram = run
)

func main() {
	if err := runProgram(); err != nil {
		fmt.Fprintln(os.Stderr, "dot-ai-tui:", err)
		exit(1)
	}
}
