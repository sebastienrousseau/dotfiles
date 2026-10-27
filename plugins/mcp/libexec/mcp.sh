#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Dotfiles CLI - MCP Commands (moved from meta.sh, P2.1)
# mcp [doctor|registry|serve]; plugins/mcp/dot-mcp maps the ADR-020
# spellings onto these.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../lib/dot/utils.sh
source "$SCRIPT_DIR/../../../lib/dot/utils.sh"

cmd_mcp() {
  local subcommand="${1:-doctor}"
  if [[ "${1:-}" == --* ]] || [[ "${1:-}" == -* ]] || [[ -z "${1:-}" ]]; then
    subcommand="doctor"
  else
    shift || true
  fi
  case "$subcommand" in
    doctor)
      if [[ "${1:-}" == "doctor" ]]; then
        shift || true
      fi
      run_script "scripts/diagnostics/mcp-doctor.sh" "MCP doctor script" "$@"
      ;;
    registry)
      local repo_root registry_file json_mode=0
      repo_root="$(resolve_chezmoi_source_dir)"
      [[ -z "$repo_root" ]] && repo_root="$(require_source_dir)"
      registry_file="${MCP_REGISTRY_CONFIG:-$repo_root/dot_config/dotfiles/mcp-registry.json}"
      if [[ "${1:-}" == "registry" ]]; then
        shift || true
      fi
      if [[ "${1:-}" == "--json" || "${1:-}" == "-j" ]]; then
        json_mode=1
      fi
      if [[ ! -f "$registry_file" ]]; then
        die "MCP registry not found: $registry_file"
      fi
      if [[ "$json_mode" -eq 1 ]]; then
        exec cat "$registry_file"
      fi
      if command -v jq >/dev/null 2>&1; then
        ui_header "MCP Registry"
        jq -r '
          .servers
          | to_entries[]
          | "\(.key)\t\(.value.transport)\t\(.value.launcher)\t\(.value.package // .value.url // "local")"
        ' "$registry_file" | while IFS=$'\t' read -r name transport launcher target; do
          ui_ok "$name" "$transport via $launcher -> $target"
        done
      else
        exec cat "$registry_file"
      fi
      ;;
    serve)
      cmd_mcp_serve "$@"
      ;;
    *)
      echo "Usage: dot mcp [doctor|registry|serve]" >&2
      exit 1
      ;;
  esac
}

# cmd_mcp_serve — exec the stdio MCP server (dot-mcp).
#
# This is the transport `.well-known/mcp/server-card.json` advertises:
# JSON-RPC 2.0 over newline-delimited frames on stdin/stdout. Nothing this
# function prints may reach stdout, because stdout is the protocol stream from
# the moment the client launches us — every message below goes to stderr, and
# the server is exec'd so it owns the descriptors outright.
#
# The binary is deployed by run_onchange_26-build-dot-mcp.sh. When it is not
# built yet and a Go toolchain is available, it is built on demand into the
# user cache rather than failing: a client that trusted the card must get a
# server, not an error.
cmd_mcp_serve() {
  local repo_root bin src cache
  # The server wants the checkout, not the chezmoi source inside it
  # (defaults/). Deriving it as the chezmoi source's parent named the
  # directory above the checkout when there was no .chezmoiroot.
  repo_root="$(require_source_dir)"

  # Tell the server which tree it is serving, and which CLI to shell out to,
  # so it never has to guess either.
  export DOT_MCP_REPO_ROOT="$repo_root"
  export DOT_MCP_DOT_BIN="${DOT_MCP_DOT_BIN:-$(command -v dot || echo dot)}"

  if bin="$(command -v dot-mcp 2>/dev/null)"; then
    exec "$bin" serve "$@"
  fi
  if [[ -x "$HOME/.local/bin/dot-mcp" ]]; then
    exec "$HOME/.local/bin/dot-mcp" serve "$@"
  fi

  src="$repo_root/defaults/dot_local/share/dot-mcp"
  [[ -d "$src" ]] || src="$HOME/.local/share/dot-mcp"
  if [[ -f "$src/main.go" ]] && has_command go; then
    cache="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles"
    mkdir -p "$cache"
    echo "dot mcp serve: building dot-mcp (first run)…" >&2
    if (cd "$src" && go build -o "$cache/dot-mcp" .) >&2; then
      exec "$cache/dot-mcp" serve "$@"
    fi
  fi

  echo "dot mcp serve: dot-mcp is not built. Run 'chezmoi apply' (or 'go build' in $src) to install it." >&2
  exit 1
}

cmd_mcp "$@"
