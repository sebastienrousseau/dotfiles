package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/charmbracelet/bubbles/progress"
	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/table"
	"github.com/charmbracelet/bubbles/viewport"
	"github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

type check struct {
	index    int
	name     string
	status   string // "running", "pass", "warn", "fail"
	msg      string
	checkCmd tea.Cmd
}

type model struct {
	spinner     spinner.Model
	table       table.Model
	progress    progress.Model
	viewport    viewport.Model
	checking    bool
	checks      []check
	done        int
	checkWidth  int
	statusWidth int
	msgWidth    int
}

var (
	titleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("#00BFFF"))

	baseStyle = lipgloss.NewStyle().
			BorderStyle(lipgloss.NormalBorder()).
			BorderForeground(lipgloss.Color("240"))
)

func (m model) Init() tea.Cmd {
	return tea.Batch(m.spinner.Tick, runChecks(m.checks))
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmd tea.Cmd
	var cmds []tea.Cmd
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c":
			return m, tea.Quit
		case "r":
			m.checking = true
			m.done = 0
			m.table.SetRows([]table.Row{})
			return m, runChecks(m.checks)
		}
	case tea.WindowSizeMsg:
		m.checkWidth = msg.Width / 4
		m.statusWidth = msg.Width / 10
		m.msgWidth = msg.Width - m.checkWidth - m.statusWidth - 10
		m.table.SetColumns([]table.Column{
			{Title: "Check", Width: m.checkWidth},
			{Title: "Status", Width: m.statusWidth},
			{Title: "Details", Width: m.msgWidth},
		})
		m.viewport.Width = msg.Width
		m.viewport.Height = msg.Height - 10
		m.progress.Width = msg.Width - 4
		return m, nil

	case spinner.TickMsg:
		if m.checking {
			m.spinner, cmd = m.spinner.Update(msg)
		}
		return m, cmd

	case check:
		m.done++
		m.checks[msg.index].status = msg.status
		m.checks[msg.index].msg = msg.msg
		m.table.SetRows(toRows(m.checks))
		progressCmd := m.progress.SetPercent(float64(m.done) / float64(len(m.checks)))
		cmds = append(cmds, progressCmd)
		if m.done == len(m.checks) {
			cmds = append(cmds, func() tea.Msg { return checksFinished{} })
		}
		return m, tea.Batch(cmds...)

	case checksFinished:
		m.checking = false
		return m, nil
	case progress.FrameMsg:
		progressModel, cmd := m.progress.Update(msg)
		m.progress = progressModel.(progress.Model)
		return m, cmd
	}
	m.viewport, cmd = m.viewport.Update(msg)
	cmds = append(cmds, cmd)
	return m, tea.Batch(cmds...)
}

func (m model) View() string {
	if m.checking {
		return fmt.Sprintf("%s Running checks... %d/%d\n\n%s", m.spinner.View(), m.done, len(m.checks), m.progress.View())
	}

	return m.viewport.View()
}

type checksFinished struct{}

func runChecks(checks []check) tea.Cmd {
	var cmds []tea.Cmd
	for i := range checks {
		cmds = append(cmds, checks[i].checkCmd)
	}
	return tea.Batch(cmds...)
}

func checkCmd(index int, name string, cmd string, args ...string) tea.Cmd {
	return func() tea.Msg {
		c := exec.Command(cmd, args...)
		out, err := c.CombinedOutput()
		if err != nil {
			return check{index: index, name: name, status: "fail", msg: err.Error()}
		}
		return check{index: index, name: name, status: "pass", msg: strings.TrimSpace(string(out))}
	}
}

func toRows(checks []check) []table.Row {
	var rows []table.Row
	for _, c := range checks {
		var status string
		switch c.status {
		case "running":
			status = "..."
		case "pass":
			status = "✓"
		case "fail":
			status = "✗"
		case "warn":
			status = "⚠"
		}
		rows = append(rows, table.Row{c.name, status, c.msg})
	}
	return rows
}

func main() {
	checks := []check{
		{name: "Chezmoi installed"},
		{name: "Git installed"},
		{name: "Zsh installed"},
		{name: "Node.js"},
		{name: "Python"},
		{name: "Rust"},
		{name: "Go"},
		{name: "fzf"},
		{name: "ripgrep"},
		{name: "fd"},
		{name: "bat"},
	}
	for i := range checks {
		checks[i].status = "running"
		checks[i].index = i
		switch checks[i].name {
		case "Chezmoi installed":
			checks[i].checkCmd = checkCmd(i, checks[i].name, "chezmoi", "--version")
		case "Git installed":
			checks[i].checkCmd = checkCmd(i, checks[i].name, "git", "--version")
		case "Zsh installed":
			checks[i].checkCmd = checkCmd(i, checks[i].name, "zsh", "--version")
		case "Node.js":
			checks[i].checkCmd = checkCmd(i, checks[i].name, "node", "--version")
		case "Python":
			checks[i].checkCmd = checkCmd(i, checks[i].name, "python3", "--version")
		case "Rust":
			checks[i].checkCmd = checkCmd(i, checks[i].name, "rustc", "--version")
		case "Go":
			checks[i].checkCmd = checkCmd(i, checks[i].name, "go", "version")
		case "fzf":
			checks[i].checkCmd = checkCmd(i, checks[i].name, "fzf", "--version")
		case "ripgrep":
			checks[i].checkCmd = checkCmd(i, checks[i].name, "rg", "--version")
		case "fd":
			checks[i].checkCmd = checkCmd(i, checks[i].name, "fd", "--version")
		case "bat":
			checks[i].checkCmd = checkCmd(i, checks[i].name, "bat", "--version")
		}
	}

	columns := []table.Column{
		{Title: "Check", Width: 20},
		{Title: "Status", Width: 10},
		{Title: "Details", Width: 50},
	}

	rows := toRows(checks)

	t := table.New(
		table.WithColumns(columns),
		table.WithRows(rows),
		table.WithFocused(true),
		table.WithHeight(len(checks)),
	)

	s := spinner.New()
	s.Spinner = spinner.Dot
	s.Style = lipgloss.NewStyle().Foreground(lipgloss.Color("205"))

	m := model{
		spinner:  s,
		table:    t,
		checking: true,
		checks:   checks,
		progress: progress.New(progress.WithDefaultGradient()),
		viewport: viewport.New(100, 20),
	}
	m.viewport.SetContent(baseStyle.Render(m.table.View()))

	p := tea.NewProgram(m, tea.WithAltScreen())

	if _, err := p.Run(); err != nil {
		fmt.Printf("Alas, there's been an error: %v", err)
		os.Exit(1)
	}
}
