// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// Interactive-path tests. A Unix socketpair stands in for /dev/tty so the
// real Bubble Tea program loop (input reader, renderer, quit handling) runs
// end-to-end without a pseudo-terminal.

//go:build unix

package main

import (
	"io"
	"os"
	"strings"
	"syscall"
	"testing"
	"time"
)

// socketPair returns two connected *os.File ends; both are closed on cleanup.
func socketPair(t *testing.T) (*os.File, *os.File) {
	t.Helper()
	fds, err := syscall.Socketpair(syscall.AF_UNIX, syscall.SOCK_STREAM, 0)
	if err != nil {
		t.Fatalf("socketpair: %v", err)
	}
	a := os.NewFile(uintptr(fds[0]), "tty-a")
	b := os.NewFile(uintptr(fds[1]), "tty-b")
	t.Cleanup(func() { a.Close(); b.Close() })
	return a, b
}

// drain discards everything the program renders to the peer end.
func drain(f *os.File) { _, _ = io.Copy(io.Discard, f) }

// withTimeout fails the test if fn does not return within d.
func withTimeout(t *testing.T, d time.Duration, fn func()) {
	t.Helper()
	done := make(chan struct{})
	go func() { fn(); close(done) }()
	select {
	case <-done:
	case <-time.After(d):
		t.Fatal("interactive program did not finish in time")
	}
}

// TestRunPickInteractiveSelect drives the picker over a socket: Enter selects
// the first candidate and the outcome is pickSelected.
func TestRunPickInteractiveSelect(t *testing.T) {
	tty, peer := socketPair(t)
	go drain(peer)
	_, _ = peer.Write([]byte("\r")) // enter
	withTimeout(t, 10*time.Second, func() {
		sel, outcome := runPick(NewStyles(LoadPalette()), "h", "p", strings.NewReader("first\nsecond\n"), tty, false)
		if outcome != pickSelected || sel != "first" {
			t.Errorf("interactive select: sel=%q outcome=%d", sel, outcome)
		}
	})
}

// TestRunPickInteractiveFilterSelect types a query, moves down, then selects.
func TestRunPickInteractiveFilterSelect(t *testing.T) {
	tty, peer := socketPair(t)
	go drain(peer)
	_, _ = peer.Write([]byte("dark\x0e\r")) // "dark", ctrl+n, enter
	withTimeout(t, 10*time.Second, func() {
		sel, outcome := runPick(NewStyles(LoadPalette()), "", "", strings.NewReader("altai-dark\nberlin-dark\ncanary-light\n"), tty, false)
		if outcome != pickSelected || sel != "berlin-dark" {
			t.Errorf("filter+select: sel=%q outcome=%d", sel, outcome)
		}
	})
}

// TestRunPickInteractiveCancel covers Ctrl-C → pickCancelled with no output.
func TestRunPickInteractiveCancel(t *testing.T) {
	tty, peer := socketPair(t)
	go drain(peer)
	_, _ = peer.Write([]byte("\x03")) // ctrl+c
	withTimeout(t, 10*time.Second, func() {
		sel, outcome := runPick(NewStyles(LoadPalette()), "h", "p", strings.NewReader("a\nb\n"), tty, false)
		if outcome != pickCancelled || sel != "" {
			t.Errorf("interactive cancel: sel=%q outcome=%d", sel, outcome)
		}
	})
}

// TestRunPickProgramError covers a Bubble Tea start-up failure (closed
// terminal handle) → pickNoTTY so the caller falls back.
func TestRunPickProgramError(t *testing.T) {
	tty, _ := socketPair(t)
	tty.Close()
	withTimeout(t, 10*time.Second, func() {
		sel, outcome := runPick(NewStyles(LoadPalette()), "", "", strings.NewReader("a\n"), tty, false)
		if outcome != pickNoTTY || sel != "" {
			t.Errorf("closed tty: sel=%q outcome=%d want pickNoTTY", sel, outcome)
		}
	})
}

// TestCmdPickInteractive covers cmdPick with a terminal on stderr and an
// openable tty: the selection is printed and the exit code is 0; Ctrl-C
// yields exit 1 and no output.
func TestCmdPickInteractive(t *testing.T) {
	t.Setenv("DOT_UI_SNAPSHOT", "")
	oldTTY, oldOpen := stderrIsTTY, openTTY
	defer func() { stderrIsTTY, openTTY = oldTTY, oldOpen }()
	stderrIsTTY = func() bool { return true }

	tty, peer := socketPair(t)
	go drain(peer)
	openTTY = func() (*os.File, error) { return tty, nil }
	_, _ = peer.Write([]byte("\r"))
	var out strings.Builder
	withTimeout(t, 10*time.Second, func() {
		code := cmdPick(NewStyles(LoadPalette()), []string{"--header", "H"}, strings.NewReader("x\ny\n"), &out)
		if code != 0 || out.String() != "x\n" {
			t.Errorf("interactive pick: code=%d out=%q", code, out.String())
		}
	})

	tty2, peer2 := socketPair(t)
	go drain(peer2)
	openTTY = func() (*os.File, error) { return tty2, nil }
	_, _ = peer2.Write([]byte("\x03"))
	out.Reset()
	withTimeout(t, 10*time.Second, func() {
		code := cmdPick(NewStyles(LoadPalette()), nil, strings.NewReader("x\n"), &out)
		if code != 1 || out.String() != "" {
			t.Errorf("interactive cancel: code=%d out=%q", code, out.String())
		}
	})
}

// TestRunStepInteractive runs the live step view through Bubble Tea with the
// event stream on stdin and keys on a socket; the "done" event quits.
func TestRunStepInteractive(t *testing.T) {
	tty, peer := socketPair(t)
	go drain(peer)
	stream := strings.Join([]string{
		`{"t":"header","title":"dot theme","subtitle":"pulse"}`,
		`{"t":"step","id":"a","label":"Alpha","state":"run"}`,
		`not json`,
		`{"t":"step","id":"a","state":"ok","detail":"done"}`,
		`{"t":"done","elapsed_ms":5,"summary":"reloaded a"}`,
	}, "\n")
	var out strings.Builder
	withTimeout(t, 10*time.Second, func() {
		if err := runStep(NewStyles(LoadPalette()), strings.NewReader(stream), tty, &out, true); err != nil {
			t.Errorf("interactive runStep: %v", err)
		}
	})
	if !strings.Contains(out.String(), "reloaded a") {
		t.Errorf("interactive frame missing summary:\n%s", out.String())
	}
}

// TestRunStepInteractiveEOF covers a stream that ends without a done event:
// streamDoneMsg finalizes and quits.
func TestRunStepInteractiveEOF(t *testing.T) {
	tty, peer := socketPair(t)
	go drain(peer)
	var out strings.Builder
	withTimeout(t, 10*time.Second, func() {
		err := runStep(NewStyles(LoadPalette()), strings.NewReader(`{"t":"step","id":"a","label":"A","state":"ok"}`), tty, &out, true)
		if err != nil {
			t.Errorf("EOF runStep: %v", err)
		}
	})
	if !strings.Contains(out.String(), "Done") {
		t.Errorf("EOF frame should be finalized:\n%s", out.String())
	}
}

// TestRunStepInteractiveCtrlC covers the ctrl+c key quitting the run view
// before the stream finishes.
func TestRunStepInteractiveCtrlC(t *testing.T) {
	tty, peer := socketPair(t)
	go drain(peer)
	inR, inW, err := os.Pipe()
	if err != nil {
		t.Fatal(err)
	}
	defer inW.Close()
	_, _ = io.WriteString(inW, `{"t":"step","id":"a","label":"A","state":"run"}`+"\n")
	_, _ = peer.Write([]byte("\x03"))
	var out strings.Builder
	withTimeout(t, 10*time.Second, func() {
		if err := runStep(NewStyles(LoadPalette()), inR, tty, &out, true); err != nil {
			t.Errorf("ctrl+c runStep: %v", err)
		}
	})
}

// TestCmdRunInteractive covers cmdRun's terminal branch: stdout reported as a
// TTY and /dev/tty opened for keys.
func TestCmdRunInteractive(t *testing.T) {
	t.Setenv("DOT_UI_SNAPSHOT", "")
	oldOut, oldOpen := stdoutIsTTY, openTTY
	defer func() { stdoutIsTTY, openTTY = oldOut, oldOpen }()
	stdoutIsTTY = func() bool { return true }
	tty, peer := socketPair(t)
	go drain(peer)
	openTTY = func() (*os.File, error) { return tty, nil }
	var out strings.Builder
	withTimeout(t, 10*time.Second, func() {
		err := cmdRun(NewStyles(LoadPalette()), strings.NewReader(`{"t":"done","summary":"ok"}`), &out)
		if err != nil {
			t.Errorf("interactive cmdRun: %v", err)
		}
	})
	if !strings.Contains(out.String(), "ok") {
		t.Errorf("interactive cmdRun frame:\n%s", out.String())
	}
}

// TestCmdRunNoTerminal covers cmdRun when stdout is piped: the snapshot
// renderer is used and no tty is opened.
func TestCmdRunNoTerminal(t *testing.T) {
	t.Setenv("DOT_UI_SNAPSHOT", "")
	oldOut, oldOpen := stdoutIsTTY, openTTY
	defer func() { stdoutIsTTY, openTTY = oldOut, oldOpen }()
	stdoutIsTTY = func() bool { return false }
	openTTY = func() (*os.File, error) { t.Fatal("openTTY must not be called when stdout is piped"); return nil, nil }
	var out strings.Builder
	if err := cmdRun(NewStyles(LoadPalette()), strings.NewReader(`{"t":"done"}`), &out); err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(out.String(), "Done") {
		t.Errorf("piped cmdRun frame:\n%s", out.String())
	}
}
