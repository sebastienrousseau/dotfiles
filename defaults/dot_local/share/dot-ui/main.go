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

// isTTY reports whether f is a character device (a terminal).
func isTTY(f *os.File) bool {
	fi, err := f.Stat()
	if err != nil {
		return false
	}
	return fi.Mode()&os.ModeCharDevice != 0
}
