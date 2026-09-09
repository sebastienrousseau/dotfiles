// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
package main

import (
	"errors"
	"regexp"
	"strings"
	"testing"
)

// TestDispatch covers every subcommand branch and the exit code each returns.
func TestDispatch(t *testing.T) {
	tests := []struct {
		name     string
		args     []string
		stdin    string
		stdout   any // io.Writer override, nil for a buffer
		wantCode int
		wantOut  string
		wantErr  string
	}{
		{name: "no arguments", wantCode: 2, wantErr: "missing subcommand"},
		{name: "version", args: []string{"--version"}, wantOut: "dot-mcp " + version},
		{name: "version short flag", args: []string{"-v"}, wantOut: "dot-mcp " + version},
		{name: "version subcommand", args: []string{"version"}, wantOut: "dot-mcp " + version},
		{name: "unknown subcommand", args: []string{"listen"}, wantCode: 2, wantErr: "unsupported subcommand"},
		{
			name:    "serve answers a handshake",
			args:    []string{"serve"},
			stdin:   initFrame + "\n",
			wantOut: `"protocolVersion"`,
		},
		{name: "serve on an empty stream exits cleanly", args: []string{"serve"}},
		{name: "tools prints the manifest", args: []string{"tools"}, wantOut: `"dotfiles-mcp"`},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			var out, errbuf strings.Builder
			code := dispatch(tc.args, strings.NewReader(tc.stdin), &out, &errbuf)
			if code != tc.wantCode {
				t.Fatalf("exit code = %d, want %d (stderr: %s)", code, tc.wantCode, errbuf.String())
			}
			if tc.wantOut != "" && !strings.Contains(out.String(), tc.wantOut) {
				t.Fatalf("stdout = %q, want it to contain %q", out.String(), tc.wantOut)
			}
			if tc.wantErr != "" && !strings.Contains(errbuf.String(), tc.wantErr) {
				t.Fatalf("stderr = %q, want it to contain %q", errbuf.String(), tc.wantErr)
			}
		})
	}
}

// TestDispatchReportsFailures covers the two error returns: a serve session
// whose peer has gone, and a manifest that cannot be written.
func TestDispatchReportsFailures(t *testing.T) {
	var errbuf strings.Builder
	code := dispatch([]string{"serve"}, strings.NewReader(initFrame+"\n"),
		errWriter{err: errors.New("broken pipe")}, &errbuf)
	if code != 1 || !strings.Contains(errbuf.String(), "dot-mcp serve:") {
		t.Fatalf("code = %d, stderr = %q", code, errbuf.String())
	}

	errbuf.Reset()
	code = dispatch([]string{"tools"}, strings.NewReader(""),
		errWriter{err: errors.New("broken pipe")}, &errbuf)
	if code != 1 || !strings.Contains(errbuf.String(), "dot-mcp tools:") {
		t.Fatalf("code = %d, stderr = %q", code, errbuf.String())
	}
}

// TestMainExitsWithTheDispatchCode covers main() through the exit seam, the
// one call that cannot run for real inside a test binary.
func TestMainExitsWithTheDispatchCode(t *testing.T) {
	origExit := exit
	t.Cleanup(func() { exit = origExit })
	got := -1
	exit = func(code int) { got = code }
	main() // no subcommand: the test binary's own arguments are not ours
	if got != 2 {
		t.Fatalf("exit code = %d, want 2", got)
	}
}

// TestVersionIsSemver pins the shape of the release string that reaches
// clients through initialize.
func TestVersionIsSemver(t *testing.T) {
	if !regexp.MustCompile(`^\d+\.\d+\.\d+$`).MatchString(version) {
		t.Fatalf("version = %q, want a bare semver", version)
	}
}
