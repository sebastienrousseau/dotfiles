#!/usr/bin/env bash
## Dotfiles Core Commands — Core chezmoi operations for the dot CLI.
##
## Provides apply, sync, update, add, diff, status, remove, cd, and edit
## commands for managing dotfiles through the unified dot interface.
##
## # Requirements
## - chezmoi: Dotfiles manager
## - bash 4+: Shell interpreter
##
## # Usage
## dot apply                   # Apply dotfiles
## dot sync                    # Alias for apply
## dot update                  # Pull and apply updates
## dot add <file>              # Add file to chezmoi
## dot diff                    # Show pending changes
## dot status                  # Show configuration drift
## dot remove <file>           # Remove managed file
## dot cd                      # Print source directory
## dot edit                    # Open source in editor
##
## # Platform Notes
## - All platforms: Full chezmoi support

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"

if [[ "${1:-}" != "cd" ]]; then
  dot_ui_command_banner "Core" "${1:-}"
fi

cmd_apply() {
  local src_dir
  src_dir="$(resolve_source_dir)"
  if [ -n "$src_dir" ] && [ -f "$src_dir/scripts/ops/chezmoi-apply.sh" ]; then
    exec bash "$src_dir/scripts/ops/chezmoi-apply.sh" "$@"
  fi
  exec chezmoi apply "$@"
}

cmd_sync() {
  cmd_apply "$@"
}

cmd_update() {
  local src_dir
  src_dir="$(resolve_source_dir)"
  if [ -n "$src_dir" ] && [ -f "$src_dir/scripts/ops/chezmoi-update.sh" ]; then
    exec bash "$src_dir/scripts/ops/chezmoi-update.sh" "$@"
  fi
  echo "Updating Dotfiles..."
  exec chezmoi update "$@"
}

cmd_add() {
  if [ -z "${1:-}" ]; then
    echo "Usage: dot add <file>"
    echo ""
    echo "Add a file to the chezmoi source directory."
    echo "The file will be managed by chezmoi from now on."
    exit 1
  fi
  exec chezmoi add "$@"
}

cmd_diff() {
  local src_dir
  src_dir="$(resolve_source_dir)"
  if [ -n "$src_dir" ] && [ -f "$src_dir/scripts/ops/chezmoi-diff.sh" ]; then
    exec bash "$src_dir/scripts/ops/chezmoi-diff.sh" "$@"
  fi
  exec chezmoi diff "$@"
}

cmd_status() {
  local out
  out="$(chezmoi status "$@" || true)"
  if [[ -z "$out" ]]; then
    ui_header "Dotfiles Status"
    ui_ok "Clean" "no local drift detected"
  else
    ui_header "Dotfiles Status"
    printf "%s\n" "$out"
  fi
}

cmd_remove() {
  run_script "scripts/ops/chezmoi-remove.sh" "Remove helper" "$@"
}

cmd_cd() {
  local src_dir
  src_dir="$(resolve_source_dir)"
  if [ -n "$src_dir" ]; then
    echo "$src_dir"
  else
    echo "Dotfiles source not found." >&2
    exit 1
  fi
}

cmd_edit() {
  local src_dir
  src_dir="$(require_source_dir)"
  if [ -n "${EDITOR:-}" ]; then
    exec "$EDITOR" "$src_dir"
  elif has_command nvim; then
    exec nvim "$src_dir"
  elif has_command vim; then
    exec vim "$src_dir"
  else
    echo "No editor found. Set \$EDITOR to open $src_dir."
    exit 1
  fi
}

# Dispatch
case "${1:-}" in
  apply)
    shift
    cmd_apply "$@"
    ;;
  sync)
    shift
    cmd_sync "$@"
    ;;
  update)
    shift
    cmd_update "$@"
    ;;
  add)
    shift
    cmd_add "$@"
    ;;
  diff)
    shift
    cmd_diff "$@"
    ;;
  status)
    shift
    cmd_status "$@"
    ;;
  remove)
    shift
    cmd_remove "$@"
    ;;
  cd)
    shift
    cmd_cd "$@"
    ;;
  edit)
    shift
    cmd_edit "$@"
    ;;
  *)
    echo "Unknown core command: ${1:-}" >&2
    exit 1
    ;;
esac
