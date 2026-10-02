#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Snapshot current system/tooling state
# Usage: dot snapshot [--baseline|-b] [--force|-f]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/dot/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../lib/dot/ui.sh"
# shellcheck source=../../lib/dot/probe.sh
source "$SCRIPT_DIR/../../lib/dot/probe.sh"

ui_init

# _snapshot_args <args…> — set BASELINE and FORCE; anything else is ignored.
_snapshot_args() {
  BASELINE=false
  FORCE=false
  local arg
  for arg in "$@"; do
    case "$arg" in
      --baseline | -b) BASELINE=true ;;
      --force | -f) FORCE=true ;;
    esac
  done
}
_snapshot_args "$@"

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/snapshots"
mkdir -p "$STATE_DIR"

if $BASELINE; then
  output="$STATE_DIR/baseline.json"
else
  output="$STATE_DIR/snapshot_$(date +%Y%m%d_%H%M%S).json"
fi

if [[ -f "$output" && "$FORCE" != "true" ]]; then
  ui_warn "Snapshot" "${output} already exists (use --force)"
  exit 0
fi

safe() { printf '%s' "$1" | sed 's/"/\\"/g'; }

# first_line <command…> — the first line of a tool's output, or nothing if
# the tool is missing, fails or does not answer within 5 seconds (rustc's
# rustup proxy waits forever when HOME has no toolchain).
first_line() {
  dot_probe 5 "$@" | head -1 || true
}

get_version() {
  first_line "$1" --version | awk '{print $NF}'
}

os_name=$(uname -s 2>/dev/null || echo "unknown")
kernel=$(uname -r 2>/dev/null || echo "unknown")
shell_name=$(basename "${SHELL:-}" 2>/dev/null || echo "")

dot_version=""
if [[ -f "$SCRIPT_DIR/../../package.json" ]]; then
  dot_version=$(sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([0-9.]*\)".*/\1/p' "$SCRIPT_DIR/../../package.json" | head -1)
fi

cat >"$output" <<JSON
{
  "timestamp": "$(date -Iseconds)",
  "os": "$(safe "$os_name")",
  "kernel": "$(safe "$kernel")",
  "shell": "$(safe "$shell_name")",
  "dotfiles_version": "$(safe "$dot_version")",
  "tools": {
    "chezmoi": "$(safe "$(get_version chezmoi)")",
    "git": "$(safe "$(get_version git)")",
    "zsh": "$(safe "$(get_version zsh)")",
    "node": "$(safe "$(get_version node)")",
    "python": "$(safe "$(first_line python3 --version | awk '{print $2}')")",
    "rustc": "$(safe "$(first_line rustc --version | awk '{print $2}')")",
    "go": "$(safe "$(first_line go version | awk '{print $3}')")",
    "nvim": "$(safe "$(first_line nvim --version | awk '{print $2}')")",
    "tmux": "$(safe "$(first_line tmux -V | awk '{print $2}')")",
    "starship": "$(safe "$(get_version starship)")",
    "mise": "$(safe "$(get_version mise)")"
  }
}
JSON

ui_dot_banner "Diagnostics"
ui_ok "Snapshot" "$output"
