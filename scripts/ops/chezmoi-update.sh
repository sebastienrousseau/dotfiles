#!/usr/bin/env bash
set -euo pipefail

args=()
if [[ -n "${DOTFILES_CHEZMOI_UPDATE_FLAGS:-}" ]]; then
  # Safely parse space-separated flags into array
  read -ra flag_array <<<"$DOTFILES_CHEZMOI_UPDATE_FLAGS"
  args+=("${flag_array[@]}")
fi

if [[ "${DOTFILES_CHEZMOI_VERBOSE:-0}" = "1" ]]; then
  args+=("--verbose")
fi

ASYNC=false
if [[ "${DOTFILES_ASYNC_UPDATE:-0}" = "1" ]]; then
  ASYNC=true
fi
if [[ "${1:-}" == "--async" ]]; then
  ASYNC=true
  shift
fi

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/update"
mkdir -p "$STATE_DIR"
LOG_FILE="$STATE_DIR/last.log"
STATUS_FILE="$STATE_DIR/last.status"
NOTICE_FILE="$STATE_DIR/notice"

run_update() {
  echo "Updating dotfiles..."
  chezmoi update "${args[@]}"
}

if $ASYNC; then
  echo "Update running in background..."
  {
    run_update
    echo $? >"$STATUS_FILE"
  } >"$LOG_FILE" 2>&1 &
  date -u +%Y-%m-%dT%H:%M:%SZ >"$NOTICE_FILE"
  disown || true
  exit 0
fi

run_update
echo $? >"$STATUS_FILE"
