// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// render.go — View, btop telemetry strip, syntax highlighting, splash screen,
// transcript layout, and snapshot rendering for dot-ai-tui.
package main

import (
	"fmt"
	"os"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"

	"github.com/alecthomas/chroma/v2/lexers"
	"github.com/alecthomas/chroma/v2/quick"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/charmbracelet/x/ansi"
)

// highlightCode is the chroma entry point, indirected so the (otherwise
// unreachable) formatter-failure fallback in highlight can be tested.
var highlightCode = quick.Highlight

// maxHighlightFences bounds Chroma invocations per render.
const maxHighlightFences = 64

// langRe bounds a fence info string to a short identifier.
var langRe = regexp.MustCompile(`^[A-Za-z0-9_+#.-]{1,32}$`)

var (
	langCache    sync.Map
	langCacheN   atomic.Int32
	langCacheMax = int32(64)
)

// resolveLang maps a fence info string to a chroma lexer name, or "" when
// the tag is malformed/unknown.
func resolveLang(lang string) string {
	if !langRe.MatchString(lang) {
		return ""
	}
	if v, ok := langCache.Load(lang); ok {
		return v.(string)
	}
	name := ""
	if l := lexers.Get(lang); l != nil {
		name = l.Config().Name
	}
	if langCacheN.Load() < langCacheMax {
		if _, loaded := langCache.LoadOrStore(lang, name); !loaded {
			langCacheN.Add(1)
		}
	}
	return name
}

// highlight syntax-colours fenced ``` code blocks with chroma.
func highlight(text string) string {
	if !strings.Contains(text, "```") || strings.Count(text, "```") > maxHighlightFences {
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
		if err := highlightCode(&hb, code, resolveLang(lang), "terminal256", "github-dark"); err == nil {
			b.WriteString(hb.String())
		} else {
			b.WriteString(code)
		}
	}
	return b.String()
}

func (m model) leftWidth() int {
	return clampi(m.width/4, 18, 26)
}

func (m model) rightWidth() int { return m.width - m.leftWidth() - 5 }

func (m model) renderHeader() string {
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
	if m.greenMode {
		left += " " + okSt.Render("● green")
	}
	right := gw + " " + chipCost.Render("today "+m.costToday)
	gap := max(m.width-lipgloss.Width(left)-lipgloss.Width(right)-2, 1)
	return " " + left + strings.Repeat(" ", gap) + right
}

func (m model) toolShortcutBadge(t tool) string {
	var b string
	if n := m.ecoSnap.ToolProcs[t.bin]; n > 0 {
		b += " " + okSt.Render(fmt.Sprintf("(%d)", n))
	}
	switch t.name {
	case "corralctl":
		return b + " " + keySt.Render("[c]")
	case "passmcp":
		return b + " " + keySt.Render("[v]")
	case "draft":
		return b + " " + keySt.Render("[d]")
	default:
		return b
	}
}

func (m model) renderLeftPane(bodyH int) string {
	var rows []string
	cursorRow, lastGroup := 0, ""
	for i, t := range m.tools {
		if t.group != lastGroup {
			hdr := strings.ToUpper(t.group)
			if t.group == "ecosystem" {
				hdr += " [c/v/d]"
			}
			rows = append(rows, groupSt.Render(hdr))
			lastGroup = t.group
		}
		dot := offSt.Render("○")
		if t.installed {
			dot = okSt.Render("●")
		}
		badge := m.toolShortcutBadge(t)
		if i == m.cursor {
			cursorRow = len(rows)
			rows = append(rows, selSt.Render("▌")+dot+" "+selSt.Render(t.name)+badge)
		} else {
			rows = append(rows, " "+dot+" "+bodySt.Render(t.name)+badge)
		}
	}
	rows = windowRows(rows, cursorRow, bodyH)
	leftStyle := panel
	if m.focus == "fleet" {
		leftStyle = panelHot
	}
	return leftStyle.Width(m.leftWidth()).Height(bodyH).Render(strings.Join(rows, "\n"))
}

func (m model) renderRightPane(bodyH int) string {
	t := m.tools[m.cursor]
	rw := m.rightWidth()
	var cb strings.Builder
	pal := m.palette()
	if len(pal) > 8 {
		pal = pal[:8]
	}
	if bodyH >= 12 && os.Getenv("DOT_AI_SPLASH") == "" {
		cb.WriteString(m.renderControlHeader(rw-2) + "\n")
		cb.WriteString(m.renderTranscript(rw-2, bodyH-6-len(pal)) + "\n")
	} else {
		cb.WriteString(titleSt.Render(strings.ToUpper(t.name)))
		state := offSt.Render(" not installed — i to install")
		if t.installed {
			state = dimSt.Render(" · ready")
		}
		cb.WriteString(state + "\n\n")
		cb.WriteString(m.renderTranscript(rw-2, bodyH-5-len(pal)) + "\n")
	}
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
	return rightStyle.Width(rw).Height(bodyH).Render(cb.String())
}

func (m model) View() string {
	if m.width < 40 || m.height < 12 || len(m.tools) == 0 {
		return "  loading dot ai…"
	}
	header := m.renderHeader()
	showBtop := m.height >= 20 && !m.hideBtop && os.Getenv("DOT_AI_SPLASH") == ""
	bodyH := m.height - 5
	if showBtop {
		bodyH = m.height - 8
	}
	body := lipgloss.JoinHorizontal(lipgloss.Top, m.renderLeftPane(bodyH), m.renderRightPane(bodyH))

	var keys []struct{ k, d string }
	if m.focus == "input" {
		keys = []struct{ k, d string }{
			{"⏎", "send"}, {"/help", "cmds"}, {"esc", "fleet"}, {"/exit", "quit"},
		}
	} else {
		keys = []struct{ k, d string }{
			{"↑↓", "tool"}, {"←→", "action"}, {"1-6/⏎", "start/run"}, {"x", "kill"},
			{"c/v/d", "eco"}, {"b", "btop"}, {"g", "green"}, {"m", "model"},
			{"s", "serve"}, {"r", "refresh"}, {"i", "install"}, {"tab", "chat"}, {"q", "quit"},
		}
	}
	var fbar strings.Builder
	for i, kv := range keys {
		if i > 0 {
			fbar.WriteString(keyDesc.Render(" · "))
		}
		fbar.WriteString(keySt.Render(kv.k) + " " + keyDesc.Render(kv.d))
	}
	footer := " " + fbar.String()
	if m.status != "" {
		footer = " " + dimSt.Render(m.status) + footer
	}
	footer = ansi.Truncate(footer, m.width, "…")
	if showBtop {
		return strings.Join([]string{header, m.renderBtopDeck(), body, footer}, "\n")
	}
	return strings.Join([]string{header, body, footer}, "\n")
}

// windowRows returns at most h rows from rows, scrolled so cursor is visible.
func windowRows(rows []string, cursor, h int) []string {
	if h < 1 {
		h = 1
	}
	if len(rows) <= h {
		return rows
	}
	start := clampi(cursor-h/2, 0, len(rows)-h)
	return rows[start : start+h]
}

var logoArt = []string{
	"█▀▄ █▀█ ▀█▀   █▀█ █",
	"█░█ █░█  █    █▀█ █",
	"▀▀░ ▀▀▀  ▀    ▀░▀ ▀",
}

func (m model) splash(w, h int) string {
	if h < 0 {
		h = 0
	}
	c := func(s string) string { return lipgloss.PlaceHorizontal(w, lipgloss.Center, s) }
	grad := []lipgloss.Color{violet, mauve, pink}
	var b []string
	b = append(b, "", c(selSt.Render("◆")), "")
	for i, ln := range logoArt {
		b = append(b, c(lipgloss.NewStyle().Foreground(grad[i]).Bold(true).Render(ln)))
	}
	b = append(b,
		"",
		c(tagSt.Render("the cockpit for your AI fleet")),
		c(dimSt.Render("one subscription · every agent · zero keys")),
		"",
		c(keySt.Render("⏎")+dimSt.Render(" open session    ")+
			keySt.Render("type")+dimSt.Render(" to chat    ")+
			keySt.Render("/")+dimSt.Render(" commands")),
	)
	for i := 0; len(b) < h; i++ {
		if i%2 == 0 {
			b = append([]string{""}, b...)
		} else {
			b = append(b, "")
		}
	}
	if len(b) > h {
		b = b[:h]
	}
	return strings.Join(b, "\n")
}

func (m model) renderTranscript(w, h int) string {
	if h < 1 {
		h = 1
	}
	if len(m.transcript) == 0 {
		return m.renderEmptyTranscript(w, h)
	}
	var lines []string
	for _, l := range m.transcript {
		lines = append(lines, renderTranscriptLine(l, w)...)
	}
	if anyMultiline(lines) {
		flat := make([]string, 0, len(lines)+1)
		for _, ln := range lines {
			flat = append(flat, strings.Split(ln, "\n")...)
		}
		lines = flat
	}
	if len(lines) > h {
		lines = lines[len(lines)-h:]
	}
	for len(lines) < h {
		lines = append([]string{""}, lines...)
	}
	return strings.Join(lines, "\n")
}

func (m model) renderEmptyTranscript(w, h int) string {
	isEco := m.cursor >= 0 && m.cursor < len(m.tools) && m.tools[m.cursor].group == "ecosystem"
	if (m.refreshed || isEco) && os.Getenv("DOT_AI_SPLASH") == "" {
		return m.renderEcosystemControlCentre(w, h)
	}
	var rec []string
	if len(m.recent) > 0 {
		rec = append(rec, dimSt.Render("recent"))
		for i, r := range m.recent {
			if i >= 3 {
				break
			}
			rec = append(rec, dimSt.Render("  "+r))
		}
	}
	if len(rec) >= h {
		rec = nil
	}
	sp := m.splash(w, h-len(rec))
	if len(rec) > 0 {
		return sp + "\n" + strings.Join(rec, "\n")
	}
	return sp
}

func renderTranscriptLine(l line, w int) []string {
	var tag, content string
	hasCode := false
	switch l.who {
	case "you":
		tag, content = youSt.Render("you ▸ "), bodySt.Render(l.text)
	case "sys":
		tag, content = dimSt.Render("· "), dimSt.Render(l.text)
	default:
		tag, content = botSt.Render(l.who+" ▸ "), highlight(l.text)
		if strings.HasPrefix(l.text, errPrefix) {
			tag, content = errSt.Render(l.who+" ▸ "), errSt.Render(l.text)
		}
		hasCode = strings.Contains(l.text, "```")
	}
	if hasCode {
		var out []string
		for i, ln := range strings.Split(content, "\n") {
			if i == 0 {
				ln = tag + ln
			}
			out = append(out, ansi.Truncate(ln, w, "…"))
		}
		return out
	}
	wrapped := lipgloss.NewStyle().Width(w).Render(tag + content)
	return strings.Split(wrapped, "\n")
}

func anyMultiline(lines []string) bool {
	for _, ln := range lines {
		if strings.Contains(ln, "\n") {
			return true
		}
	}
	return false
}

// envInt reads a positive integer from the environment, else def.
func envInt(name string, def int) int {
	if n, err := strconv.Atoi(os.Getenv(name)); err == nil && n > 0 {
		return n
	}
	return def
}

// renderSnapshot prints one frame (DOT_AI_SNAPSHOT=1), sized from COLUMNS and
// LINES when set, else 100x28.
func renderSnapshot() {
	m := newModel()
	mm, _ := m.Update(tea.WindowSizeMsg{Width: envInt("COLUMNS", 100), Height: envInt("LINES", 28)})
	m = mm.(model)
	m.sessions = m.scanner.Scan()
	if r, ok := refresh().(refreshMsg); ok {
		mm, _ = m.Update(r)
		m = mm.(model)
	}
	if want := os.Getenv("DOT_AI_TOOL"); want != "" {
		mm, _ = m.jumpToTool(want)
		m = mm.(model)
		fmt.Println(m.View())
		return
	}
	m.transcript = []line{
		{who: "you", text: "show me a typed fetch wrapper"},
		{who: "claude", text: "Here's a small typed wrapper:\n```ts\nexport async function getJSON<T>(url: string): Promise<T> {\n  const r = await fetch(url);\n  if (!r.ok) throw new Error(r.statusText);\n  return r.json();\n}\n```\nCall it with `getJSON<User>(\"/api/me\")`."},
	}
	m.style = "architect"
	m.focus = "input"
	if os.Getenv("DOT_AI_SPLASH") != "" {
		m.transcript = nil
	} else {
		m.input.SetValue("/")
	}
	fmt.Println(m.View())
}
