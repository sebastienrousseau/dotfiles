#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck shell=bash
# Sourced by mcp-doctor.sh; inherits set -euo pipefail
# The other MCP configs Claude Code reads besides the managed
# mcp_servers.json: ~/.claude.json (user scope and each project's scope),
# the .mcp.json of every project ~/.claude.json knows, and the working
# directory's .mcp.json. Each one that declares servers is copied to a
# scratch file as {mcpServers: …}, so the same per-config checks run on it.
# Uses CLAUDE_USER_CONFIG, MCP_PROJECT_CONFIG, MCP_CONFIG and _mcp_json_ok.

CLAUDE_USER_CONFIG="${CLAUDE_USER_CONFIG:-$HOME/.claude.json}"
MCP_PROJECT_CONFIG="${MCP_PROJECT_CONFIG:-$PWD/.mcp.json}"
MCP_SOURCE_LABELS=()
MCP_SOURCE_FILES=()
MCP_SEEN_FILES=()

# _mcp_add_source <dir> <label> <jq filter> <input> [project key]: keep the
# servers <filter> selects from <input> when there is at least one.
_mcp_add_source() {
  local dest="$1/source-${#MCP_SOURCE_FILES[@]}.json"
  jq -e --arg k "${5:-}" "{mcpServers: ($3)} | select(.mcpServers | type == \"object\" and length > 0)" \
    "$4" >"$dest" 2>/dev/null || return 0
  MCP_SOURCE_LABELS+=("$2")
  MCP_SOURCE_FILES+=("$dest")
}

# _mcp_seen <file>: 0 when <file> is the primary config or already queued.
_mcp_seen() {
  local f
  [[ "$1" -ef "$MCP_CONFIG" ]] && return 0
  for f in ${MCP_SEEN_FILES[@]+"${MCP_SEEN_FILES[@]}"}; do
    [[ "$1" -ef "$f" ]] && return 0
  done
  return 1
}

# _mcp_add_project_file <dir> <path>: a project .mcp.json, once.
_mcp_add_project_file() {
  [[ -f "$2" ]] || return 0
  _mcp_seen "$2" && return 0
  MCP_SEEN_FILES+=("$2")
  _mcp_json_ok "$2" || return 0
  _mcp_add_source "$1" "$2" '.mcpServers // {}' "$2"
}

# _mcp_collect_sources <dir>: fill MCP_SOURCE_LABELS / MCP_SOURCE_FILES.
_mcp_collect_sources() {
  local key
  if _mcp_json_ok "$CLAUDE_USER_CONFIG"; then
    _mcp_add_source "$1" "user scope ($CLAUDE_USER_CONFIG)" '.mcpServers // {}' "$CLAUDE_USER_CONFIG"
    while IFS= read -r key; do
      [[ -n "$key" ]] || continue
      _mcp_add_source "$1" "project $key ($CLAUDE_USER_CONFIG)" '.projects[$k].mcpServers // {}' \
        "$CLAUDE_USER_CONFIG" "$key"
      _mcp_add_project_file "$1" "$key/.mcp.json"
    done < <(jq -r '(.projects // {}) | keys[]' "$CLAUDE_USER_CONFIG" 2>/dev/null || true)
  fi
  _mcp_add_project_file "$1" "$MCP_PROJECT_CONFIG"
}
