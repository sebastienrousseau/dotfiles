// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// dot-ui — the shared Bubble Tea rendering binary for the `dot` CLI.
//
// It is a thin renderer driven by the bash command layer (lib/dot/ui.sh): the
// bash side does the real work and streams structured events; dot-ui draws
// them with a consistent, theme-aware interface. It never fails an apply — when
// Go/dot-ui is absent, ui.sh falls back to plain output.
//
// Subcommands (Phase 1 ships `run`; others are reserved and exit 2 so callers
// fall back cleanly):
//
//	run   step-runner over an NDJSON event stream on stdin
//	pick  unified picker            (reserved)
//	table themed table              (reserved)
//	dashboard full-screen panels    (reserved)
//	spin  single long-op spinner    (reserved)
package main

import (
	"fmt"
	"io"
	"os"
)

const version = "0.2.512"

func main() { os.Exit(dispatch(os.Args[1:], os.Stdout, os.Stderr)) }

// dispatch routes a subcommand and returns a process exit code. Split from
// main so it is unit-testable without spawning a process.
func dispatch(args []string, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		fmt.Fprintln(stderr, "dot-ui: missing subcommand (run|pick|table|dashboard|spin)")
		return 2
	}
	switch args[0] {
	case "--version", "-v", "version":
		fmt.Fprintln(stdout, "dot-ui", version)
		return 0
	case "run":
		if err := cmdRun(NewStyles(LoadPalette())); err != nil {
			fmt.Fprintln(stderr, "dot-ui run:", err)
			return 1
		}
		return 0
	case "table":
		if err := runTable(LoadPalette(), os.Stdin, os.Stdout); err != nil {
			fmt.Fprintln(stderr, "dot-ui table:", err)
			return 1
		}
		return 0
	case "pick":
		return cmdPick(NewStyles(LoadPalette()), args[1:], stdout)
	default:
		// Reserved / unknown subcommand — non-zero so the bash façade uses
		// its plain fallback instead of assuming rich output happened.
		fmt.Fprintln(stderr, "dot-ui: unsupported subcommand:", args[0])
		return 2
	}
}

// cmdRun wires stdin (events) + /dev/tty (keys) + stdout (render) for the run
// view, honoring DOT_UI_SNAPSHOT for a static one-shot frame.
func cmdRun(st Styles) error {
	if os.Getenv("DOT_UI_SNAPSHOT") == "1" {
		return snapshotStep(st, os.Stdin, os.Stdout)
	}

	interactive := isTTY(os.Stdout)
	var ttyReader io.Reader
	if interactive {
		// Keyboard from the controlling terminal so stdin stays the event
		// stream. If /dev/tty can't be opened, keep rendering without keys.
		if tty, err := os.Open("/dev/tty"); err == nil {
			ttyReader = tty
			defer tty.Close()
		}
	}
	return runStep(st, os.Stdin, ttyReader, os.Stdout, interactive)
}

// cmdPick parses --header/--prompt, drives the picker on /dev/tty, and prints
// the selection to stdout (exit 0) or nothing (exit 1 on cancel/no-TTY) so the
// bash caller can fall back.
func cmdPick(st Styles, args []string, stdout io.Writer) int {
	var header, prompt string
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--header":
			if i+1 < len(args) {
				i++
				header = args[i]
			}
		case "--prompt":
			if i+1 < len(args) {
				i++
				prompt = args[i]
			}
		}
	}
	snapshot := os.Getenv("DOT_UI_SNAPSHOT") == "1"
	var tty *os.File
	// Only engage the interactive picker in a real session. stderr stays a
	// terminal even when stdout is captured (sel=$(… | dot-ui pick)); if it
	// isn't a tty we're piped/non-interactive, so bail to the fallback rather
	// than block on a /dev/tty that never delivers input.
	if !snapshot && isTTY(os.Stderr) {
		if f, err := os.OpenFile("/dev/tty", os.O_RDWR, 0); err == nil {
			tty = f
			defer f.Close()
		}
	}
	sel, outcome := runPick(st, header, prompt, os.Stdin, tty, snapshot)
	switch outcome {
	case pickSelected:
		fmt.Fprintln(stdout, sel)
		return 0
	case pickCancelled:
		return 1 // interactive cancel — caller stops, no fallback
	default:
		return 2 // could not run — caller falls back to fzf/gum
	}
}

// isTTY reports whether f is a character device (a terminal).
func isTTY(f *os.File) bool {
	fi, err := f.Stat()
	if err != nil {
		return false
	}
	return fi.Mode()&os.ModeCharDevice != 0
}
