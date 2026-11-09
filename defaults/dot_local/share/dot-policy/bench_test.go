// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package main

import (
	"io"
	"strings"
	"testing"
)

// BenchmarkCheck is one hook call end to end: read and validate the policy,
// decode the call, decide it. It runs on every tool call of every agent.
func BenchmarkCheck(b *testing.B) {
	dir := b.TempDir()
	path := dir + "/p.toml"
	if err := writeFile(path, samplePolicy); err != nil {
		b.Fatal(err)
	}
	getenv := func(k string) string { return map[string]string{"HOME": dir}[k] }
	call := `{"tool_name":"Bash","tool_input":{"command":"cd x && go test ./... | tee log"},"cwd":"/work"}`
	for b.Loop() {
		run([]string{"check", "--mode", "apply", "--policy", path}, strings.NewReader(call), io.Discard, io.Discard, getenv)
	}
}
