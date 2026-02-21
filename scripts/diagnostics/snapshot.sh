#!/usr/bin/env bash
# Snapshot current system/tooling state
# Usage: dot snapshot [--baseline] [--force]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"

ui_init

BASELINE=false
FORCE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --baseline)
      BASELINE=true
      shift
      ;;
    --force)
      FORCE=true
      shift
      ;;
    *) shift ;;
  esac
done

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

get_version() {
  local cmd="$1"
  if command -v "$cmd" >/dev/null 2>&1; then
    "$cmd" --version 2>/dev/null | head -1 | awk '{print $NF}'
  else
    echo ""
  fi
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
    "python": "$(safe "$(python3 --version 2>/dev/null | awk '{print $2}')")",
    "rustc": "$(safe "$(rustc --version 2>/dev/null | awk '{print $2}')")",
    "go": "$(safe "$(go version 2>/dev/null | awk '{print $3}')")",
    "nvim": "$(safe "$(nvim --version 2>/dev/null | head -1 | awk '{print $2}')")",
    "tmux": "$(safe "$(tmux -V 2>/dev/null | awk '{print $2}')")",
    "starship": "$(safe "$(get_version starship)")",
    "mise": "$(safe "$(get_version mise)")"
  }
}
JSON

ui_ok "Snapshot" "$output"
