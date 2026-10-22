// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// control.go — btop-grade top telemetry deck, live OS process table (proc),
// process termination ([x]), keyboard shortcut keycaps, and per-tool Control
// Centre for AI agents, local LLMs, corralctl, passmcp, and draft.
package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/x/ansi"
)

// controlAction defines a keyboard-triggered action in a tool's Control Centre.
type controlAction struct {
	key         string
	label       string
	desc        string
	bin         string
	args        []string
	interactive bool
	focusInput  bool
}

// actionResultMsg carries the output of a Control Centre command back into the TUI.
type actionResultMsg struct {
	tool   string
	label  string
	output string
	err    error
}

// btopTickMsg fires every sessionTickRate; its handler samples processes and
// transcripts off the UI goroutine.
type btopTickMsg struct{}

// ecoMsg and sessionsMsg carry those samples back into Update.
type (
	ecoMsg      EcosystemSnapshot
	sessionsMsg []AgentSession
)

// cpuHistMax bounds the CPU sparkline history.
const cpuHistMax = 64

func tickBtop() tea.Cmd {
	return tea.Tick(sessionTickRate, func(time.Time) tea.Msg { return btopTickMsg{} })
}

func sampleEcosystemCmd() tea.Msg { return ecoMsg(sampleEcosystem()) }

func scanSessions(sc *sessionScanner) tea.Cmd {
	if sc == nil {
		return nil
	}
	return func() tea.Msg { return sessionsMsg(sc.Scan()) }
}

// withEco stores a process sample and appends it to the bounded CPU history.
func (m model) withEco(snap EcosystemSnapshot) model {
	if snap.NumCPU == 0 {
		return m
	}
	m.ecoSnap = snap
	m.cpuHist = append(m.cpuHist, snap.TotalAICPU)
	if n := len(m.cpuHist); n > cpuHistMax {
		m.cpuHist = append([]float64(nil), m.cpuHist[n-cpuHistMax:]...)
	}
	return m
}

// killProcess sends SIGTERM to a PID (indirected for deterministic unit testing).
var killProcess = func(pid int) error {
	return syscall.Kill(pid, syscall.SIGTERM)
}

// toolActions returns the 6 keyboard-accessible Control Centre actions ([1]..[6])
// for the given tool.
func toolActions(t tool) []controlAction {
	switch t.name {
	case "corralctl":
		return []controlAction{
			{key: "1", label: "Status", desc: "corralctl status ~/Code — live repo & dirty-tree audit", bin: "dot", args: []string{"ai", "corral", "status"}},
			{key: "2", label: "Sync Forge", desc: "corralctl sync — parallel multi-forge repository sync", bin: "dot", args: []string{"ai", "corral", "sync"}},
			{key: "3", label: "Finder Tags", desc: "corralctl doctor --refresh-tags — reconcile macOS tags", bin: "dot", args: []string{"ai", "corral", "doctor"}},
			{key: "4", label: "List Repos", desc: "corralctl --help — workspace & multi-forge CLI options", bin: "corralctl", args: []string{"--help"}},
			{key: "5", label: "MCP Bridge", desc: "corralctl mcp --help — inspect MCP workspace server", bin: "corralctl", args: []string{"mcp", "--help"}},
			{key: "6", label: "Version", desc: "corralctl --version — binary version & target", bin: "corralctl", args: []string{"--version"}},
		}
	case "passmcp":
		return []controlAction{
			{key: "1", label: "MCP Doctor", desc: "dot ai mcp doctor — audit MCP configs & 6 passmcp binaries", bin: "dot", args: []string{"ai", "mcp", "doctor"}},
			{key: "2", label: "9-Phase Check", desc: "passmcp check --help — 9-phase security & SARIF gate", bin: "passmcp", args: []string{"check", "--help"}},
			{key: "3", label: "Risk Graph", desc: "passmcp-graph --help — capability escalation & blast radius", bin: "passmcp-graph", args: []string{"--help"}},
			{key: "4", label: "SBOM Audit", desc: "passmcp sbom --help — CycloneDX 1.6 & SPDX 3.0.1 export", bin: "passmcp", args: []string{"sbom", "--help"}},
			{key: "5", label: "Cosign Attest", desc: "passmcp attest --help — Sigstore DSSE / SLSA v1.0 provenance", bin: "passmcp", args: []string{"attest", "--help"}},
			{key: "6", label: "Version", desc: "passmcp --version — toolchain version & build info", bin: "passmcp", args: []string{"--version"}},
		}
	case "draft":
		return []controlAction{
			{key: "1", label: "Pipeline Help", desc: "draft --help — 5-phase grounded research & C2PA synthesis", bin: "draft", args: []string{"--help"}},
			{key: "2", label: "Verify C2PA", desc: "draft verify --help — Ed25519 signature & citation check", bin: "draft", args: []string{"verify", "--help"}},
			{key: "3", label: "AI Doctor", desc: "dot ai doctor — fleet & provider health check", bin: "dot", args: []string{"ai", "doctor"}},
			{key: "4", label: "MCP Doctor", desc: "dot ai mcp doctor — inspect MCP retrieval servers", bin: "dot", args: []string{"ai", "mcp", "doctor"}},
			{key: "5", label: "Spend", desc: "dot ai cost — token spend by provider", bin: "dot", args: []string{"ai", "cost"}},
			{key: "6", label: "Version", desc: "draft --version — binary version & provenance support", bin: "draft", args: []string{"--version"}},
		}
	default:
		return []controlAction{
			{key: "1", label: "Version", desc: t.bin + " --version — inspect agent CLI version", bin: t.bin, args: []string{"--version"}},
			{key: "2", label: "AI Doctor", desc: "dot ai doctor — fleet & provider health check", bin: "dot", args: []string{"ai", "doctor"}},
			{key: "3", label: "Spend", desc: "dot ai cost — token spend by provider", bin: "dot", args: []string{"ai", "cost"}},
			{key: "4", label: "MCP Audit", desc: "dot ai mcp doctor — audit MCP servers & passmcp family", bin: "dot", args: []string{"ai", "mcp", "doctor"}},
			{key: "5", label: "Start Agent", desc: "dot ai chat " + t.name + " — launch interactive agent session", bin: "dot", args: []string{"ai", "chat", t.name}, interactive: true},
			{key: "6", label: "Inline Chat", desc: "Tab — focus inline prompt input in cockpit", focusInput: true},
		}
	}
}

// startActionCmd executes a non-interactive Control Centre action and captures
// its combined stdout/stderr into an actionResultMsg.
func startActionCmd(toolName string, act controlAction) tea.Cmd {
	return func() tea.Msg {
		c := execCommand(act.bin, act.args...)
		c.Env = append(os.Environ(), "DOT_AI_RAW=1", "NO_COLOR=1")
		out, err := c.CombinedOutput()
		text := strings.TrimSpace(clean(string(out)))
		return actionResultMsg{
			tool:   toolName,
			label:  act.label,
			output: text,
			err:    err,
		}
	}
}

// pendingKill is a SIGTERM armed by the first x and sent by a second x
// within killConfirmFor. identity (start time + program, from ps) is taken at
// arm time and re-checked before the signal, so a PID that exited and was
// reused by another program is never signalled.
type pendingKill struct {
	pid            int
	name, identity string
	deadline       time.Time
}

const killConfirmFor = 5 * time.Second

// procIdentity returns "<lstart> <comm>" for a PID, or "" if it is not running
// (indirected for tests).
var procIdentity = func(pid int) string {
	if pid <= 0 { // kill(0) would signal the whole process group
		return ""
	}
	out, err := exec.Command("ps", "-o", "lstart=,comm=", "-p", strconv.Itoa(pid)).Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

// identityComm extracts the program basename from a procIdentity value
// (lstart is five fields: "Sat Oct 18 09:00:00 2026").
func identityComm(id string) string {
	f := strings.Fields(id)
	if len(f) < 6 {
		return ""
	}
	return filepath.Base(strings.Join(f[5:], " "))
}

// terminateSelectedProcess handles x: the first press arms a SIGTERM for the
// selected tool's busiest process, a second press within killConfirmFor sends
// it. Only the selected tool's own processes are ever targeted.
func (m model) terminateSelectedProcess() (model, tea.Cmd) {
	if time.Now().Before(m.kill.deadline) { // zero when nothing is armed
		return m.confirmKill()
	}
	return m.armKill(), nil
}

func (m model) armKill() model {
	t := m.tools[m.cursor]
	m.kill = pendingKill{}
	var target *AIProcess
	for i, p := range m.ecoSnap.ActiveProcs { // sorted by CPU, busiest first
		if p.Name == t.bin || p.Name == t.name {
			target = &m.ecoSnap.ActiveProcs[i]
			break
		}
	}
	if target == nil {
		m.status = "no running " + t.name + " process — nothing to terminate"
		return m
	}
	id := procIdentity(target.PID)
	if identityComm(id) != target.Name {
		m.status = fmt.Sprintf("%s (PID %d) is no longer running — press r to refresh", target.Name, target.PID)
		return m
	}
	m.kill = pendingKill{pid: target.PID, name: target.Name, identity: id, deadline: time.Now().Add(killConfirmFor)}
	m.status = fmt.Sprintf("press x again within %ds to SIGTERM %s (PID %d) · any other key cancels",
		int(killConfirmFor.Seconds()), target.Name, target.PID)
	return m
}

func (m model) confirmKill() (model, tea.Cmd) {
	k := m.kill
	m.kill = pendingKill{}
	if procIdentity(k.pid) != k.identity {
		m.status = fmt.Sprintf("PID %d changed since it was selected — no signal sent", k.pid)
		return m, refresh
	}
	if err := killProcess(k.pid); err != nil {
		m.status = fmt.Sprintf("kill %s (%d): %v", k.name, k.pid, err)
		return m, nil
	}
	m.status = fmt.Sprintf("sent SIGTERM to %s (PID %d)", k.name, k.pid)
	return m, refresh
}

// renderBtopDeck renders a 3-line btop-style telemetry header box with a CPU
// sparkline, meter bars, CPU/MEM/PROC gauges and shortcut keycaps. Energy is
// not measured, so SCI reads n/a; the CPU sparkline is blank until sampled.
func (m model) renderBtopDeck() string {
	w := max(m.width-2, 38)
	snap := m.ecoSnap
	if snap.NumCPU == 0 {
		snap = sampleEcosystem()
	}
	cpuSpark := renderBrailleSparkline(m.cpuHist, 4)
	cpuBar := renderMeterBar(cpuBarPct(snap.TotalAICPU), 5)
	memMB := snap.TotalAIMemMB + snap.MemAllocMB
	memBar := renderMeterBar(min((memMB/1024.0)*100.0, 100.0), 5)

	topTitle := "─ " + keySt.Render("¹") + titleSt.Render("cpu/uma") +
		" ─ " + keySt.Render("²") + titleSt.Render("mem/rss") +
		" ─ " + keySt.Render("³") + titleSt.Render("proc") +
		" ─ " + keySt.Render("⁴") + titleSt.Render("sci") +
		" ── " + keySt.Render("[c]") + dimSt.Render("orral ") +
		keySt.Render("[v]") + dimSt.Render("passmcp ") +
		keySt.Render("[d]") + dimSt.Render("raft ") +
		keySt.Render("[x]") + dimSt.Render("kill ") +
		keySt.Render("[b]") + dimSt.Render("top ")
	topFill := max(w-lipgloss.Width(topTitle)-2, 1)
	line1 := " ╭" + ansi.Truncate(topTitle+strings.Repeat("─", topFill), w-2, "─") + "╮"

	row := fmt.Sprintf(" %s %s %s %.1f%% %dc │ %s %s %.0fMB │ %s %d │ %s %s │ Repo:%d MCP:%d ",
		keySt.Render("CPU"), okSt.Render(cpuSpark), okSt.Render(cpuBar), snap.TotalAICPU, snap.NumCPU,
		keySt.Render("MEM"), selSt.Render(memBar), memMB,
		keySt.Render("PROC"), len(snap.ActiveProcs),
		keySt.Render("SCI"), dimSt.Render("n/a"),
		snap.Corral.TotalRepos, snap.MCPServers)
	rowTrunc := ansi.Truncate(row, w-2, "…")
	rowPad := max((w-2)-lipgloss.Width(rowTrunc), 0)
	line2 := " │" + rowTrunc + strings.Repeat(" ", rowPad) + "│"
	line3 := " ╰" + strings.Repeat("─", max(w-2, 1)) + "╯"
	return line1 + "\n" + line2 + "\n" + line3
}

// renderControlHeader renders the 3-line Control Centre title bar and [1]..[6]
// interactive keycap action deck at the top of the right pane.
func (m model) renderControlHeader(w int) string {
	t := m.tools[m.cursor]
	actions := toolActions(t)
	sel := clampi(m.actionIdx, 0, len(actions)-1)

	state := offSt.Render(" ○ not installed ([i] install)")
	if t.installed {
		state = okSt.Render(" ● installed")
	}
	if n := m.ecoSnap.ToolProcs[t.bin]; n > 0 {
		state += selSt.Render(fmt.Sprintf(" · %d running", n))
	}
	roleTag := dimSt.Render(" · [" + t.group + " control centre]")
	hint := dimSt.Render("  ") + keySt.Render("←→/hl") + dimSt.Render(" select · ") +
		keySt.Render("1-6/⏎") + dimSt.Render(" run · ") + keySt.Render("x") + dimSt.Render(" kill · ") +
		keySt.Render("0") + dimSt.Render(" clear")
	line1 := ansi.Truncate(titleSt.Render(strings.ToUpper(t.name))+state+roleTag+hint, w, "…")

	var pills []string
	for i, a := range actions {
		kcap := "[" + a.key + "] " + a.label
		if i == sel {
			pills = append(pills, chipOK.Render(kcap))
		} else {
			pills = append(pills, keySt.Render("["+a.key+"]")+" "+bodySt.Render(a.label))
		}
	}
	line2 := ansi.Truncate(strings.Join(pills, dimSt.Render("  ")), w, "…")
	sep := dimSt.Render("── " + actions[sel].desc + " ")
	sepFill := max(w-lipgloss.Width(sep), 0)
	line3 := ansi.Truncate(sep+dimSt.Render(strings.Repeat("─", sepFill)), w, "─")
	return line1 + "\n" + line2 + "\n" + line3
}

// renderEcosystemControlCentre renders the dedicated btop Control Centre and
// live OS process table (proc) when the console transcript is empty.
func (m model) renderEcosystemControlCentre(w, h int) string {
	if h < 1 {
		h = 1
	}
	t := m.tools[m.cursor]
	snap := m.ecoSnap
	if snap.NumCPU == 0 {
		snap = sampleEcosystem()
	}
	var rows []string
	switch t.name {
	case "corralctl":
		rows = m.renderCorralCentre(snap)
	case "passmcp":
		rows = m.renderPassMCPCentre(snap)
	case "draft":
		rows = m.renderDraftCentre(snap)
	default:
		rows = m.renderAgentCentre(t, snap)
		if t.name == "claude" || t.name == "codex" {
			rows = append(rows, "")
			rows = append(rows, renderSessionRows(m.sessions, t.name, time.Now())...)
		}
	}
	rows = append(rows, "")
	rows = append(rows, m.renderProcTableRows(t, snap)...)
	for i := range rows {
		rows[i] = ansi.Truncate(rows[i], w, "…")
	}
	for len(rows) < h {
		rows = append(rows, "")
	}
	if len(rows) > h {
		rows = rows[:h]
	}
	return strings.Join(rows, "\n")
}

func (m model) renderAgentCentre(t tool, snap EcosystemSnapshot) []string {
	nProc := snap.ToolProcs[t.bin]
	var tCPU, tMem float64
	for _, p := range snap.ActiveProcs {
		if p.Name == t.bin || p.Name == t.name {
			tCPU += p.CPUPct
			tMem += p.MemMB
		}
	}
	cpuBar := renderMeterBar(min(tCPU, 100), 10)
	memBar := renderMeterBar(min((tMem/512.0)*100.0, 100), 10)
	return []string{
		titleSt.Render("╭─ ²agent control centre · " + strings.ToUpper(t.name) + " · [⏎/5] start session [1-4] probe [x] kill ─╮"),
		bodySt.Render(fmt.Sprintf("  Active Processes: %d   │   Model: %s   │   Gateway: %s   │   Spend Today: %s",
			nProc, modelLabel(m.aiModel), m.gatewayMsg, m.costToday)),
		okSt.Render("  CPU Load  ["+cpuBar+"] ") + bodySt.Render(fmt.Sprintf("%.1f%%   │   ", tCPU)) +
			selSt.Render("RSS Memory ["+memBar+"] ") + bodySt.Render(fmt.Sprintf("%.1f MB", tMem)),
		keySt.Render("  [⏎ / 5] Start Agent  ") + dimSt.Render("→ ") + bodySt.Render("dot ai chat "+t.name+" (launch interactive agent CLI)"),
		keySt.Render("  [1-4]   Quick Probes ") + dimSt.Render("→ ") + bodySt.Render("[1] Version · [2] AI Doctor · [3] Cost/SCI · [4] MCP Audit"),
		keySt.Render("  [x]     Terminate    ") + dimSt.Render("→ ") + bodySt.Render("send SIGTERM to running "+t.name+" process"),
	}
}

func (m model) renderProcTableRows(selected tool, snap EcosystemSnapshot) []string {
	rows := []string{
		titleSt.Render(fmt.Sprintf("╭─ ³proc · live AI agents, local LLMs & MCP servers (%d active · %.1f%% CPU · %.1f MB) ── [x] kill [r] refresh ─╮",
			len(snap.ActiveProcs), snap.TotalAICPU, snap.TotalAIMemMB)),
		groupSt.Render("   PID      PROGRAM          ROLE         CPU%      MEM(MB)   ELAPSED    BAR"),
	}
	if len(snap.ActiveProcs) == 0 {
		rows = append(rows, dimSt.Render("   (no active AI agent or MCP processes — press ⏎ to start "+selected.name+" or [1-6] to run a probe)"))
		return rows
	}
	for i, p := range snap.ActiveProcs {
		if i >= 6 {
			break
		}
		bar := renderMeterBar(min(p.CPUPct, 100), 6)
		line := fmt.Sprintf("%-8d %-16s %-12s %5.1f%%    %7.1f   %-10s %s",
			p.PID, p.Name, p.Role, p.CPUPct, p.MemMB, p.Elapsed, okSt.Render(bar))
		if p.Name == selected.bin || p.Name == selected.name {
			rows = append(rows, selSt.Render(" ▌ ")+selSt.Render(line))
		} else {
			rows = append(rows, "   "+bodySt.Render(line))
		}
	}
	return rows
}

func (m model) renderCorralCentre(snap EcosystemSnapshot) []string {
	c := snap.Corral
	tot := max(c.TotalRepos, 1)
	pBar := renderMeterBar((float64(c.Pristine)/float64(tot))*100, 10)
	fBar := renderMeterBar((float64(c.InFlight)/float64(tot))*100, 10)
	wBar := renderMeterBar((float64(c.Worktree)/float64(tot))*100, 10)
	nBar := renderMeterBar((float64(c.NeedsFix)/float64(tot))*100, 10)
	return []string{
		titleSt.Render("╭─ ²corralctl · multi-forge workspace & Finder tag control centre ─╮"),
		bodySt.Render(fmt.Sprintf("  Managed Repositories: %d   │   Forges: GitHub · GitLab · Codeberg · Gitea", c.TotalRepos)),
		okSt.Render("  🟢 Pristine   ["+pBar+"] ") + bodySt.Render(fmt.Sprintf("%d repos (clean working tree, synced)", c.Pristine)),
		selSt.Render("  🟡 In-Flight  ["+fBar+"] ") + bodySt.Render(fmt.Sprintf("%d repos (uncommitted / ahead of remote)", c.InFlight)),
		keySt.Render("  🟣 Worktree   ["+wBar+"] ") + bodySt.Render(fmt.Sprintf("%d repos (active git worktree linked)", c.Worktree)),
		errSt.Render("  🔴 Needs-Fix  ["+nBar+"] ") + bodySt.Render(fmt.Sprintf("%d repos (conflict / failing hook)", c.NeedsFix)),
		keySt.Render("  [1] Status  [2] Sync Forge  [3] Finder Tags  [4] List Repos  [5] MCP Bridge  [6] Version"),
	}
}

func (m model) renderPassMCPCentre(snap EcosystemSnapshot) []string {
	var bins []string
	for _, b := range passmcpFamily {
		if _, err := exec.LookPath(b); err == nil {
			bins = append(bins, okSt.Render("● "+b))
		} else {
			bins = append(bins, offSt.Render("○ "+b))
		}
	}
	pct := (float64(snap.PassMCPReady) / float64(len(passmcpFamily))) * 100.0
	bar := renderMeterBar(pct, 12)
	return []string{
		titleSt.Render("╭─ ²passmcp · 9-repo MCP security & capability risk control centre ─╮"),
		bodySt.Render(fmt.Sprintf("  Toolchain Readiness: [%s] %d/%d binaries   │   Configured MCP Servers: %d",
			okSt.Render(bar), snap.PassMCPReady, len(passmcpFamily), snap.MCPServers)),
		"  " + strings.Join(bins[:3], "   "),
		"  " + strings.Join(bins[3:], "   "),
		okSt.Render("  ● 9-Phase Security & Risk Graph: ") + bodySt.Render("OWASP MCP Top 10 · CVSS v4.0 · Toxic-Pair & SEP-1649 Gate"),
		keySt.Render("  [1] MCP Doctor  [2] 9-Phase Check  [3] Risk Graph  [4] SBOM Audit  [5] Cosign Attest  [6] Version"),
	}
}

func (m model) renderDraftCentre(snap EcosystemSnapshot) []string {
	greenBadge := offSt.Render("not available (needs ollama and draft)")
	if snap.Draft.GreenSplit {
		greenBadge = okSt.Render("available · dot ai draft --green")
	}
	return []string{
		titleSt.Render("╭─ ²draft · 5-phase grounded research & C2PA control centre ────────╮"),
		bodySt.Render("  Pipeline:  [1.Decompose] → [2.Retrieve] → [3.Extract] → [4.Synthesize] → [5.Verify]"),
		okSt.Render("  ● C2PA Provenance     ") + bodySt.Render("Ed25519-signed Content Credentials · ≥95% Claim Gate"),
		okSt.Render("  ● Green Split-Stage   ") + greenBadge,
		dimSt.Render("  ● Energy & carbon     n/a — not measured"),
		keySt.Render("  [1] Pipeline Help  [2] Verify C2PA  [3] AI Doctor  [4] MCP Doctor  [5] Spend  [6] Version"),
	}
}
