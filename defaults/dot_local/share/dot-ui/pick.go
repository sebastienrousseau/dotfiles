// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// `dot-ui pick` — a themed, fuzzy-filterable list picker.
//
// Reads candidate lines on stdin (one row per line), shows an interactive
// list rendered to /dev/tty (so stdout stays clean for capture), and prints
// the selected line to stdout on Enter. Exits non-zero on cancel (Esc/Ctrl-C)
// with no output, so callers can `sel=$(… | dot-ui pick) || fallback`.
//
// Flags: --header <text>, --prompt <text>. DOT_UI_SNAPSHOT renders one frame.
package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

type pickModel struct {
	header, prompt string
	all            []string
	filtered       []string
	query          string
	cursor         int
	offset         int
	selected       string
	cancelled      bool
	st             Styles
	height         int
}

func newPickModel(st Styles, header, prompt string, items []string) pickModel {
	return pickModel{
		header:   header,
		prompt:   prompt,
		all:      items,
		filtered: items,
		st:       st,
		height:   15,
	}
}

// fuzzyMatch reports whether all runes of query appear in s in order
// (case-insensitive subsequence) — the same feel as fzf.
func fuzzyMatch(s, query string) bool {
	if query == "" {
		return true
	}
	s = strings.ToLower(s)
	q := strings.ToLower(query)
	i := 0
	for _, r := range s {
		if i < len(q) && rune(q[i]) == r {
			i++
		}
	}
	return i == len(q)
}

func (m *pickModel) refilter() {
	m.filtered = m.filtered[:0]
	for _, it := range m.all {
		if fuzzyMatch(it, m.query) {
			m.filtered = append(m.filtered, it)
		}
	}
	m.cursor = 0
	m.offset = 0
}

func (m pickModel) Init() tea.Cmd { return nil }

func (m pickModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.height = msg.Height
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "esc":
			m.cancelled = true
			return m, tea.Quit
		case "enter":
			if len(m.filtered) > 0 {
				m.selected = m.filtered[m.cursor]
			} else {
				m.cancelled = true
			}
			return m, tea.Quit
		case "up", "ctrl+p":
			if m.cursor > 0 {
				m.cursor--
			}
		case "down", "ctrl+n":
			if m.cursor < len(m.filtered)-1 {
				m.cursor++
			}
		case "backspace":
			if m.query != "" {
				m.query = m.query[:len(m.query)-1]
				m.refilter()
			}
		default:
			if len(msg.Runes) == 1 {
				m.query += string(msg.Runes)
				m.refilter()
			}
		}
	}
	m.clampScroll()
	return m, nil
}

// visibleRows is how many list rows fit below the header + prompt.
func (m pickModel) visibleRows() int {
	n := m.height - 4
	if n < 3 {
		n = 3
	}
	if n > 20 {
		n = 20
	}
	return n
}

func (m *pickModel) clampScroll() {
	rows := m.visibleRows()
	if m.cursor < m.offset {
		m.offset = m.cursor
	}
	if m.cursor >= m.offset+rows {
		m.offset = m.cursor - rows + 1
	}
}

func (m pickModel) View() string {
	var b strings.Builder
	if m.header != "" {
		b.WriteString("  " + m.st.Sub.Render(m.header) + "\n")
	}
	prompt := m.prompt
	if prompt == "" {
		prompt = "›"
	}
	b.WriteString("  " + m.st.Spin.Render(prompt) + " " + m.st.Label.Render(m.query) +
		m.st.Detail.Render("▏") + "\n")

	rows := m.visibleRows()
	end := m.offset + rows
	if end > len(m.filtered) {
		end = len(m.filtered)
	}
	for i := m.offset; i < end; i++ {
		cursor := "  "
		style := m.st.Label
		if i == m.cursor {
			cursor = m.st.Ok.Render("▸") + " "
			style = lipgloss.NewStyle().Bold(true).Foreground(m.st.Spin.GetForeground())
		}
		b.WriteString("  " + cursor + style.Render(strings.TrimSpace(m.filtered[i])) + "\n")
	}
	if len(m.filtered) == 0 {
		b.WriteString("  " + m.st.Detail.Render("no matches") + "\n")
	}
	b.WriteString("  " + m.st.Detail.Render(fmt.Sprintf("%d/%d · ↑↓ move · enter select · esc cancel",
		len(m.filtered), len(m.all))) + "\n")
	return b.String()
}

func readItems(in io.Reader) []string {
	var items []string
	sc := bufio.NewScanner(in)
	sc.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	for sc.Scan() {
		if strings.TrimSpace(sc.Text()) != "" {
			items = append(items, sc.Text())
		}
	}
	return items
}

// Pick outcomes — distinct so the bash caller can tell an intentional cancel
// (done, no selection) from an inability to run (fall back to fzf/gum).
const (
	pickSelected  = 0
	pickCancelled = 1
	pickNoTTY     = 2
)

// runPick reads items from `in`, drives the picker on `tty`, and returns the
// selected line plus an outcome code. Snapshot / no-TTY yield pickNoTTY.
func runPick(st Styles, header, prompt string, in io.Reader, tty *os.File, snapshot bool) (string, int) {
	items := readItems(in)
	m := newPickModel(st, header, prompt, items)
	if snapshot || tty == nil {
		return "", pickNoTTY // non-interactive: caller falls back
	}
	p := tea.NewProgram(m, tea.WithInput(tty), tea.WithOutput(tty))
	res, err := p.Run()
	if err != nil {
		return "", pickNoTTY
	}
	fm := res.(pickModel)
	if fm.cancelled || fm.selected == "" {
		return "", pickCancelled
	}
	return fm.selected, pickSelected
}
