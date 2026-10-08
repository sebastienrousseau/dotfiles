#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# dot restore - Restore dotfiles from backup or previous state
# Usage: dot restore [--list|-l|--latest|-L|<backup-id>]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../lib/dot/utils.sh
source "$SCRIPT_DIR/../../../lib/dot/utils.sh"
# shellcheck source=../../../lib/dot/log.sh
source "$SCRIPT_DIR/../../../lib/dot/log.sh"

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

# Set GIT_SRC to the repository and GIT_COMMIT to the commit REF names, or
# log why not and return 1. A ref starting with '-' would reach git as an
# option (--output=FILE writes anywhere), so it is refused, and
# --end-of-options keeps rev-parse from reading it as one either. Only the
# resolved commit id is ever passed on to git.
resolve_git_target() {
  local ref="$1"
  if [[ -d "$DOTFILES_DIR/.git" ]]; then
    GIT_SRC="$DOTFILES_DIR"
  elif [[ -d "$CHEZMOI_SOURCE/.git" ]]; then
    GIT_SRC="$CHEZMOI_SOURCE"
  else
    log_error "No git repository found"
    return 1
  fi
  if [[ -z "$ref" || "$ref" == -* ]]; then
    log_error "Invalid git ref: '$ref'"
    return 1
  fi
  GIT_COMMIT="$(git -C "$GIT_SRC" rev-parse --verify --quiet --end-of-options "${ref}^{commit}")" || {
    log_error "Unknown git ref: $ref"
    return 1
  }
}

restore_from_git() {
  local ref="$1"
  local dry_run="${2:-false}"

  resolve_git_target "$ref" || return 1

  log_info "Restoring from git ref: $ref"

  if $dry_run; then
    log_info "Dry run - showing changes:"
    git -C "$GIT_SRC" diff "$GIT_COMMIT" --stat --
    return 0
  fi

  # Create backup first
  create_backup

  # Restore
  git -C "$GIT_SRC" checkout "$GIT_COMMIT" -- .
  log_success "Restored from $ref"

  # Re-apply chezmoi
  if has_command chezmoi; then
    log_info "Re-applying chezmoi..."
    chezmoi apply
  fi
}

show_diff() {
  resolve_git_target "$1" || return 1
  git -C "$GIT_SRC" diff "$GIT_COMMIT" --
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
    # rollback.sh keeps its metadata beside the files; it is not a dotfile.
    [[ "${item##*/}" == ".backup_meta" ]] && continue
    rel_path="${item#"$backup_path"/}"
    target="$HOME/$rel_path"
    mkdir -p "$(dirname "$target")"
    cp -r "$item" "$target"
    log_success "Restored: $rel_path"
  done < <(find "$backup_path" -mindepth 1 -maxdepth 1 -print0)
}

# Both name shapes are backups: this script writes backup-<stamp>, and
# scripts/ops/rollback.sh writes backup_<stamp>_<reason> into the same
# directory. Users have years of the latter on disk, so neither is renamed.
list_backup_names() {
  local backup_path

  shopt -s nullglob
  for backup_path in "$BACKUP_DIR"/backup-* "$BACKUP_DIR"/backup_*; do
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

# Parse every flag before acting, so `--git REF --dry-run` is a dry run.
DRY_RUN=false
ACTION=""
REF=""

need_ref() {
  if [[ $# -lt 2 ]]; then
    log_error "$1 needs a git ref"
    usage
    exit 1
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -l | --list) ACTION=list ;;
      --latest | -L) ACTION=latest ;;
      --git | -g | --diff | -d)
        need_ref "$@"
        ACTION="$1"
        REF="$2"
        shift
        ;;
      --dry-run | -n) DRY_RUN=true ;;
      -h | --help) ACTION=help ;;
      *)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
    shift
  done
}

# No action: show usage.
run_action() {
  case "$ACTION" in
    list) list_backups ;;
    latest) restore_latest ;;
    --git | -g) restore_from_git "$REF" "$DRY_RUN" ;;
    --diff | -d) show_diff "$REF" ;;
    *) usage ;;
  esac
}

parse_args "$@"
run_action
