// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
package main

import (
	"os"
	"strings"
	"testing"
)

func TestParseEvent(t *testing.T) {
	if _, ok := parseEvent(""); ok {
		t.Error("blank line should not parse")
	}
	if _, ok := parseEvent("   "); ok {
		t.Error("whitespace line should not parse")
	}
	if _, ok := parseEvent("{not json"); ok {
		t.Error("invalid JSON should not parse")
	}
	e, ok := parseEvent(`{"t":"step","id":"x","label":"X","state":"ok","detail":"done"}`)
	if !ok {
		t.Fatal("valid event failed to parse")
	}
	if e.T != "step" || e.ID != "x" || e.Label != "X" || e.State != "ok" || e.Detail != "done" {
		t.Errorf("unexpected event: %+v", e)
	}
}

func newTestModel() stepModel { return newStepModel(NewStyles(LoadPalette())) }

func TestApplyHeaderAndSteps(t *testing.T) {
	m := newTestModel()
	m.apply(Event{T: "header", Title: "dot theme", Subtitle: "pulse"})
	if m.title != "dot theme" || m.subtitle != "pulse" {
		t.Fatalf("header not applied: %q %q", m.title, m.subtitle)
	}
	// New step defaults to run when state omitted.
	m.apply(Event{T: "step", ID: "a", Label: "Alpha"})
	if len(m.steps) != 1 || m.steps[0].state != "run" {
		t.Fatalf("step add failed: %+v", m.steps)
	}
	// Update existing step in place.
	m.apply(Event{T: "step", ID: "a", State: "ok", Detail: "done"})
	if len(m.steps) != 1 || m.steps[0].state != "ok" || m.steps[0].detail != "done" {
		t.Fatalf("step update failed: %+v", m.steps)
	}
	// labelW tracks widest label.
	m.apply(Event{T: "step", ID: "b", Label: "LongerLabel", State: "ok"})
	if m.labelW < len("LongerLabel") {
		t.Errorf("labelW=%d too small", m.labelW)
	}
}

func TestApplyNaDropped(t *testing.T) {
	m := newTestModel()
	m.apply(Event{T: "step", ID: "dms", Label: "DMS", State: "na"})
	if len(m.steps) != 0 {
		t.Fatalf("pure-na step should never be added, got %+v", m.steps)
	}
}

func TestRunThenNaHidden(t *testing.T) {
	// A step that starts running then resolves to na is kept but hidden.
	m := newTestModel()
	m.apply(Event{T: "step", ID: "niri", Label: "Niri", State: "run"})
	m.apply(Event{T: "step", ID: "niri", State: "na"})
	if m.steps[0].state != "na" {
		t.Fatalf("run→na should set state na, got %q", m.steps[0].state)
	}
	if strings.Contains(m.View(), "Niri") {
		t.Errorf("na step should not render:\n%s", m.View())
	}
}

func TestApplyProgressWaitDone(t *testing.T) {
	m := newTestModel()
	m.apply(Event{T: "progress", Cur: 3, Total: 12})
	if m.cur != 3 || m.total != 12 {
		t.Fatalf("progress not applied: %d/%d", m.cur, m.total)
	}
	m.apply(Event{T: "wait", Label: "waiting…"})
	if m.wait != "waiting…" {
		t.Fatalf("wait not applied: %q", m.wait)
	}
	// A subsequent step clears the wait line.
	m.apply(Event{T: "step", ID: "z", Label: "Z", State: "run"})
	if m.wait != "" {
		t.Errorf("wait should clear on new step")
	}
	m.apply(Event{T: "done", ElapsedMs: 1618, Summary: "reloaded x"})
	if !m.done || m.elapsedMs != 1618 || m.summary != "reloaded x" {
		t.Fatalf("done not applied: %+v", m)
	}
}

func TestViewRendersStates(t *testing.T) {
	m := newTestModel()
	m.apply(Event{T: "header", Title: "dot theme", Subtitle: "pulse"})
	m.apply(Event{T: "step", ID: "ok", Label: "Okay", State: "ok", Detail: "good"})
	m.apply(Event{T: "step", ID: "sk", Label: "Skipp", State: "skip", Detail: "n/a"})
	m.apply(Event{T: "step", ID: "fa", Label: "Faild", State: "fail", Detail: "boom"})
	m.apply(Event{T: "step", ID: "wa", Label: "Warnn", State: "warn"})
	m.apply(Event{T: "progress", Cur: 2, Total: 4})
	out := m.View()
	for _, want := range []string{"dot theme", "pulse", "Okay", "good", "✓", "·", "✗", "⚠", "2/4"} {
		if !strings.Contains(out, want) {
			t.Errorf("View missing %q\n%s", want, out)
		}
	}
	// Done view shows the summary + elapsed.
	m.apply(Event{T: "done", ElapsedMs: 100, Summary: "all good"})
	out = m.View()
	if !strings.Contains(out, "Done in 100ms") || !strings.Contains(out, "all good") {
		t.Errorf("done view wrong:\n%s", out)
	}
}

func TestViewDoneWithoutSummary(t *testing.T) {
	m := newTestModel()
	m.apply(Event{T: "done"})
	if !strings.Contains(m.View(), "Done") {
		t.Error("bare done should still render Done")
	}
}

func TestSnapshotStep(t *testing.T) {
	stream := strings.Join([]string{
		`{"t":"header","title":"dot theme","subtitle":"pulse"}`,
		`{"t":"step","id":"a","label":"Alpha","state":"ok","detail":"done"}`,
		`{"t":"step","id":"b","label":"Beta","state":"run","detail":"working…"}`, // still running
		`{"t":"step","id":"c","label":"Gamma","state":"na"}`,                     // dropped
		`{"t":"done","elapsed_ms":50,"summary":"reloaded a"}`,
	}, "\n")
	var b strings.Builder
	if err := snapshotStep(newTestModel().st, strings.NewReader(stream), &b); err != nil {
		t.Fatal(err)
	}
	out := b.String()
	if !strings.Contains(out, "Alpha") || !strings.Contains(out, "reloaded a") {
		t.Errorf("snapshot missing content:\n%s", out)
	}
	if strings.Contains(out, "Gamma") {
		t.Errorf("na step leaked into snapshot:\n%s", out)
	}
	// A running step is frozen to skip (·) in the static frame, not a spinner.
	if strings.Contains(out, "⠋") {
		t.Errorf("snapshot should not contain a live spinner frame:\n%s", out)
	}
}

func TestSnapshotStepUnterminated(t *testing.T) {
	// No "done" event — snapshot still finalizes.
	var b strings.Builder
	err := snapshotStep(newTestModel().st, strings.NewReader(`{"t":"step","id":"a","label":"A","state":"run"}`), &b)
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(b.String(), "A") {
		t.Errorf("unterminated snapshot missing step:\n%s", b.String())
	}
}

func TestIsTTYOnPipe(t *testing.T) {
	// os.Stdin under `go test` is not a character device.
	r, w, _ := os.Pipe()
	defer r.Close()
	defer w.Close()
	if isTTY(r) {
		t.Error("a pipe should not be reported as a TTY")
	}
}

func TestRunStepNonInteractiveFallsBackToSnapshot(t *testing.T) {
	// interactive=false must render via snapshot without a Bubble Tea loop.
	stream := `{"t":"header","title":"t","subtitle":"s"}` + "\n" + `{"t":"done","summary":"ok"}`
	var b strings.Builder
	if err := runStep(newTestModel().st, strings.NewReader(stream), nil, &b, false); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(b.String(), "Done") {
		t.Errorf("non-interactive runStep did not render:\n%s", b.String())
	}
}
