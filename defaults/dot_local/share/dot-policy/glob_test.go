// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package main

import "testing"

func TestGlob(t *testing.T) {
	cases := []struct {
		pat, s string
		slash  bool
		want   bool
	}{
		{"/a/*", "/a/b", true, true},
		{"/a/*", "/a/b/c", true, false},
		{"/a/**", "/a/b/c", true, true},
		{"/a/**", "/a", true, true},
		{"/a/**", "/ab", true, false},
		{"**/.env", "/x/y/.env", true, true},
		{"**/.env", "/x/y/.envrc", true, false},
		{"/a/?.go", "/a/b.go", true, true},
		{"/a/?.go", "/a//.go", true, false},
		{"*.github.com", "api.github.com", true, true},
		{"*.github.com", "github.com", true, false},
		{"a.b", "axb", true, false},
		{"rm -rf *", "rm -rf /tmp/x", false, true},
		{"rm -rf ?", "rm -rf /", false, true},
		{"café/*", "café/x", true, true},
	}
	for _, tc := range cases {
		if got := globRegexp(tc.pat, tc.slash).MatchString(tc.s); got != tc.want {
			t.Errorf("glob %q on %q (slash %v) = %v, want %v", tc.pat, tc.s, tc.slash, got, tc.want)
		}
	}
}

func TestMatchAnyExpands(t *testing.T) {
	up := func(s string) string { return s + "x" }
	if !matchAny([]string{"a"}, "ax", true, up) {
		t.Error("the pattern was not expanded")
	}
	if matchAny(nil, "a", true, nil) {
		t.Error("no patterns matched")
	}
}
