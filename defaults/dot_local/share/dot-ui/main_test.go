package main

import (
	"io"
	"os"
	"strings"
	"testing"

	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
)

func TestDispatchVersion(t *testing.T) {
	var out, errb strings.Builder
	if code := dispatch([]string{"--version"}, &out, &errb); code != 0 {
		t.Fatalf("version exit=%d", code)
	}
	if !strings.Contains(out.String(), version) {
		t.Errorf("version output=%q", out.String())
	}
}

func TestDispatchNoArgs(t *testing.T) {
	var out, errb strings.Builder
	if code := dispatch(nil, &out, &errb); code != 2 {
		t.Fatalf("no-args exit=%d want 2", code)
	}
	if !strings.Contains(errb.String(), "missing subcommand") {
		t.Errorf("stderr=%q", errb.String())
	}
}

func TestDispatchUnknown(t *testing.T) {
	var out, errb strings.Builder
	if code := dispatch([]string{"bogus"}, &out, &errb); code != 2 {
		t.Fatalf("unknown exit=%d want 2", code)
	}
	if !strings.Contains(errb.String(), "unsupported subcommand") {
		t.Errorf("stderr=%q", errb.String())
	}
}

func TestDispatchRunSnapshot(t *testing.T) {
	t.Setenv("DOT_UI_SNAPSHOT", "1")
	// Redirect os.Stdin/os.Stdout for the run path.
	inR, inW, _ := os.Pipe()
	outR, outW, _ := os.Pipe()
	oldIn, oldOut := os.Stdin, os.Stdout
	os.Stdin, os.Stdout = inR, outW
	defer func() { os.Stdin, os.Stdout = oldIn, oldOut }()

	go func() {
		io.WriteString(inW, `{"t":"header","title":"t","subtitle":"s"}`+"\n")
		io.WriteString(inW, `{"t":"done","summary":"ok"}`+"\n")
		inW.Close()
	}()

	var out strings.Builder
	done := make(chan int, 1)
	go func() {
		var errb strings.Builder
		done <- dispatch([]string{"run"}, io.Discard, &errb)
	}()
	code := <-done
	outW.Close()
	b, _ := io.ReadAll(outR)
	out.Write(b)
	if code != 0 {
		t.Fatalf("run snapshot exit=%d", code)
	}
	if !strings.Contains(out.String(), "Done") {
		t.Errorf("run snapshot output=%q", out.String())
	}
}

func isQuit(cmd tea.Cmd) bool {
	if cmd == nil {
		return false
	}
	_, ok := cmd().(tea.QuitMsg)
	return ok
}

func TestUpdateEventAndQuit(t *testing.T) {
	m := newTestModel()
	nm, _ := m.Update(eventMsg{T: "step", ID: "a", Label: "A", State: "ok"})
	sm := nm.(stepModel)
	if len(sm.steps) != 1 || sm.steps[0].state != "ok" {
		t.Fatalf("event not applied via Update: %+v", sm.steps)
	}
	nm2, cmd := sm.Update(eventMsg{T: "done", Summary: "x"})
	if !nm2.(stepModel).done {
		t.Error("done not set via Update")
	}
	if !isQuit(cmd) {
		t.Error("done should return a quit cmd")
	}
}

func TestUpdateKeyCtrlCQuits(t *testing.T) {
	m := newTestModel()
	_, cmd := m.Update(tea.KeyMsg{Type: tea.KeyCtrlC})
	if !isQuit(cmd) {
		t.Error("ctrl+c should quit")
	}
	// A non-quit key is a no-op.
	if _, cmd := m.Update(tea.KeyMsg{Type: tea.KeyRunes, Runes: []rune{'x'}}); isQuit(cmd) {
		t.Error("plain key should not quit")
	}
}

func TestUpdateStreamDoneQuits(t *testing.T) {
	m := newTestModel()
	nm, cmd := m.Update(streamDoneMsg{})
	if !nm.(stepModel).done {
		t.Error("streamDone should finalize")
	}
	if !isQuit(cmd) {
		t.Error("streamDone should quit")
	}
}

func TestUpdateSpinnerTick(t *testing.T) {
	m := newTestModel()
	// Feed a real spinner tick; expect a follow-up tick cmd and no panic.
	msg := m.sp.Tick()
	if _, ok := msg.(spinner.TickMsg); !ok {
		t.Fatalf("expected spinner.TickMsg, got %T", msg)
	}
	if _, cmd := m.Update(msg); cmd == nil {
		t.Error("spinner tick should schedule the next tick")
	}
}

func TestInit(t *testing.T) {
	if newTestModel().Init() == nil {
		t.Error("Init should return the spinner tick cmd")
	}
}
