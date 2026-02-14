#!/usr/bin/env bash
# dot restore - Restore dotfiles from backup or previous state
# Usage: dot restore [--list|--latest|<backup-id>]

set -euo pipefail

DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"
BACKUP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/backups"
CHEZMOI_SOURCE="${HOME}/.local/share/chezmoi"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }

usage() {
  echo "Usage: dot restore [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --list, -l       List available backups"
  echo "  --latest         Restore from latest backup"
  echo "  --git <ref>      Restore from git ref (commit, tag, branch)"
  echo "  --diff <ref>     Show diff between current and ref"
  echo "  --dry-run        Show what would be restored"
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

  echo -e "${BLUE}Available Backups:${NC}"
  echo "─────────────────────────────────────────"

  find "$BACKUP_DIR" -maxdepth 1 -type d -name "backup-*" -printf "%T@ %f\n" 2>/dev/null | sort -rn | cut -d' ' -f2- | while read -r backup; do
    echo "  $backup"
  done

  echo ""
  echo -e "${BLUE}Git History (last 10):${NC}"
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
  if command -v chezmoi >/dev/null 2>&1; then
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
      cp -r "$f" "$backup_path/" 2>/dev/null || true
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
  latest=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name "backup-*" -printf "%T@ %f\n" 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2-)

  if [[ -z "$latest" ]]; then
    log_error "No backups found"
    return 1
  fi

  log_info "Restoring from: $latest"

  local backup_path="$BACKUP_DIR/$latest"
  local target
  for item in "$backup_path"/*; do
    if [[ -e "$item" ]]; then
      target="$HOME/$(basename "$item")"
      cp -r "$item" "$target"
      log_success "Restored: $(basename "$item")"
    fi
  done
}

# Parse arguments
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -l | --list)
      list_backups
      exit 0
      ;;
    --latest)
      restore_latest
      exit 0
      ;;
    --git)
      restore_from_git "$2" "$DRY_RUN"
      exit 0
      ;;
    --diff)
      show_diff "$2"
      exit 0
      ;;
    --dry-run)
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
