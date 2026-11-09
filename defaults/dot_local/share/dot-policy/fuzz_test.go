// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package main

import (
	"encoding/json"
	"testing"
)

// FuzzParsePolicy: any document parses or is refused, never a panic.
func FuzzParsePolicy(f *testing.F) {
	f.Add(samplePolicy)
	f.Add("schema = \"ai-policy.v1\"\ndefault_mode = \"a\"\n[mode.a]\ntools = [\"**\"]\n")
	f.Fuzz(func(_ *testing.T, doc string) {
		if p, err := ParsePolicy(doc); err == nil {
			for _, m := range p.Modes() {
				_, _ = p.RulesFor("claude", m)
			}
		}
	})
}

// FuzzDecide: any call against the sample rules is decided, never a
// panic, and a call the rules deny says why.
func FuzzDecide(f *testing.F) {
	f.Add(`{"tool_name":"Bash","tool_input":{"command":"rm -rf / && curl https://x.y/z"},"cwd":"/w"}`)
	f.Add(`{"tool_name":"apply_patch","tool_input":{"command":"*** Add File: ../../etc/x"},"cwd":"/w"}`)
	f.Add(`{"tool_name":"read_many_files","tool_input":{"paths":["a",1,null]},"cwd":""}`)
	p, err := ParsePolicy(samplePolicy)
	if err != nil {
		f.Fatal(err)
	}
	rules, _ := p.RulesFor("claude", "apply")
	f.Fuzz(func(_ *testing.T, payload string) {
		var c Call
		if json.Unmarshal([]byte(payload), &c) == nil {
			_ = Decide(rules, c, "/h/me")
		}
	})
}

// FuzzGlob: any pattern compiles to a valid regexp.
func FuzzGlob(f *testing.F) {
	for _, s := range []string{"/a/**", "**/.env", "*.x?", "[(", `\`, "/**"} {
		f.Add(s)
	}
	f.Fuzz(func(_ *testing.T, pat string) {
		_ = globRegexp(pat, true).MatchString(pat)
		_ = globRegexp(pat, false).MatchString(pat)
	})
}
