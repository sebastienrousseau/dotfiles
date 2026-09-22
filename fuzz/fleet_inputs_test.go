// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// FuzzFleetInputs ports the input gates of `dot fleet apply`
// (scripts/dot/commands/fleet.sh, cmd_fleet_apply) that run before any
// SSH connection:
//
//	host name   ^[a-zA-Z0-9._-]+$, not starting with "."
//	            (it becomes "$tmpdir/$name.out")
//	ssh target  ^[a-zA-Z0-9._@:+/-]+$, not starting with "-"
//	            (ssh would parse a leading "-" as an option)
//	--jobs      ^[1-9][0-9]*$ (0 or a non-number spun the throttle forever)
//
// The literals below must stay byte-identical to fleet.sh;
// tests/unit/security/test_fuzz_ports_lockstep.sh fails when they drift.
//
// Invariants:
//  1. An accepted host name joined as "<dir>/<name>.out" stays inside dir.
//  2. An accepted target never starts with "-" and carries no shell
//     metacharacter or whitespace.
//  3. An accepted --jobs value is a positive decimal integer.
//
// Run locally:
//
//	cd fuzz && go test -run '^$' -fuzz=FuzzFleetInputs -fuzztime=30s

package fuzz

import (
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

const (
	fleetNamePattern   = `^[a-zA-Z0-9._-]+$`
	fleetTargetPattern = `^[a-zA-Z0-9._@:+/-]+$`
	fleetJobsPattern   = `^[1-9][0-9]*$`
)

var (
	fleetNameRE   = regexp.MustCompile(fleetNamePattern)
	fleetTargetRE = regexp.MustCompile(fleetTargetPattern)
	fleetJobsRE   = regexp.MustCompile(fleetJobsPattern)
)

func fleetNameOK(name string) bool {
	return fleetNameRE.MatchString(name) && !strings.HasPrefix(name, ".")
}

func fleetTargetOK(target string) bool {
	return fleetTargetRE.MatchString(target) && !strings.HasPrefix(target, "-")
}

func fleetJobsOK(jobs string) bool { return fleetJobsRE.MatchString(jobs) }

func FuzzFleetInputs(f *testing.F) {
	for _, s := range [][3]string{
		{"alpha", "user@alpha.test", "4"},
		{"laptop-2", "me@host.local:2222", "16"},
		{"../victim", "-F/nonexistent", "0"},
		{".hidden", "-oProxyCommand=x", "-1"},
		{"a/b", "user@host; rm -rf /", "many"},
		{"", "", ""},
		{"x", "host name", "01"},
		{"ok", "u@h\n-oX", "4 "},
	} {
		f.Add(s[0], s[1], s[2])
	}
	f.Fuzz(func(t *testing.T, name, target, jobs string) {
		if fleetNameOK(name) {
			dir := "/tmp/dotfiles-fleet.XXXX"
			out := filepath.Join(dir, name+".out")
			if !strings.HasPrefix(out, dir+"/") {
				t.Fatalf("accepted host name %q escapes %s: %s", name, dir, out)
			}
		}
		if fleetTargetOK(target) {
			if strings.HasPrefix(target, "-") {
				t.Fatalf("accepted option-like target %q", target)
			}
			if strings.ContainsAny(target, " \t\n;|&$`'\"\\()<>*?!{}[]~#") {
				t.Fatalf("accepted target with a shell metacharacter %q", target)
			}
		}
		if fleetJobsOK(jobs) {
			if jobs[0] < '1' || jobs[0] > '9' {
				t.Fatalf("accepted non-positive jobs %q", jobs)
			}
			for _, c := range jobs {
				if c < '0' || c > '9' {
					t.Fatalf("accepted non-decimal jobs %q", jobs)
				}
			}
		}
	})
}
