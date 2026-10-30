#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# `dot ai login [tool…]`: authenticate the installed AI tools, every roster
# tool or the ones named. The tools and their login commands come from the
# roster (plugins/ai/roster.toml, `login`); a tool that signs in on first use
# is checked with `<bin> --version`.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/dot/ui.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/dot/ai-roster.sh"

# setup_tool <title> <bin>: run the tool's login command, or its version
# probe; a login needs a terminal.
setup_tool() {
  local name="$1" bin="$2" login
  local -a argv
  login="$(ai_roster_login "$bin" || true)"
  read -ra argv <<<"${login:-$bin --version}"
  ui_section "Setting up $name"
  if ! command -v "$bin" >/dev/null 2>&1; then
    ui_err "$name" "Binary not found. Run 'dot ai install $bin' first."
    return 0
  fi
  if [[ -n "$login" && ! -t 0 ]]; then
    ui_info "$name" "non-interactive shell; skipping login. Run '$login' in a terminal."
    return 0
  fi
  ui_info "Tool found, initiating authentication..."
  "${argv[@]}" || ui_warn "$name" "Setup/Auth skipped or failed."
}

# _wanted <bin>: true when no tool was named, or this one was.
_wanted() {
  local w
  [[ ${#WANT[@]} -eq 0 ]] && return 0
  for w in "${WANT[@]}"; do [[ "$w" != "$1" ]] || return 0; done
  return 1
}

WANT=()
for arg in "$@"; do
  bin="$(ai_roster_bin "$arg")" || {
    ui_err "dot ai login" "'$arg' is not a roster tool (dot ai list)"
    exit 2
  }
  WANT+=("$bin")
done

ui_header "Universal AI Toolchain Setup"
for row in "${AI_ROSTER_STATUS[@]}"; do
  IFS='|' read -r _ _ title bin _ <<<"$row"
  if _wanted "$bin"; then setup_tool "$title" "$bin"; fi
done

ui_header "AI Setup Complete"
ui_info "All tools are ready. Use 'dot ai' to check status."
