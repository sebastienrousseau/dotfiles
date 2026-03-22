#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# dot restore - Restore dotfiles from backup or previous state
# Usage: dot restore [--list|-l|--latest|-L|<backup-id>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"
# shellcheck source=../lib/log.sh
source "$SCRIPT_DIR/../lib/log.sh"

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
BACKUP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/backups"
CHEZMOI_SOURCE="${HOME}/.local/share/chezmoi"

ui_init

usage() {
  echo "Usage: dot restore [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --list, -l       List available backups"
  echo "  --latest, -L     Restore from latest backup"
  echo "  --git, -g <ref>  Restore from git ref (commit, tag, branch)"
  echo "  --diff, -d <ref> Show diff between current and ref"
  echo "  --dry-run, -n    Show what would be restored"
  echo "  -h, --help       Show this help"
  echo ""
  echo "Examples:"
  echo "  dot restore --list"
  echo "  dot restore --latest"
  echo "  dot restore --git HEAD~1"
  echo "  dot restore --git v0.2.470"
}

list_backups() {
  if [[ ! -d "$BACKUP_DIR" ]]; then
    log_warn "No backups found at $BACKUP_DIR"
    return 1
  fi

  ui_header "Available Backups"
  echo "─────────────────────────────────────────"

  while IFS= read -r backup; do
    echo "  $backup"
  done < <(list_backup_names)

  echo ""
  echo ""
  ui_header "Git History (last 10)"
  echo "─────────────────────────────────────────"

  if [[ -d "$DOTFILES_DIR/.git" ]]; then
    git -C "$DOTFILES_DIR" log --oneline -10
  elif [[ -d "$CHEZMOI_SOURCE/.git" ]]; then
    git -C "$CHEZMOI_SOURCE" log --oneline -10
  fi
}

restore_from_git() {
  local ref="$1"
  local dry_run="${2:-false}"
  local source_dir

  if [[ -d "$DOTFILES_DIR/.git" ]]; then
    source_dir="$DOTFILES_DIR"
  elif [[ -d "$CHEZMOI_SOURCE/.git" ]]; then
    source_dir="$CHEZMOI_SOURCE"
  else
    log_error "No git repository found"
    return 1
  fi

  log_info "Restoring from git ref: $ref"

  if $dry_run; then
    log_info "Dry run - showing changes:"
    git -C "$source_dir" diff "$ref" --stat
    return 0
  fi

  # Create backup first
  create_backup

  # Restore
  git -C "$source_dir" checkout "$ref" -- .
  log_success "Restored from $ref"

  # Re-apply chezmoi
  if has_command chezmoi; then
    log_info "Re-applying chezmoi..."
    chezmoi apply
  fi
}

show_diff() {
  local ref="$1"
  local source_dir

  if [[ -d "$DOTFILES_DIR/.git" ]]; then
    source_dir="$DOTFILES_DIR"
  elif [[ -d "$CHEZMOI_SOURCE/.git" ]]; then
    source_dir="$CHEZMOI_SOURCE"
  else
    log_error "No git repository found"
    return 1
  fi

  git -C "$source_dir" diff "$ref"
}

create_backup() {
  local backup_name
  backup_name="backup-$(date +%Y%m%d_%H%M%S)"
  local backup_path="$BACKUP_DIR/$backup_name"
  local rel_path

  mkdir -p "$backup_path"

  log_info "Creating backup: $backup_name"

  # Backup key config files
  local files_to_backup=(
    "$HOME/.zshrc"
    "$HOME/.config/zsh"
    "$HOME/.config/nvim"
    "$HOME/.config/git"
    "$HOME/.gitconfig"
  )

  for f in "${files_to_backup[@]}"; do
    if [[ -e "$f" ]]; then
      rel_path="${f#"$HOME"/}"
      mkdir -p "$backup_path/$(dirname "$rel_path")"
      cp -r "$f" "$backup_path/$rel_path" 2>/dev/null || true
    fi
  done

  log_success "Backup created at $backup_path"
}

restore_latest() {
  if [[ ! -d "$BACKUP_DIR" ]]; then
    log_error "No backups found"
    return 1
  fi

  local latest
  latest=$(list_backup_names | head -1)

  if [[ -z "$latest" ]]; then
    log_error "No backups found"
    return 1
  fi

  log_info "Restoring from: $latest"

  local backup_path="$BACKUP_DIR/$latest"
  local item rel_path target
  while IFS= read -r -d '' item; do
    rel_path="${item#"$backup_path"/}"
    target="$HOME/$rel_path"
    mkdir -p "$(dirname "$target")"
    cp -r "$item" "$target"
    log_success "Restored: $rel_path"
  done < <(find "$backup_path" -mindepth 1 -maxdepth 1 -print0)
}

list_backup_names() {
  local backup_path

  shopt -s nullglob
  for backup_path in "$BACKUP_DIR"/backup-*; do
    [[ -d "$backup_path" ]] || continue
    printf '%s\n' "${backup_path##*/}"
  done | while IFS= read -r backup_name; do
    printf '%s\t%s\n' "$(portable_mtime "$BACKUP_DIR/$backup_name")" "$backup_name"
  done | sort -rn | cut -f2-
  shopt -u nullglob
}

portable_mtime() {
  if stat -c %Y "$1" >/dev/null 2>&1; then
    stat -c %Y "$1"
  else
    stat -f %m "$1"
  fi
}

# Parse arguments
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -l | --list)
      list_backups
      exit 0
      ;;
    --latest | -L)
      restore_latest
      exit 0
      ;;
    --git | -g)
      restore_from_git "$2" "$DRY_RUN"
      exit 0
      ;;
    --diff | -d)
      show_diff "$2"
      exit 0
      ;;
    --dry-run | -n)
      DRY_RUN=true
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      log_error "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

# Default: show usage
usage
