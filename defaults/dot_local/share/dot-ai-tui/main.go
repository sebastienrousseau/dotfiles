// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// dot-ai — the `dot ai` cockpit & btop-grade agentic control plane. Unifies
// the AI fleet with corralctl (multi-forge workspace manager), passmcp (9-repo
// MCP security & risk-graph family), and draft (grounded research & C2PA
// synthesis), plus ISO/IEC 21031:2024 SCI carbon/Joule telemetry.
package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
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
	ecoSnap    EcosystemSnapshot
}

type streamMsg struct {
	chunk string
	done  bool
	err   error
}

type model struct {
	tools         []tool
	cursor        int
	actionIdx     int
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
	hideBtop      bool
	refreshed     bool
	ecoSnap       EcosystemSnapshot
	cpuHist       []float64
	kill          pendingKill // armed by x, sent by a second x
	sessions      []AgentSession
	scanner       *sessionScanner
}

func newModel() model {
	t := make([]tool, len(fleet))
	copy(t, fleet)
	ti := textinput.New()
	ti.Placeholder = "ask the selected tool…  (/help · Tab to browse · 1-6 actions)"
	ti.Prompt = "❯ "
	ti.PromptStyle = lipgloss.NewStyle().Foreground(pink).Bold(true)
	ti.TextStyle = bodySt
	ti.PlaceholderStyle = lipgloss.NewStyle().Foreground(faint)
	ti.CharLimit = 2000
	sp := spinner.New()
	sp.Spinner = spinner.Dot
	sp.Style = lipgloss.NewStyle().Foreground(pink)
	snap := sampleEcosystem()
	hist := []float64{12, 24, 36, 28, 45, 32, 20, max(snap.TotalAICPU, 8)}
	return model{tools: t, focus: "fleet", input: ti, spin: sp, ecoSnap: snap, cpuHist: hist, scanner: newSessionScanner()}
}

// Init starts the refresh and the session scan; each sessionsMsg re-arms the tick.
func (m model) Init() tea.Cmd { return tea.Batch(refresh, textinput.Blink, scanSessions(m.scanner)) }

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width, m.height = msg.Width, msg.Height
		m.input.Width = m.rightWidth() - 4
	case refreshMsg:
		m.tools, m.gatewayUp, m.gatewayMsg = msg.tools, msg.gatewayUp, msg.gatewayMsg
		m.costToday, m.recent, m.status = msg.costToday, msg.recent, ""
		m.refreshed = true
		m = m.withEco(msg.ecoSnap)
	case btopTickMsg:
		return m, tea.Batch(scanSessions(m.scanner), sampleEcosystemCmd)
	case ecoMsg:
		return m.withEco(EcosystemSnapshot(msg)), nil
	case sessionsMsg:
		m.sessions = msg
		return m, tickBtop()
	case spinner.TickMsg:
		if m.running {
			var c tea.Cmd
			m.spin, c = m.spin.Update(msg)
			return m, c
		}
	case actionResultMsg:
		return m.handleActionResult(msg), nil
	case streamMsg:
		return m.handleStreamMsg(msg)
	case tea.KeyMsg:
		return m.handleKeyMsg(msg)
	}
	return m, nil
}

func (m model) handleActionResult(msg actionResultMsg) model {
	m.running = false
	m.ecoSnap = sampleEcosystem()
	body := msg.output
	if body == "" && msg.err != nil {
		body = errPrefix + msg.err.Error()
	} else if body == "" {
		body = "(completed with no output)"
	}
	m.transcript = append(m.transcript,
		line{who: "sys", text: fmt.Sprintf("[%s · %s]", msg.tool, msg.label)},
		line{who: msg.tool, text: body},
	)
	m.status = msg.tool + " · " + msg.label + " done (press 0 to return to control centre)"
	return m
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
	k := msg.String()
	if m.kill.pid != 0 && k != "x" {
		m.kill = pendingKill{}
		m.status = "kill cancelled"
	}
	if nm, handled := m.updateFleetNav(k); handled {
		return nm, nil
	}
	if len(k) == 1 && k[0] >= '1' && k[0] <= '6' {
		idx := int(k[0] - '1')
		m.actionIdx = idx
		return m.triggerControlAction(idx)
	}
	return m.updateFleetHotkey(k)
}

func (m model) updateFleetNav(k string) (model, bool) {
	switch k {
	case "up", "k":
		if m.cursor > 0 {
			m.cursor--
			m.actionIdx = 0
		}
		return m, true
	case "down", "j":
		if m.cursor < len(m.tools)-1 {
			m.cursor++
			m.actionIdx = 0
		}
		return m, true
	case "left", "h":
		m.actionIdx = clampi(m.actionIdx-1, 0, 5)
		return m, true
	case "right", "l":
		m.actionIdx = clampi(m.actionIdx+1, 0, 5)
		return m, true
	case "0", "backspace":
		m.transcript = nil
		m.status = "console cleared → control centre"
		return m, true
	case "b":
		m.hideBtop = !m.hideBtop
		m.status = map[bool]string{true: "btop deck → hidden", false: "btop deck → visible"}[m.hideBtop]
		return m, true
	}
	return m, false
}

func (m model) updateFleetHotkey(k string) (tea.Model, tea.Cmd) {
	switch k {
	case "q", "esc":
		return m, tea.Quit
	case "enter":
		if m.tools[m.cursor].group == "ecosystem" {
			return m.triggerControlAction(m.actionIdx)
		}
		return m, dotExec("chat", m.tools[m.cursor].name)
	case "/", "p":
		m.focus = "input"
		m.input.Focus()
		if k == "/" {
			m.input.SetValue("/")
		}
		return m, textinput.Blink
	case "x":
		return m.terminateSelectedProcess()
	case "c":
		return m.jumpToTool("corralctl")
	case "v":
		return m.jumpToTool("passmcp")
	case "d":
		return m.jumpToTool("draft")
	case "r":
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

func (m model) jumpToTool(name string) (tea.Model, tea.Cmd) {
	for i, t := range m.tools {
		if t.name == name {
			m.cursor = i
			m.actionIdx = 0
			break
		}
	}
	m.status = name + " control centre · refreshing…"
	return m, refresh
}

func (m model) triggerControlAction(idx int) (tea.Model, tea.Cmd) {
	t := m.tools[m.cursor]
	actions := toolActions(t)
	act := actions[clampi(idx, 0, len(actions)-1)]
	if act.focusInput {
		m.focus = "input"
		m.input.Focus()
		return m, textinput.Blink
	}
	if act.interactive {
		return m, dotExec("chat", t.name)
	}
	m.running = true
	m.status = "running " + t.name + " · " + act.label + "…"
	return m, tea.Batch(startActionCmd(t.name, act), m.spin.Tick)
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
