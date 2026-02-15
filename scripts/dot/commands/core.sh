#!/usr/bin/env bash
# Dotfiles CLI - Core Commands
# apply, sync, update, add, diff, status, remove, cd, edit

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"
# shellcheck source=../lib/ui.sh
source "$SCRIPT_DIR/../lib/ui.sh"

cmd_apply() {
  if [ "${1:-}" = "--no-logo" ]; then
    shift
  else
    ui_logo_dot "Dot Apply • Chezmoi"
  fi
  local src_dir
  src_dir="$(resolve_source_dir)"
  if [ -n "$src_dir" ] && [ -f "$src_dir/scripts/ops/chezmoi-apply.sh" ]; then
    exec bash "$src_dir/scripts/ops/chezmoi-apply.sh" "$@"
  fi
  exec chezmoi apply "$@"
}

cmd_sync() {
  ui_logo_dot "Dot Sync • Chezmoi"
  cmd_apply --no-logo "$@"
}

cmd_update() {
  local src_dir
  src_dir="$(resolve_source_dir)"
  if [ -n "$src_dir" ] && [ -f "$src_dir/scripts/ops/chezmoi-update.sh" ]; then
    exec bash "$src_dir/scripts/ops/chezmoi-update.sh" "$@"
  fi
  ui_logo_dot "Dot Update • Chezmoi"
  ui_info "Updating dotfiles..."
  exec chezmoi update "$@"
}

cmd_add() {
  if [ -z "$1" ]; then
    ui_logo_dot "Dot Add • Chezmoi"
    ui_error "Usage: dot add <file>"
    printf "\n"
    ui_info "Add a file to the chezmoi source directory."
    ui_info "The file will be managed by chezmoi from now on."
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
  ui_logo_dot "Dot Diff • Chezmoi"
  exec chezmoi diff "$@"
}

cmd_status() {
  ui_logo_dot "Dot Status • Chezmoi"
  exec chezmoi status "$@"
}

cmd_remove() {
  ui_logo_dot "Dot Remove • Chezmoi"
  run_script "scripts/ops/chezmoi-remove.sh" "Remove helper" "$@"
}

cmd_cd() {
  local src_dir
  src_dir="$(resolve_source_dir)"
  if [ -n "$src_dir" ]; then
    echo "$src_dir"
  else
    ui_logo_dot "Dot Cd • Core"
    ui_error "Dotfiles source not found."
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
    ui_logo_dot "Dot Edit • Core"
    ui_error "No editor found. Set \$EDITOR to open $src_dir."
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
    ui_logo_dot "Dot Core"
    ui_error "Unknown core command: ${1:-}"
    exit 1
    ;;
esac
