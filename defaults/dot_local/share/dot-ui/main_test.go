// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
package main

import (
	"errors"
	"io"
	"os"
	"strings"
	"testing"

	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
)

// errWriter fails every write — used to drive the render-error exit paths.
type errWriter struct{}

func (errWriter) Write([]byte) (int, error) { return 0, errors.New("write failed") }

// TestDispatchVersion covers `dot-ui --version`, `-v` and `version`.
func TestDispatchVersion(t *testing.T) {
	for _, flag := range []string{"--version", "-v", "version"} {
		var out, errb strings.Builder
		if code := dispatch([]string{flag}, strings.NewReader(""), &out, &errb); code != 0 {
			t.Fatalf("%s exit=%d", flag, code)
		}
		if !strings.Contains(out.String(), version) {
			t.Errorf("%s output=%q", flag, out.String())
		}
	}
}

// TestDispatchNoArgs covers the missing-subcommand usage error (exit 2).
func TestDispatchNoArgs(t *testing.T) {
	var out, errb strings.Builder
	if code := dispatch(nil, strings.NewReader(""), &out, &errb); code != 2 {
		t.Fatalf("no-args exit=%d want 2", code)
	}
	if !strings.Contains(errb.String(), "missing subcommand") {
		t.Errorf("stderr=%q", errb.String())
	}
}

// TestDispatchUnknown covers reserved/unknown subcommands (exit 2 so the bash
// façade falls back to plain output).
func TestDispatchUnknown(t *testing.T) {
	for _, sub := range []string{"bogus", "dashboard", "spin"} {
		var out, errb strings.Builder
		if code := dispatch([]string{sub}, strings.NewReader(""), &out, &errb); code != 2 {
			t.Fatalf("%s exit=%d want 2", sub, code)
		}
		if !strings.Contains(errb.String(), "unsupported subcommand") {
			t.Errorf("stderr=%q", errb.String())
		}
	}
}

// TestDispatchRunSnapshot covers `dot-ui run` under DOT_UI_SNAPSHOT=1.
func TestDispatchRunSnapshot(t *testing.T) {
	t.Setenv("DOT_UI_SNAPSHOT", "1")
	in := `{"t":"header","title":"t","subtitle":"s"}` + "\n" + `{"t":"done","summary":"ok"}` + "\n"
	var out, errb strings.Builder
	if code := dispatch([]string{"run"}, strings.NewReader(in), &out, &errb); code != 0 {
		t.Fatalf("run snapshot exit=%d stderr=%q", code, errb.String())
	}
	if !strings.Contains(out.String(), "Done") {
		t.Errorf("run snapshot output=%q", out.String())
	}
}

// TestDispatchRunRenderError covers the exit-1 path when the frame cannot be
// written to stdout.
func TestDispatchRunRenderError(t *testing.T) {
	t.Setenv("DOT_UI_SNAPSHOT", "1")
	var errb strings.Builder
	if code := dispatch([]string{"run"}, strings.NewReader(`{"t":"done"}`), errWriter{}, &errb); code != 1 {
		t.Fatalf("run render error exit=%d want 1", code)
	}
	if !strings.Contains(errb.String(), "dot-ui run:") {
		t.Errorf("stderr=%q", errb.String())
	}
}

// TestDispatchTableRenderError covers the exit-1 path for `dot-ui table`.
func TestDispatchTableRenderError(t *testing.T) {
	var errb strings.Builder
	if code := dispatch([]string{"table"}, strings.NewReader("H\nv\n"), errWriter{}, &errb); code != 1 {
		t.Fatalf("table render error exit=%d want 1", code)
	}
	if !strings.Contains(errb.String(), "dot-ui table:") {
		t.Errorf("stderr=%q", errb.String())
	}
}

// TestDispatchPickSnapshot covers `dot-ui pick` routed through dispatch under
// DOT_UI_SNAPSHOT=1 (no terminal → exit 2 so the caller falls back).
func TestDispatchPickSnapshot(t *testing.T) {
	t.Setenv("DOT_UI_SNAPSHOT", "1")
	var out, errb strings.Builder
	if code := dispatch([]string{"pick", "--header", "H"}, strings.NewReader("a\nb\n"), &out, &errb); code != 2 {
		t.Fatalf("pick snapshot exit=%d want 2", code)
	}
	if out.String() != "" {
		t.Errorf("pick snapshot must print nothing, got %q", out.String())
	}
}

// TestMain_ExitsWithDispatchCode covers main via the exit seam: the process
// exit code is exactly what dispatch returned.
func TestMain_ExitsWithDispatchCode(t *testing.T) {
	oldExit, oldArgs, oldOut := exit, os.Args, os.Stdout
	defer func() { exit, os.Args, os.Stdout = oldExit, oldArgs, oldOut }()
	got := -1
	exit = func(code int) { got = code }
	r, w, err := os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	os.Stdout = w
	os.Args = []string{"dot-ui", "--version"}
	main()
	w.Close()
	b, _ := io.ReadAll(r)
	if got != 0 {
		t.Fatalf("main exit=%d want 0", got)
	}
	if !strings.Contains(string(b), version) {
		t.Errorf("main stdout=%q", string(b))
	}
	// A usage error propagates as exit 2.
	os.Args = []string{"dot-ui"}
	main()
	if got != 2 {
		t.Fatalf("main usage exit=%d want 2", got)
	}
}

// TestParsePickArgs covers the --header/--prompt flag parser, including
// dangling flags and unknown arguments.
func TestParsePickArgs(t *testing.T) {
	cases := []struct {
		name           string
		args           []string
		header, prompt string
	}{
		{"none", nil, "", ""},
		{"both", []string{"--header", "H", "--prompt", "P"}, "H", "P"},
		{"reversed", []string{"--prompt", "P", "--header", "H"}, "H", "P"},
		{"dangling header", []string{"--header"}, "", ""},
		{"dangling prompt", []string{"--prompt"}, "", ""},
		{"unknown ignored", []string{"--bogus", "x", "--header", "H"}, "H", ""},
		{"value looks like flag", []string{"--header", "--prompt"}, "--prompt", ""},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			h, p := parsePickArgs(c.args)
			if h != c.header || p != c.prompt {
				t.Fatalf("parsePickArgs(%q)=(%q,%q) want (%q,%q)", c.args, h, p, c.header, c.prompt)
			}
		})
	}
}

// TestSnapshotMode covers the DOT_UI_SNAPSHOT env switch.
func TestSnapshotMode(t *testing.T) {
	t.Setenv("DOT_UI_SNAPSHOT", "")
	if snapshotMode() {
		t.Error("unset → interactive")
	}
	t.Setenv("DOT_UI_SNAPSHOT", "0")
	if snapshotMode() {
		t.Error("0 → interactive")
	}
	t.Setenv("DOT_UI_SNAPSHOT", "1")
	if !snapshotMode() {
		t.Error("1 → snapshot")
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

// TestSeamDefaults exercises the production bodies of the process-boundary
// seams. Under `go test` stdout/stderr are pipes (not terminals) and
// /dev/tty may or may not exist, so only the contract is asserted: the
// predicates return without panicking and an opened tty is closed again.
func TestSeamDefaults(t *testing.T) {
	_ = stdoutIsTTY()
	_ = stderrIsTTY()
	if f, err := openTTY(); err == nil {
		f.Close()
	}
}
