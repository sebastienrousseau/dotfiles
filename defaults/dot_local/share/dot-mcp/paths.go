// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau
//
// Filesystem resolution: where the dotfiles tree lives and where the JSON
// configuration the resources expose is found. The layout differs between a
// git checkout (`<root>/defaults/dot_config/dotfiles/...`) and a chezmoi
// source directory (`<root>/dot_config/dotfiles/...`), so both are probed.
package main

import (
	"io"
	"os"
	"os/exec"
	"path/filepath"
)

// rootMarker is the file whose presence identifies a dotfiles checkout. It is
// the MCP audit script itself, so a tree that cannot answer `mcp-doctor` is
// never mistaken for a root.
const rootMarker = "scripts/diagnostics/mcp-doctor.sh"

// environment is the process environment as this server sees it, injected so
// tests need not mutate the real one.
type environment struct {
	lookup   func(string) (string, bool)
	home     func() (string, error)
	stat     func(string) (os.FileInfo, error)
	lookPath func(string) (string, error)
	isScript func(string) bool
}

// osEnvironment reads the real process environment.
func osEnvironment() environment {
	return environment{
		lookup:   os.LookupEnv,
		home:     os.UserHomeDir,
		stat:     os.Stat,
		lookPath: exec.LookPath,
		isScript: isScript,
	}
}

// isScript reports whether the file at path starts with "#!". The dotfiles
// CLI is a script; Graphviz installs a binary that is also named dot.
func isScript(path string) bool {
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	defer f.Close()
	head := make([]byte, 2)
	if _, err := io.ReadFull(f, head); err != nil {
		return false
	}
	return string(head) == "#!"
}

// get returns an environment variable, or "" when unset.
func (e environment) get(key string) string {
	v, _ := e.lookup(key)
	return v
}

// exists reports whether path is a regular file or directory that can be
// stat'ed.
func (e environment) exists(path string) bool {
	if path == "" {
		return false
	}
	_, err := e.stat(path)
	return err == nil
}

// repoRoot is the dotfiles tree named by DOT_MCP_REPO_ROOT, which `dot mcp
// serve` exports, when it holds rootMarker. Nothing else is searched: walking
// up from the working directory let any directory carrying the marker (a
// cloned repository, say) choose the tree this server reads and serves.
// It returns "" when unset; callers degrade to an explicit error rather than
// guessing, because a wrong root silently serves another tree's configuration.
func (e environment) repoRoot() string {
	if v := e.get("DOT_MCP_REPO_ROOT"); e.exists(filepath.Join(v, rootMarker)) {
		return v
	}
	return ""
}

// configPath locates one of the dotfiles JSON configuration files by its base
// name. envKey, when set in the environment, wins outright — the existing bash
// commands honour the same overrides (MCP_REGISTRY_CONFIG, MCP_POLICY_CONFIG,
// AGENT_PROFILE_CONFIG) and the two surfaces must agree. Otherwise the
// checkout layout, the chezmoi-source layout and the deployed ~/.config copy
// are probed in that order.
func (e environment) configPath(envKey, base string) string {
	if v := e.get(envKey); v != "" {
		return v
	}
	root := e.repoRoot()
	candidates := []string{}
	if root != "" {
		candidates = append(candidates,
			filepath.Join(root, "defaults", "dot_config", "dotfiles", base),
			filepath.Join(root, "dot_config", "dotfiles", base),
		)
	}
	if home, err := e.home(); err == nil {
		candidates = append(candidates, filepath.Join(home, ".config", "dotfiles", base))
	}
	for _, c := range candidates {
		if e.exists(c) {
			return c
		}
	}
	if len(candidates) > 0 {
		return candidates[0] // report the canonical path in the error
	}
	return ""
}

// wellKnownPath locates a discovery card under .well-known/ in the checkout.
// Only the checkout carries these; a deployed home directory does not, so an
// unresolvable root yields "".
func (e environment) wellKnownPath(rel string) string {
	root := e.repoRoot()
	if root == "" {
		return ""
	}
	return filepath.Join(root, ".well-known", rel)
}

// dotBinary is the `dot` executable the tools shell out to. `dot mcp serve`
// exports its own resolved path so the server calls the same CLI that launched
// it. A directly-launched binary takes the dot on PATH only when it is a
// script (Graphviz installs a binary named dot), else the served checkout's
// bin/dot, else the installed ~/.local/bin/dot; a bare "dot" is the last
// resort, when none of those exists.
func (e environment) dotBinary() string {
	if v := e.get("DOT_MCP_DOT_BIN"); v != "" {
		return v
	}
	if p, err := e.lookPath("dot"); err == nil && e.isScript(p) {
		return p
	}
	var candidates []string
	if root := e.repoRoot(); root != "" {
		candidates = append(candidates, filepath.Join(root, "bin", "dot"))
	}
	if home, err := e.home(); err == nil && home != "" {
		candidates = append(candidates, filepath.Join(home, ".local", "bin", "dot"))
	}
	for _, c := range candidates {
		if e.exists(c) {
			return c
		}
	}
	return "dot"
}
