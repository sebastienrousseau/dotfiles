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

// version is the dot-ui release string printed by `dot-ui --version`; it
// tracks the framework version in defaults/.chezmoidata.toml.
const version = "0.2.512"

// Process-boundary seams. Each wraps exactly one call that cannot be
// exercised in-process by `go test`: os.Exit terminates the test binary, and
// the controlling terminal (/dev/tty, stdout/stderr device checks) does not
// exist under CI. Tests substitute these; production never does.
var (
	// exit terminates the process with a status code.
	exit = os.Exit
	// stdoutIsTTY reports whether stdout is attached to a terminal.
	stdoutIsTTY = func() bool { return isTTY(os.Stdout) }
	// stderrIsTTY reports whether stderr is attached to a terminal.
	stderrIsTTY = func() bool { return isTTY(os.Stderr) }
	// openTTY opens the controlling terminal read/write.
	openTTY = func() (*os.File, error) { return os.OpenFile("/dev/tty", os.O_RDWR, 0) }
)

func main() { exit(dispatch(os.Args[1:], os.Stdin, os.Stdout, os.Stderr)) }

// dispatch routes a subcommand and returns a process exit code. Split from
// main so it is unit-testable without spawning a process. stdin carries the
// event/row stream, stdout the rendered output, stderr diagnostics.
func dispatch(args []string, stdin io.Reader, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		fmt.Fprintln(stderr, "dot-ui: missing subcommand (run|pick|table|dashboard|spin)")
		return 2
	}
	switch args[0] {
	case "--version", "-v", "version":
		fmt.Fprintln(stdout, "dot-ui", version)
		return 0
	case "run":
		if err := cmdRun(NewStyles(LoadPalette()), stdin, stdout); err != nil {
			fmt.Fprintln(stderr, "dot-ui run:", err)
			return 1
		}
		return 0
	case "table":
		if err := runTable(LoadPalette(), stdin, stdout); err != nil {
			fmt.Fprintln(stderr, "dot-ui table:", err)
			return 1
		}
		return 0
	case "pick":
		return cmdPick(NewStyles(LoadPalette()), args[1:], stdin, stdout)
	default:
		// Reserved / unknown subcommand — non-zero so the bash façade uses
		// its plain fallback instead of assuming rich output happened.
		fmt.Fprintln(stderr, "dot-ui: unsupported subcommand:", args[0])
		return 2
	}
}

// snapshotMode reports whether DOT_UI_SNAPSHOT=1 requests a static one-shot
// frame instead of an interactive Bubble Tea session.
func snapshotMode() bool { return os.Getenv("DOT_UI_SNAPSHOT") == "1" }

// cmdRun wires stdin (events) + /dev/tty (keys) + stdout (render) for the run
// view, honoring DOT_UI_SNAPSHOT for a static one-shot frame.
func cmdRun(st Styles, stdin io.Reader, stdout io.Writer) error {
	if snapshotMode() {
		return snapshotStep(st, stdin, stdout)
	}

	interactive := stdoutIsTTY()
	var ttyReader io.Reader
	if interactive {
		// Keyboard from the controlling terminal so stdin stays the event
		// stream. If /dev/tty can't be opened, keep rendering without keys.
		if tty, err := openTTY(); err == nil {
			ttyReader = tty
			defer func() { _ = tty.Close() }()
		}
	}
	return runStep(st, stdin, ttyReader, stdout, interactive)
}

// parsePickArgs extracts --header and --prompt from the pick argument list.
// Unknown flags are ignored; a trailing flag with no value is ignored too.
func parsePickArgs(args []string) (header, prompt string) {
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
	return header, prompt
}

// cmdPick parses --header/--prompt, drives the picker on /dev/tty, and prints
// the selection to stdout (exit 0) or nothing (exit 1 on cancel, 2 when no
// terminal is available) so the bash caller can fall back.
func cmdPick(st Styles, args []string, stdin io.Reader, stdout io.Writer) int {
	header, prompt := parsePickArgs(args)
	snapshot := snapshotMode()
	var tty *os.File
	// Only engage the interactive picker in a real session. stderr stays a
	// terminal even when stdout is captured (sel=$(… | dot-ui pick)); if it
	// isn't a tty we're piped/non-interactive, so bail to the fallback rather
	// than block on a /dev/tty that never delivers input.
	if !snapshot && stderrIsTTY() {
		if f, err := openTTY(); err == nil {
			tty = f
			defer func() { _ = f.Close() }()
		}
	}
	sel, outcome := runPick(st, header, prompt, stdin, tty, snapshot)
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
