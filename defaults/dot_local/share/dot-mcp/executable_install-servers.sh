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

# install_python <dir>: one venv per server, every wheel hash-checked. A
# rejected install leaves no venv behind, so a stale or partial one never runs.
install_python() {
  local dir="$1" venv="$1/venv"
  [[ -f "$dir/requirements.txt" ]] || return 0
  rm -rf "$venv"
  if uv venv --quiet "$venv" &&
    uv pip install --python "$venv/bin/python" --require-hashes -r "$dir/requirements.txt"; then
    return 0
  fi
  rm -rf "$venv"
  echo "dot-mcp: install failed for $(basename "$dir") (hash-pinned requirements rejected)." >&2
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
