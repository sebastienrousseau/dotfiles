#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
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

# Apply unattended by default (see chezmoi-apply.sh). `chezmoi update` runs
# `apply` internally, so without --force it blocks on the "<file> has
# changed since chezmoi last wrote it" prompt — and `dot update` is often
# run from cron/CI/--async with no TTY, where that prompt aborts the run.
# --force makes updates land like an OS package-manager update; opt back
# into prompting with DOTFILES_INTERACTIVE_APPLY=1.
if [[ "${DOTFILES_INTERACTIVE_APPLY:-0}" != "1" ]]; then
  _has_force=0
  if [[ ${#args[@]} -gt 0 ]]; then
    for _a in "${args[@]}"; do [[ "$_a" == "--force" ]] && _has_force=1; done
  fi
  [[ "$_has_force" == "0" ]] && args+=("--force")
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
