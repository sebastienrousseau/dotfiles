// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

package main

import (
	"fmt"
	"net/url"
	"path/filepath"
	"regexp"
	"strings"
)

// Call is one tool call, as Claude Code, Codex and Gemini CLI send it to a
// PreToolUse (BeforeTool) hook, or a prompt event (UserPromptSubmit,
// BeforeAgent: Event and Session; the prompt itself is never read).
type Call struct {
	Tool    string         `json:"tool_name"`
	Input   map[string]any `json:"tool_input"`
	Cwd     string         `json:"cwd"`
	Event   string         `json:"hook_event_name"`
	Session string         `json:"session_id"`
}

// toolClasses maps each agent's tool names to the classes a policy names.
var toolClasses = map[string]string{
	"Bash": "shell", "run_shell_command": "shell", "exec_command": "shell", "shell": "shell",
	"Read": "read", "read_file": "read", "read_many_files": "read", "NotebookRead": "read",
	"LS": "read", "list_directory": "read",
	"Write": "write", "write_file": "write", "Edit": "write", "MultiEdit": "write",
	"NotebookEdit": "write", "replace": "write", "apply_patch": "write",
	"Grep": "search", "Glob": "search", "glob": "search", "grep": "search",
	"search_file_content": "search",
	"WebFetch":            "fetch", "web_fetch": "fetch", "WebSearch": "fetch", "google_web_search": "fetch",
}

// ToolClass is the class of a tool name; "mcp" for MCP tools, and the name
// itself for any other.
func ToolClass(tool string) string {
	if c, ok := toolClasses[tool]; ok {
		return c
	}
	if strings.HasPrefix(tool, "mcp__") || strings.HasPrefix(tool, "mcp_") {
		return "mcp"
	}
	return tool
}

// Env is what patterns may refer to: ~ is Home, {cwd} the session's
// directory.
type Env struct{ Home, Cwd string }

func (e Env) expand(p string) string {
	if p == "~" || strings.HasPrefix(p, "~/") {
		p = e.Home + p[1:]
	}
	return strings.ReplaceAll(p, "{cwd}", e.Cwd)
}

// Decide returns why the call is denied, or "" when the rules allow it.
func Decide(r Rules, c Call, home string) string {
	env := Env{Home: home, Cwd: filepath.Clean(c.Cwd)}
	class := ToolClass(c.Tool)
	if why := decideTool(r, c.Tool, class); why != "" {
		return why
	}
	for _, p := range callPaths(c, env.Cwd) {
		if why := decidePath(r, p, env); why != "" {
			return why
		}
	}
	if class == "shell" {
		if why := decideCommand(r, str(c.Input, "command")); why != "" {
			return why
		}
	}
	for _, h := range callHosts(c, class) {
		if why := decideHost(r, h); why != "" {
			return why
		}
	}
	return ""
}

func decideTool(r Rules, tool, class string) string {
	names := []string{class, tool}
	for _, n := range names {
		if matchAny(r.ToolsDeny, n, true, nil) {
			return fmt.Sprintf("tool %s is denied", tool)
		}
	}
	for _, n := range names {
		if matchAny(r.Tools, n, true, nil) {
			return ""
		}
	}
	return fmt.Sprintf("tool %s (%s) is not allowed", tool, class)
}

func decidePath(r Rules, p string, env Env) string {
	if matchAny(r.PathsDeny, p, true, env.expand) {
		return fmt.Sprintf("path %s is denied", p)
	}
	if len(r.PathsAllow) > 0 && !matchAny(r.PathsAllow, p, true, env.expand) {
		return fmt.Sprintf("path %s is outside the allowed paths", p)
	}
	return ""
}

func decideCommand(r Rules, cmd string) string {
	segs := commandSegments(cmd)
	for _, s := range append([]string{strings.TrimSpace(cmd)}, segs...) {
		if matchAny(r.CommandsDeny, s, false, nil) {
			return fmt.Sprintf("command %q is denied", s)
		}
	}
	if len(r.CommandsAllow) == 0 {
		return ""
	}
	for _, s := range segs {
		if !matchAny(r.CommandsAllow, s, false, nil) {
			return fmt.Sprintf("command %q is not allowed", s)
		}
	}
	return ""
}

func decideHost(r Rules, h string) string {
	if matchAny(r.HostsDeny, h, true, nil) {
		return fmt.Sprintf("host %s is denied", h)
	}
	if len(r.HostsAllow) > 0 && !matchAny(r.HostsAllow, h, true, nil) {
		return fmt.Sprintf("host %s is not allowed", h)
	}
	return ""
}

// pathKeys are the tool_input keys that name a file or directory.
var pathKeys = []string{"file_path", "path", "notebook_path", "absolute_path", "dir_path"}

var patchFileRe = regexp.MustCompile(`(?m)^\*\*\* (?:Add File|Update File|Delete File|Move to): (.+)$`)

// callPaths is every path the call touches, absolute and cleaned.
func callPaths(c Call, cwd string) []string {
	var raw []string
	for _, k := range pathKeys {
		if v := str(c.Input, k); v != "" {
			raw = append(raw, v)
		}
	}
	if list, ok := c.Input["paths"].([]any); ok {
		for _, v := range list {
			if s, ok := v.(string); ok {
				raw = append(raw, s)
			}
		}
	}
	if c.Tool == "apply_patch" {
		for _, m := range patchFileRe.FindAllStringSubmatch(str(c.Input, "command"), -1) {
			raw = append(raw, strings.TrimSpace(m[1]))
		}
	}
	out := make([]string, 0, len(raw))
	for _, p := range raw {
		if !filepath.IsAbs(p) {
			p = filepath.Join(cwd, p)
		}
		out = append(out, filepath.Clean(p))
	}
	return out
}

var urlRe = regexp.MustCompile(`https?://[^\s'"<>)]+`)

// callHosts is every host the call reaches: a fetch's url, and each URL
// written into a shell command.
func callHosts(c Call, class string) []string {
	var urls []string
	switch class {
	case "fetch":
		if u := str(c.Input, "url"); u != "" {
			urls = append(urls, u)
		}
	case "shell":
		urls = urlRe.FindAllString(str(c.Input, "command"), -1)
	}
	var hosts []string
	for _, raw := range urls {
		u, err := url.Parse(raw)
		if err != nil || u.Hostname() == "" {
			hosts = append(hosts, raw)
			continue
		}
		hosts = append(hosts, strings.ToLower(u.Hostname()))
	}
	return hosts
}

var segmentSplit = regexp.MustCompile(`&&|\|\||[;|&\n]|\$\(|` + "`")

var assignRe = regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_]*=\S*\s+`)

// commandSegments splits a shell command at ; && || | & newlines, $( and
// backticks, and drops leading VAR=value assignments from each part. It is
// a guardrail, not a shell parser: quoting is not understood, so a
// separator inside quotes splits too (which only makes it stricter).
func commandSegments(cmd string) []string {
	var out []string
	for _, s := range segmentSplit.Split(cmd, -1) {
		s = strings.TrimSpace(strings.TrimRight(strings.TrimSpace(s), ")"))
		for assignRe.MatchString(s) {
			s = assignRe.ReplaceAllString(s, "")
		}
		if s != "" {
			out = append(out, s)
		}
	}
	return out
}

func str(m map[string]any, k string) string {
	s, _ := m[k].(string)
	return s
}
