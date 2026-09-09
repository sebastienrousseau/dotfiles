// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
package main

import (
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"testing"
)

// fakeEnv builds an environment backed by literal maps: vars for lookups,
// files for stat. Nothing touches the real process environment, so the tests
// are order-independent and safe under -race.
func fakeEnv(vars map[string]string, files ...string) environment {
	present := map[string]bool{}
	for _, f := range files {
		present[f] = true
	}
	return environment{
		lookup: func(k string) (string, bool) { v, ok := vars[k]; return v, ok },
		getwd:  func() (string, error) { return vars["__wd"], nil },
		home:   func() (string, error) { return vars["__home"], nil },
		stat: func(p string) (os.FileInfo, error) {
			if present[p] {
				return nil, nil
			}
			return nil, fs.ErrNotExist
		},
	}
}

// TestEnvironmentGetAndExists covers the two small accessors, including the
// empty-path short circuit that keeps a missing config from stat'ing "".
func TestEnvironmentGetAndExists(t *testing.T) {
	e := fakeEnv(map[string]string{"SET": "value"}, "/there")
	if got := e.get("SET"); got != "value" {
		t.Fatalf("get = %q", got)
	}
	if got := e.get("UNSET"); got != "" {
		t.Fatalf("unset key returned %q", got)
	}
	if !e.exists("/there") {
		t.Fatal("existing path reported missing")
	}
	if e.exists("/elsewhere") {
		t.Fatal("missing path reported present")
	}
	if e.exists("") {
		t.Fatal("empty path reported present")
	}
}

// TestRepoRoot covers each resolution strategy in precedence order.
func TestRepoRoot(t *testing.T) {
	marker := func(root string) string { return filepath.Join(root, rootMarker) }
	tests := []struct {
		name  string
		vars  map[string]string
		files []string
		want  string
	}{
		{
			name:  "explicit env wins",
			vars:  map[string]string{"DOT_MCP_REPO_ROOT": "/repo", "__wd": "/other", "__home": "/home/u"},
			files: []string{marker("/repo"), marker("/other")},
			want:  "/repo",
		},
		{
			name:  "env without the marker is ignored",
			vars:  map[string]string{"DOT_MCP_REPO_ROOT": "/bogus", "__wd": "/repo/sub/dir", "__home": "/home/u"},
			files: []string{marker("/repo")},
			want:  "/repo",
		},
		{
			name:  "walks up from the working directory",
			vars:  map[string]string{"__wd": "/repo/a/b/c", "__home": "/home/u"},
			files: []string{marker("/repo")},
			want:  "/repo",
		},
		{
			name:  "chezmoi source directory as a last resort",
			vars:  map[string]string{"__wd": "/nowhere", "__home": "/home/u"},
			files: []string{"/home/u/.local/share/chezmoi"},
			want:  "/home/u/.local/share/chezmoi",
		},
		{
			name: "nothing resolvable",
			vars: map[string]string{"__wd": "/nowhere", "__home": "/home/u"},
			want: "",
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if got := fakeEnv(tc.vars, tc.files...).repoRoot(); got != tc.want {
				t.Fatalf("repoRoot = %q, want %q", got, tc.want)
			}
		})
	}
}

// TestRepoRootSurvivesBrokenSeams covers the error branches of getwd and home,
// which a real process hits when its working directory has been unlinked or
// when HOME is unset in a daemon environment.
func TestRepoRootSurvivesBrokenSeams(t *testing.T) {
	e := fakeEnv(nil)
	e.getwd = func() (string, error) { return "", errors.New("no cwd") }
	e.home = func() (string, error) { return "", errors.New("no home") }
	if got := e.repoRoot(); got != "" {
		t.Fatalf("repoRoot = %q, want empty", got)
	}
	if got := e.configPath("NOPE", "x.json"); got != "" {
		t.Fatalf("configPath = %q, want empty", got)
	}
}

// TestRepoRootStopsWalkingAtTheFilesystemRoot pins the loop's termination when
// no marker exists anywhere above the working directory.
func TestRepoRootStopsWalkingAtTheFilesystemRoot(t *testing.T) {
	e := fakeEnv(map[string]string{"__wd": "/a/b", "__home": "/home/u"})
	if got := e.repoRoot(); got != "" {
		t.Fatalf("repoRoot = %q, want empty", got)
	}
}

// TestConfigPath covers the override, both repository layouts, the deployed
// copy, and the fallback that names a canonical path for the error message.
func TestConfigPath(t *testing.T) {
	marker := filepath.Join("/repo", rootMarker)
	tests := []struct {
		name  string
		vars  map[string]string
		files []string
		want  string
	}{
		{
			name: "env override wins outright",
			vars: map[string]string{"MCP_POLICY_CONFIG": "/custom/policy.json", "__wd": "/", "__home": "/home/u"},
			want: "/custom/policy.json",
		},
		{
			name:  "checkout layout",
			vars:  map[string]string{"DOT_MCP_REPO_ROOT": "/repo", "__wd": "/", "__home": "/home/u"},
			files: []string{marker, "/repo/defaults/dot_config/dotfiles/mcp-policy.json"},
			want:  "/repo/defaults/dot_config/dotfiles/mcp-policy.json",
		},
		{
			name:  "chezmoi source layout",
			vars:  map[string]string{"DOT_MCP_REPO_ROOT": "/repo", "__wd": "/", "__home": "/home/u"},
			files: []string{marker, "/repo/dot_config/dotfiles/mcp-policy.json"},
			want:  "/repo/dot_config/dotfiles/mcp-policy.json",
		},
		{
			name:  "deployed home copy",
			vars:  map[string]string{"__wd": "/", "__home": "/home/u"},
			files: []string{"/home/u/.config/dotfiles/mcp-policy.json"},
			want:  "/home/u/.config/dotfiles/mcp-policy.json",
		},
		{
			name:  "nothing present falls back to the canonical path",
			vars:  map[string]string{"DOT_MCP_REPO_ROOT": "/repo", "__wd": "/", "__home": "/home/u"},
			files: []string{marker},
			want:  "/repo/defaults/dot_config/dotfiles/mcp-policy.json",
		},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			got := fakeEnv(tc.vars, tc.files...).configPath("MCP_POLICY_CONFIG", "mcp-policy.json")
			if got != tc.want {
				t.Fatalf("configPath = %q, want %q", got, tc.want)
			}
		})
	}
}

// TestWellKnownPath covers both the resolvable and unresolvable roots.
func TestWellKnownPath(t *testing.T) {
	e := fakeEnv(map[string]string{"DOT_MCP_REPO_ROOT": "/repo", "__wd": "/", "__home": "/h"},
		filepath.Join("/repo", rootMarker))
	if got, want := e.wellKnownPath("mcp/server-card.json"), "/repo/.well-known/mcp/server-card.json"; got != want {
		t.Fatalf("wellKnownPath = %q, want %q", got, want)
	}
	if got := fakeEnv(map[string]string{"__wd": "/", "__home": "/h"}).wellKnownPath("x"); got != "" {
		t.Fatalf("wellKnownPath = %q, want empty", got)
	}
}

// TestDotBinary covers the exported override and the PATH fallback.
func TestDotBinary(t *testing.T) {
	if got := fakeEnv(map[string]string{"DOT_MCP_DOT_BIN": "/usr/local/bin/dot"}).dotBinary(); got != "/usr/local/bin/dot" {
		t.Fatalf("dotBinary = %q", got)
	}
	if got := fakeEnv(nil).dotBinary(); got != "dot" {
		t.Fatalf("dotBinary = %q, want \"dot\"", got)
	}
}

// TestOSEnvironmentSeams exercises the production bodies once so the default
// wiring is covered rather than only its substitutes.
func TestOSEnvironmentSeams(t *testing.T) {
	e := osEnvironment()
	t.Setenv("DOT_MCP_PROBE", "probe-value")
	if got := e.get("DOT_MCP_PROBE"); got != "probe-value" {
		t.Fatalf("get = %q", got)
	}
	if _, err := e.getwd(); err != nil {
		t.Fatalf("getwd: %v", err)
	}
	if _, err := e.home(); err != nil {
		t.Fatalf("home: %v", err)
	}
	if !e.exists(t.TempDir()) {
		t.Fatal("temp dir reported missing")
	}
	// The production repoRoot walks the real tree: this module lives inside
	// the dotfiles checkout, so it must find the marker while tests run.
	if root := e.repoRoot(); root != "" && !e.exists(filepath.Join(root, rootMarker)) {
		t.Fatalf("repoRoot %q does not hold %s", root, rootMarker)
	}
}
