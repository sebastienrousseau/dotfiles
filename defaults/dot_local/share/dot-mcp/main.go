// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// dot-mcp — the Model Context Protocol server behind `dot mcp serve`.
//
// It speaks JSON-RPC 2.0 over newline-delimited frames on stdin/stdout, which
// is exactly what .well-known/mcp/server-card.json advertises. stdout carries
// protocol frames and nothing else; every diagnostic goes to stderr, because a
// single stray byte on stdout desynchronises the client's frame reader.
//
// The tools it exposes are the `dot` CLI's own read-only governance surfaces
// (MCP policy audit, agent profile inspection, workstation attestation, fleet
// status), so the protocol layer never becomes a second source of truth: it
// shells out to the same commands a human would run. Nothing it exposes
// mutates configuration.
//
// Subcommands:
//
//	serve      run the stdio MCP server (the card's transport)
//	tools      print the tool/resource manifest as JSON, without speaking
//	           the protocol (inspection, scripts, and CI)
//	--version  print the version and exit
package main

import (
	"fmt"
	"io"
	"os"
)

// version is the dot-mcp release string. It tracks the framework version in
// defaults/.chezmoidata.toml and is kept in step with
// .well-known/mcp/server-card.json by scripts/version-sync.sh; the pairing is
// asserted by TestVersionMatchesServerCard.
const version = "0.2.520"

// Process-boundary seams. Each wraps exactly one call that cannot be exercised
// in-process by `go test`: os.Exit terminates the test binary. Tests substitute
// these; production never does.
var (
	// exit terminates the process with a status code.
	exit = os.Exit
)

func main() { exit(dispatch(os.Args[1:], os.Stdin, os.Stdout, os.Stderr)) }

// dispatch routes a subcommand and returns a process exit code. Split from
// main so it is unit-testable without spawning a process. stdin/stdout carry
// the JSON-RPC frames, stderr the log lines.
func dispatch(args []string, stdin io.Reader, stdout, stderr io.Writer) int {
	if len(args) == 0 {
		fmt.Fprintln(stderr, "dot-mcp: missing subcommand (serve|tools|--version)")
		return 2
	}
	switch args[0] {
	case "--version", "-v", "version":
		fmt.Fprintln(stdout, "dot-mcp", version)
		return 0
	case "serve":
		srv := NewServer(stdin, stdout, stderr)
		if err := srv.Serve(); err != nil {
			fmt.Fprintln(stderr, "dot-mcp serve:", err)
			return 1
		}
		return 0
	case "tools":
		srv := NewServer(stdin, stdout, stderr)
		if err := srv.WriteToolManifest(stdout); err != nil {
			fmt.Fprintln(stderr, "dot-mcp tools:", err)
			return 1
		}
		return 0
	default:
		fmt.Fprintln(stderr, "dot-mcp: unsupported subcommand:", args[0])
		return 2
	}
}
