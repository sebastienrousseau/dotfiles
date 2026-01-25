#!/usr/bin/env bash
# =============================================================================
# Dotfiles Rollback Script - Self-Healing Configuration Recovery
# Safely reverts failed dotfile applications with automatic backup
# Usage: ./scripts/ops/rollback.sh [OPTIONS]
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
DOTFILES_SOURCE="${HOME}/.dotfiles"
BACKUP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/backups"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
ROLLBACK_LOG="$STATE_DIR/rollback.log"
MAX_BACKUPS=10

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Logging
log() { echo -e "$*"; }
log_info() { log "${BLUE}[INFO]${NC} $*"; }
log_success() { log "${GREEN}[OK]${NC} $*"; }
log_warn() { log "${YELLOW}[WARN]${NC} $*"; }
log_error() { log "${RED}[ERROR]${NC} $*"; }
log_step() { log "\n${BOLD}==> $*${NC}"; }

# Persistent logging
persist_log() {
  mkdir -p "$STATE_DIR"
  echo "[$(date -Iseconds)] $*" >>"$ROLLBACK_LOG"
}

usage() {
  cat <<EOF
Dotfiles Rollback & Recovery Tool

Usage: $(basename "$0") [COMMAND] [OPTIONS]

Commands:
  status          Show current state and available backups
  backup          Create a manual backup of current dotfiles
  rollback        Rollback to the previous backup
  rollback-to N   Rollback to specific backup number (from status list)
  git-reset       Reset to last known good git commit
  restore FILE    Restore a specific file from backup
  clean           Remove old backups (keeps last $MAX_BACKUPS)

Options:
  -f, --force     Skip confirmation prompts
  -n, --dry-run   Show what would be done without making changes
  -v, --verbose   Show detailed output
  -h, --help      Show this help message

Examples:
  $(basename "$0") status              # List available backups
  $(basename "$0") backup              # Create manual backup
  $(basename "$0") rollback            # Rollback to previous state
  $(basename "$0") rollback-to 3       # Rollback to backup #3
  $(basename "$0") git-reset           # Reset to last good commit
  $(basename "$0") restore .bashrc     # Restore specific file

EOF
}

# Ensure directories exist
ensure_dirs() {
  mkdir -p "$BACKUP_DIR" "$STATE_DIR"
}

# List available backups
list_backups() {
  local backups=()
  local i=1

  if [[ ! -d "$BACKUP_DIR" ]]; then
    log_warn "No backup directory found"
    return 1
  fi

  log_step "Available Backups"
  echo ""

  while IFS= read -r backup; do
    if [[ -d "$backup" ]]; then
      local name timestamp size
      name=$(basename "$backup")
      timestamp=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$backup" 2>/dev/null || stat -c "%y" "$backup" 2>/dev/null | cut -d'.' -f1)
      size=$(du -sh "$backup" 2>/dev/null | cut -f1)
      printf "  %2d. %-30s  %s  %s\n" "$i" "$name" "$timestamp" "$size"
      ((i++))
    fi
  done < <(find "$BACKUP_DIR" -maxdepth 1 -type d -name "backup_*" | sort -r)

  if [[ $i -eq 1 ]]; then
    log_warn "No backups found"
    return 1
  fi
  echo ""
}

# Create a backup
create_backup() {
  local reason="${1:-manual}"
  local timestamp
  timestamp=$(date +"%Y%m%d_%H%M%S")
  local backup_name="backup_${timestamp}_${reason}"
  local backup_path="$BACKUP_DIR/$backup_name"

  log_step "Creating Backup: $backup_name"
  ensure_dirs

  mkdir -p "$backup_path"

  # List of files/directories to backup
  local targets=(
    "$HOME/.bashrc"
    "$HOME/.zshrc"
    "$HOME/.zshenv"
    "$HOME/.profile"
    "$HOME/.inputrc"
    "$HOME/.vimrc"
    "$HOME/.gitconfig"
    "$HOME/.config/shell"
    "$HOME/.config/nvim"
    "$HOME/.config/git"
    "$HOME/.config/tmux"
    "$HOME/.config/chezmoi"
  )

  local backed_up=0
  for target in "${targets[@]}"; do
    if [[ -e "$target" ]]; then
      local rel_path="${target#$HOME/}"
      local dest_dir
      dest_dir=$(dirname "$backup_path/$rel_path")
      mkdir -p "$dest_dir"
      cp -a "$target" "$backup_path/$rel_path" 2>/dev/null || true
      ((backed_up++))
      [[ "$VERBOSE" == "1" ]] && log_info "Backed up: $rel_path"
    fi
  done

  # Record metadata
  cat >"$backup_path/.backup_meta" <<EOF
timestamp=$timestamp
reason=$reason
chezmoi_version=$(chezmoi --version 2>/dev/null || echo "unknown")
git_commit=$(cd "$DOTFILES_SOURCE" 2>/dev/null && git rev-parse --short HEAD 2>/dev/null || echo "unknown")
files_backed_up=$backed_up
EOF

  log_success "Backup created: $backup_path ($backed_up items)"
  persist_log "BACKUP_CREATED: $backup_name ($backed_up items)"

  # Cleanup old backups
  cleanup_old_backups
}

# Cleanup old backups, keeping only MAX_BACKUPS
cleanup_old_backups() {
  local count
  count=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name "backup_*" 2>/dev/null | wc -l | tr -d ' ')

  if [[ $count -gt $MAX_BACKUPS ]]; then
    local to_delete=$((count - MAX_BACKUPS))
    log_info "Cleaning up $to_delete old backup(s)..."

    find "$BACKUP_DIR" -maxdepth 1 -type d -name "backup_*" | sort | head -n "$to_delete" | while read -r old; do
      rm -rf "$old"
      [[ "$VERBOSE" == "1" ]] && log_info "Removed: $(basename "$old")"
    done
  fi
}

# Get the most recent backup
get_latest_backup() {
  find "$BACKUP_DIR" -maxdepth 1 -type d -name "backup_*" 2>/dev/null | sort -r | head -1
}

# Get backup by index (1-based)
get_backup_by_index() {
  local index="$1"
  find "$BACKUP_DIR" -maxdepth 1 -type d -name "backup_*" | sort -r | sed -n "${index}p"
}

# Rollback to a specific backup
perform_rollback() {
  local backup_path="$1"
  local dry_run="${2:-0}"

  if [[ ! -d "$backup_path" ]]; then
    log_error "Backup not found: $backup_path"
    return 1
  fi

  log_step "Rollback from: $(basename "$backup_path")"

  # First, create a safety backup of current state
  if [[ "$dry_run" != "1" ]]; then
    create_backup "pre_rollback"
  fi

  # Restore files
  local restored=0
  while IFS= read -r -d '' file; do
    local rel_path="${file#$backup_path/}"
    local dest="$HOME/$rel_path"

    # Skip metadata file
    [[ "$rel_path" == ".backup_meta" ]] && continue

    if [[ "$dry_run" == "1" ]]; then
      log_info "[DRY-RUN] Would restore: $rel_path"
    else
      local dest_dir
      dest_dir=$(dirname "$dest")
      mkdir -p "$dest_dir"
      cp -a "$file" "$dest"
      ((restored++))
      [[ "$VERBOSE" == "1" ]] && log_info "Restored: $rel_path"
    fi
  done < <(find "$backup_path" -type f -print0)

  if [[ "$dry_run" != "1" ]]; then
    log_success "Rollback complete: $restored file(s) restored"
    persist_log "ROLLBACK: from $(basename "$backup_path"), $restored files restored"
  fi
}

# Git-based rollback
git_reset() {
  local dry_run="${1:-0}"

  if [[ ! -d "$DOTFILES_SOURCE/.git" ]]; then
    log_error "Not a git repository: $DOTFILES_SOURCE"
    return 1
  fi

  log_step "Git Reset Recovery"

  cd "$DOTFILES_SOURCE"

  # Show recent commits
  log_info "Recent commits:"
  git log --oneline -5
  echo ""

  # Check for uncommitted changes
  if [[ -n "$(git status --porcelain)" ]]; then
    log_warn "Uncommitted changes detected"
    if [[ "$FORCE" != "1" ]]; then
      read -rp "Stash changes? [y/N] " response
      if [[ "$response" =~ ^[Yy]$ ]]; then
        git stash push -m "Auto-stash before rollback $(date +%Y%m%d_%H%M%S)"
        log_success "Changes stashed"
      fi
    fi
  fi

  # Find last good commit (last tag or HEAD~1)
  local target_commit
  target_commit=$(git describe --tags --abbrev=0 2>/dev/null || echo "HEAD~1")

  log_info "Reset target: $target_commit"

  if [[ "$dry_run" == "1" ]]; then
    log_info "[DRY-RUN] Would reset to: $target_commit"
    git diff --stat HEAD "$target_commit"
  else
    # Create backup first
    create_backup "pre_git_reset"

    git reset --hard "$target_commit"
    log_success "Git reset to: $target_commit"

    # Re-apply chezmoi
    if command -v chezmoi >/dev/null 2>&1; then
      log_info "Re-applying chezmoi..."
      chezmoi apply --force --exclude=scripts
      log_success "Chezmoi re-applied"
    fi

    persist_log "GIT_RESET: to $target_commit"
  fi
}

# Restore a specific file from the latest backup
restore_file() {
  local file_path="$1"
  local dry_run="${2:-0}"

  # Normalize path
  file_path="${file_path#$HOME/}"
  file_path="${file_path#./}"
  file_path="${file_path#~/}"

  local backup
  backup=$(get_latest_backup)

  if [[ -z "$backup" ]]; then
    log_error "No backups available"
    return 1
  fi

  local source_file="$backup/$file_path"

  if [[ ! -f "$source_file" ]]; then
    log_error "File not found in backup: $file_path"
    log_info "Available files in backup:"
    find "$backup" -type f -name "*.backup_meta" -prune -o -type f -print | sed "s|$backup/||" | head -20
    return 1
  fi

  local dest="$HOME/$file_path"

  if [[ "$dry_run" == "1" ]]; then
    log_info "[DRY-RUN] Would restore: $file_path"
    log_info "From: $source_file"
    log_info "To: $dest"
  else
    # Backup current version
    if [[ -f "$dest" ]]; then
      cp "$dest" "${dest}.rollback.$(date +%Y%m%d_%H%M%S)"
    fi

    local dest_dir
    dest_dir=$(dirname "$dest")
    mkdir -p "$dest_dir"
    cp -a "$source_file" "$dest"
    log_success "Restored: $file_path"
    persist_log "RESTORE_FILE: $file_path"
  fi
}

# Show current status
show_status() {
  log_step "Dotfiles Rollback Status"
  echo ""

  # Chezmoi status
  if command -v chezmoi >/dev/null 2>&1; then
    log_info "Chezmoi version: $(chezmoi --version | head -1)"
    local status
    status=$(chezmoi status 2>/dev/null || echo "")
    if [[ -z "$status" ]]; then
      log_success "Chezmoi: All files in sync"
    else
      log_warn "Chezmoi: $(echo "$status" | wc -l | tr -d ' ') file(s) out of sync"
    fi
  fi

  # Git status
  if [[ -d "$DOTFILES_SOURCE/.git" ]]; then
    cd "$DOTFILES_SOURCE"
    log_info "Git commit: $(git rev-parse --short HEAD)"
    log_info "Git branch: $(git branch --show-current)"
    local changes
    changes=$(git status --porcelain | wc -l | tr -d ' ')
    if [[ "$changes" -eq 0 ]]; then
      log_success "Git: Working tree clean"
    else
      log_warn "Git: $changes uncommitted change(s)"
    fi
  fi

  # List backups
  echo ""
  list_backups || true

  # Recent rollback log
  if [[ -f "$ROLLBACK_LOG" ]]; then
    echo ""
    log_info "Recent rollback activity:"
    tail -5 "$ROLLBACK_LOG" | while read -r line; do
      echo "    $line"
    done
  fi
}

# =============================================================================
# Main
# =============================================================================

FORCE=0
DRY_RUN=0
VERBOSE=0

main() {
  local command="${1:-status}"
  shift || true

  # Parse global options
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -f | --force)
        FORCE=1
        shift
        ;;
      -n | --dry-run)
        DRY_RUN=1
        shift
        ;;
      -v | --verbose)
        VERBOSE=1
        shift
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *) break ;;
    esac
  done

  ensure_dirs

  case "$command" in
    status)
      show_status
      ;;
    backup)
      create_backup "manual"
      ;;
    rollback)
      local latest
      latest=$(get_latest_backup)
      if [[ -z "$latest" ]]; then
        log_error "No backups available for rollback"
        exit 1
      fi
      if [[ "$FORCE" != "1" ]] && [[ "$DRY_RUN" != "1" ]]; then
        read -rp "Rollback to $(basename "$latest")? [y/N] " response
        [[ ! "$response" =~ ^[Yy]$ ]] && exit 0
      fi
      perform_rollback "$latest" "$DRY_RUN"
      ;;
    rollback-to)
      local index="${1:-}"
      if [[ -z "$index" ]] || ! [[ "$index" =~ ^[0-9]+$ ]]; then
        log_error "Please specify a backup number (see 'status' command)"
        exit 1
      fi
      local backup
      backup=$(get_backup_by_index "$index")
      if [[ -z "$backup" ]]; then
        log_error "Backup #$index not found"
        exit 1
      fi
      if [[ "$FORCE" != "1" ]] && [[ "$DRY_RUN" != "1" ]]; then
        read -rp "Rollback to $(basename "$backup")? [y/N] " response
        [[ ! "$response" =~ ^[Yy]$ ]] && exit 0
      fi
      perform_rollback "$backup" "$DRY_RUN"
      ;;
    git-reset)
      if [[ "$FORCE" != "1" ]] && [[ "$DRY_RUN" != "1" ]]; then
        read -rp "Reset to last known good commit? [y/N] " response
        [[ ! "$response" =~ ^[Yy]$ ]] && exit 0
      fi
      git_reset "$DRY_RUN"
      ;;
    restore)
      local file="${1:-}"
      if [[ -z "$file" ]]; then
        log_error "Please specify a file to restore"
        exit 1
      fi
      restore_file "$file" "$DRY_RUN"
      ;;
    clean)
      log_info "Cleaning old backups (keeping last $MAX_BACKUPS)..."
      cleanup_old_backups
      log_success "Cleanup complete"
      ;;
    -h | --help | help)
      usage
      ;;
    *)
      log_error "Unknown command: $command"
      usage
      exit 1
      ;;
  esac
}

main "$@"
