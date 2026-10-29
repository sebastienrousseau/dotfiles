#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Installs the third-party MCP servers that ~/.config/claude/mcp_servers.json
# runs, from the committed manifests next to this script, so nothing is
# fetched unverified at launch:
#   node/package-lock.json          npm ci --ignore-scripts (sha512 integrity)
#   python/<server>/requirements.txt  uv pip install --require-hashes into
#                                     python/<server>/venv
# uvx does not check the hashes in a --with-requirements file (seen with
# uv 0.12: a wrong hash still installs), so each Python server gets its own
# venv here instead and the config runs the installed binary.
# Run by run_onchange_26-build-dot-mcp.sh when a manifest changes; safe to
# re-run by hand. A tool that is not installed is skipped with a notice.
set -euo pipefail

ROOT="${DOT_MCP_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

# install_node: the npm servers, exactly as package-lock.json pins them.
install_node() {
  local dir="$ROOT/node"
  [[ -f "$dir/package-lock.json" ]] || return 0
  if ! command -v npm >/dev/null 2>&1; then
    echo "dot-mcp: npm not found; skipping the npm MCP servers (memory)." >&2
    return 0
  fi
  if ! (cd "$dir" && npm ci --ignore-scripts --no-audit --no-fund); then
    echo "dot-mcp: npm ci failed for the npm MCP servers (memory)." >&2
    return 1
  fi
}

# venv_install <venv> <requirements> [uv flag…]: a fresh venv, every wheel
# hash-checked.
venv_install() {
  local venv="$1" req="$2"
  shift 2
  rm -rf "$venv"
  uv venv --quiet "$venv" &&
    uv pip install --python "$venv/bin/python" --require-hashes -r "$req" "$@"
}

# install_python <dir>: one venv per server. uv reuses an unpacked wheel from
# its cache without checking it is whole, so once an entry loses a file (an
# OS purge of a cache under /tmp) every cached install fails the same way;
# --refresh and --reinstall reuse it too (uv 0.13). One retry with --no-cache
# downloads fresh, still hash-checked, and leaves the cache alone. A failed
# install leaves no venv behind, so a stale or partial one never runs.
install_python() {
  local dir="$1" venv="$1/venv" name
  [[ -f "$dir/requirements.txt" ]] || return 0
  name="$(basename "$dir")"
  venv_install "$venv" "$dir/requirements.txt" && return 0
  echo "dot-mcp: retrying $name without the uv cache." >&2
  venv_install "$venv" "$dir/requirements.txt" --no-cache && return 0
  rm -rf "$venv"
  echo "dot-mcp: install failed for $name; uv's error above says why." >&2
  return 1
}

main() {
  local rc=0 dir
  install_node || rc=1
  if ! command -v uv >/dev/null 2>&1; then
    echo "dot-mcp: uv not found; skipping the Python MCP servers (git, sqlite)." >&2
    return "$rc"
  fi
  for dir in "$ROOT"/python/*/; do
    install_python "${dir%/}" || rc=1
  done
  return "$rc"
}

main "$@"
