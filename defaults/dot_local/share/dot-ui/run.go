// `dot-ui run` — the step-runner view.
//
// Reads an NDJSON event stream on stdin and renders an inline (no alt-screen)
// live checklist: a braille spinner on running steps that flips to ✓/·/✗ on
// completion, an optional progress bar, and a final summary. Keyboard input is
// read from /dev/tty so stdin stays dedicated to the event stream.
//
// Event shapes (one JSON object per line):
//
//	{"t":"header","title":"dot theme","subtitle":"pulse"}
//	{"t":"step","id":"ghostty","label":"Ghostty","state":"run","detail":"reloading…"}
//	{"t":"step","id":"ghostty","state":"ok","detail":"reloaded"}   // ok|skip|fail|na
//	{"t":"progress","cur":3,"total":12}
//	{"t":"wait","label":"refreshing all Spaces…"}
//	{"t":"done","elapsed_ms":1618,"summary":"reloaded desktop, wallpaper"}
//
// A "na" step is dropped entirely (OS-aware filtering on the emitter side).
package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"strings"
	"time"

	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// Event is the union of all NDJSON event fields.
type Event struct {
	T         string `json:"t"`
	Title     string `json:"title,omitempty"`
	Subtitle  string `json:"subtitle,omitempty"`
	ID        string `json:"id,omitempty"`
	Label     string `json:"label,omitempty"`
	State     string `json:"state,omitempty"`
	Detail    string `json:"detail,omitempty"`
	Cur       int    `json:"cur,omitempty"`
	Total     int    `json:"total,omitempty"`
	ElapsedMs int64  `json:"elapsed_ms,omitempty"`
	Summary   string `json:"summary,omitempty"`
}

// parseEvent decodes one NDJSON line. Blank lines yield ok=false.
func parseEvent(line string) (Event, bool) {
	line = strings.TrimSpace(line)
	if line == "" {
		return Event{}, false
	}
	var e Event
	if err := json.Unmarshal([]byte(line), &e); err != nil {
		return Event{}, false
	}
	return e, true
}

type step struct {
	id, label, state, detail string
}

// Bubble Tea messages.
type eventMsg Event
type streamDoneMsg struct{} // stdin reached EOF

// stepModel is the run view model.
type stepModel struct {
	title, subtitle string
	steps           []step
	index           map[string]int // step id -> position
	cur, total      int            // progress
	wait            string         // transient indeterminate line
	done            bool
	summary         string
	elapsedMs       int64
	labelW          int
	sp              spinner.Model
	st              Styles
	width           int
}

func newStepModel(st Styles) stepModel {
	sp := spinner.New()
	sp.Spinner = spinner.Spinner{
		Frames: []string{"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"},
		FPS:    time.Second / 12,
	}
	sp.Style = st.Spin
	return stepModel{index: map[string]int{}, sp: sp, st: st, width: 80}
}

func (m stepModel) Init() tea.Cmd { return m.sp.Tick }

// apply folds an event into the model. Extracted from Update so snapshot mode
// (which has no Bubble Tea loop) can reuse the exact same reducer.
func (m *stepModel) apply(e Event) {
	switch e.T {
	case "header":
		m.title, m.subtitle = e.Title, e.Subtitle
	case "step":
		m.wait = ""
		if i, ok := m.index[e.ID]; ok {
			// Update in place — including run→na, which hides the step.
			if e.Label != "" {
				m.steps[i].label = e.Label
			}
			if e.State != "" {
				m.steps[i].state = e.State
			}
			if e.Detail != "" {
				m.steps[i].detail = e.Detail
			}
		} else {
			if e.State == "na" { // never-applicable, never shown
				return
			}
			s := step{id: e.ID, label: e.Label, state: e.State, detail: e.Detail}
			if s.state == "" {
				s.state = "run"
			}
			m.index[e.ID] = len(m.steps)
			m.steps = append(m.steps, s)
		}
		if e.State != "na" {
			if w := lipgloss.Width(e.Label); w > m.labelW {
				m.labelW = w
			}
		}
	case "progress":
		m.cur, m.total = e.Cur, e.Total
	case "wait":
		m.wait = e.Label
	case "done":
		m.done = true
		m.summary = e.Summary
		m.elapsedMs = e.ElapsedMs
		m.wait = ""
	}
}

func (m stepModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		if msg.String() == "ctrl+c" {
			return m, tea.Quit
		}
	case eventMsg:
		e := Event(msg)
		m.apply(e)
		if m.done {
			return m, tea.Quit
		}
		return m, nil
	case streamDoneMsg:
		// Emitter closed the stream without an explicit done — finish anyway.
		if !m.done {
			m.done = true
		}
		return m, tea.Quit
	case spinner.TickMsg:
		var cmd tea.Cmd
		m.sp, cmd = m.sp.Update(msg)
		return m, cmd
	}
	return m, nil
}

func (m stepModel) View() string {
	var b strings.Builder
	// Header
	if m.title != "" {
		b.WriteString("\n  ")
		b.WriteString(m.st.Logo.Render(m.title))
		if m.subtitle != "" {
			b.WriteString(" ")
			b.WriteString(m.st.Sub.Render("· " + m.subtitle))
		}
		b.WriteString("\n\n")
	}
	// Steps
	for _, s := range m.steps {
		if s.state == "na" { // resolved not-applicable — hidden
			continue
		}
		b.WriteString(m.renderStep(s))
		b.WriteString("\n")
	}
	// Transient wait line
	if m.wait != "" {
		b.WriteString(fmt.Sprintf("  %s  %s\n", m.sp.View(), m.st.Detail.Render(m.wait)))
	}
	// Progress bar
	if m.total > 0 && !m.done {
		b.WriteString("\n  " + m.renderBar() + "\n")
	}
	// Summary
	if m.done {
		b.WriteString("\n  ")
		if m.summary != "" {
			label := "Done"
			if m.elapsedMs > 0 {
				label = fmt.Sprintf("Done in %dms", m.elapsedMs)
			}
			b.WriteString(m.st.Summary.Render(label))
			b.WriteString(" ")
			b.WriteString(m.st.Detail.Render("· " + m.summary))
		} else {
			b.WriteString(m.st.Summary.Render("Done"))
		}
		b.WriteString("\n")
	}
	return b.String()
}

func (m stepModel) renderStep(s step) string {
	var sym string
	switch s.state {
	case "ok":
		sym = m.st.Ok.Render("✓")
	case "skip":
		sym = m.st.Skip.Render("·")
	case "fail":
		sym = m.st.Fail.Render("✗")
	case "warn":
		sym = m.st.Warn.Render("⚠")
	default: // run
		sym = m.sp.View()
	}
	label := lipgloss.NewStyle().Width(m.labelW + 2).Render(m.st.Label.Render(s.label))
	line := fmt.Sprintf("  %s  %s", sym, label)
	if s.detail != "" {
		line += m.st.Detail.Render(s.detail)
	}
	return strings.TrimRight(line, " ")
}

func (m stepModel) renderBar() string {
	const w = 24
	filled := 0
	if m.total > 0 {
		filled = m.cur * w / m.total
	}
	if filled > w {
		filled = w
	}
	bar := m.st.BarFull.Render(strings.Repeat("━", filled)) +
		m.st.BarRest.Render(strings.Repeat("━", w-filled))
	return fmt.Sprintf("%s  %s", bar, m.st.Detail.Render(fmt.Sprintf("%d/%d", m.cur, m.total)))
}

// runStep executes the run view. When interactive is false (no /dev/tty), it
// falls back to snapshot rendering so it still produces useful output.
func runStep(st Styles, in io.Reader, tty io.Reader, out io.Writer, interactive bool) error {
	if !interactive {
		return snapshotStep(st, in, out)
	}
	m := newStepModel(st)
	opts := []tea.ProgramOption{tea.WithOutput(out)}
	if tty != nil {
		opts = append(opts, tea.WithInput(tty))
	}
	p := tea.NewProgram(m, opts...)

	go func() {
		sc := bufio.NewScanner(in)
		sc.Buffer(make([]byte, 0, 64*1024), 1024*1024)
		for sc.Scan() {
			if e, ok := parseEvent(sc.Text()); ok {
				p.Send(eventMsg(e))
			}
		}
		p.Send(streamDoneMsg{})
	}()

	_, err := p.Run()
	return err
}

// snapshotStep reads the whole stream and renders a single final frame — used
// for golden tests (DOT_UI_SNAPSHOT=1) and the no-TTY fallback.
func snapshotStep(st Styles, in io.Reader, out io.Writer) error {
	m := newStepModel(st)
	sc := bufio.NewScanner(in)
	sc.Buffer(make([]byte, 0, 64*1024), 1024*1024)
	for sc.Scan() {
		if e, ok := parseEvent(sc.Text()); ok {
			m.apply(e)
		}
	}
	if !m.done {
		m.done = true
	}
	// Freeze any still-running steps as skipped for a clean static frame.
	for i := range m.steps {
		if m.steps[i].state == "run" || m.steps[i].state == "" {
			m.steps[i].state = "skip"
		}
	}
	_, err := fmt.Fprint(out, m.View())
	return err
}
