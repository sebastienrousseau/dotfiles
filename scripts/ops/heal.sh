#!/usr/bin/env bash
# shellcheck disable=SC2034
# =============================================================================
# Dotfiles Heal Script - Auto-repair common dotfiles issues
# Runs diagnostics and attempts automatic fixes
# Usage: ./scripts/ops/heal.sh [OPTIONS]
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
DOTFILES_SOURCE="$REPO_ROOT"
BACKUP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/backups"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
HEAL_LOG="$STATE_DIR/heal.log"

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
log_dry() { log "${YELLOW}[DRY-RUN]${NC} Would: $*"; }

# Persistent logging
persist_log() {
  mkdir -p "$STATE_DIR"
  echo "[$(date -Iseconds)] $*" >>"$HEAL_LOG"
}

# Options
DRY_RUN=0
FORCE=0
FIXES_APPLIED=0
ISSUES_FOUND=0
CHEZMOI_APPLIED=0

usage() {
  cat <<EOF
Dotfiles Heal - Auto-repair common issues

Usage: $(basename "$0") [OPTIONS]

Options:
  -n, --dry-run   Preview what would be fixed without making changes
  -f, --force     Skip confirmation prompts
  -h, --help      Show this help message

Repairs:
  - Missing core dependencies (chezmoi, starship, rg, bat)
  - Broken symlinks in \$HOME (depth 3)
  - Chezmoi drift (re-applies dotfiles)
  - Missing critical files (.zshrc, .bashrc, .profile)
  - Missing XDG config directories

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n | --dry-run)
      DRY_RUN=1
      shift
      ;;
    -f | --force)
      FORCE=1
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

# =============================================================================
# Backup before making changes
# =============================================================================

create_pre_heal_backup() {
  local rollback_script="$REPO_ROOT/scripts/ops/rollback.sh"
  if [[ -f "$rollback_script" ]]; then
    log_info "Creating backup before heal..."
    bash "$rollback_script" backup --force 2>/dev/null || true
  else
    # Minimal inline backup
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local backup_path="$BACKUP_DIR/backup_${timestamp}_pre_heal"
    mkdir -p "$backup_path"
    for f in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
      [[ -f "$f" ]] && cp -a "$f" "$backup_path/" 2>/dev/null || true
    done
    log_info "Backup created at $backup_path"
  fi
}

# =============================================================================
# Repair Functions
# =============================================================================

detect_pkg_manager() {
  if command -v brew >/dev/null 2>&1; then
    echo "brew"
  elif command -v apt-get >/dev/null 2>&1; then
    echo "apt"
  elif command -v dnf >/dev/null 2>&1; then
    echo "dnf"
  elif command -v pacman >/dev/null 2>&1; then
    echo "pacman"
  elif command -v nix-env >/dev/null 2>&1; then
    echo "nix"
  else
    echo ""
  fi
}

install_package() {
  local pkg="$1"
  local pkg_mgr
  pkg_mgr=$(detect_pkg_manager)

  case "$pkg_mgr" in
    brew)   brew install "$pkg" ;;
    apt)    sudo apt-get install -y "$pkg" ;;
    dnf)    sudo dnf install -y "$pkg" ;;
    pacman) sudo pacman -S --noconfirm "$pkg" ;;
    nix)    nix-env -iA "nixpkgs.$pkg" ;;
    *)
      log_error "No supported package manager found. Install '$pkg' manually."
      return 1
      ;;
  esac
}

# Map command names to package names per package manager
get_package_name() {
  local cmd="$1"
  local pkg_mgr
  pkg_mgr=$(detect_pkg_manager)

  case "$cmd" in
    rg)
      case "$pkg_mgr" in
        apt|dnf) echo "ripgrep" ;;
        *) echo "ripgrep" ;;
      esac
      ;;
    bat)
      case "$pkg_mgr" in
        apt) echo "bat" ;;
        *) echo "bat" ;;
      esac
      ;;
    *) echo "$cmd" ;;
  esac
}

heal_missing_dependencies() {
  log_step "Checking core dependencies"
  local deps=(chezmoi starship rg bat)
  local missing=()

  for cmd in "${deps[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
      ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    log_success "All core dependencies present"
    return 0
  fi

  log_warn "Missing dependencies: ${missing[*]}"

  local pkg_mgr
  pkg_mgr=$(detect_pkg_manager)

  if [[ -z "$pkg_mgr" ]]; then
    log_error "No supported package manager detected. Install manually: ${missing[*]}"
    return 1
  fi

  for cmd in "${missing[@]}"; do
    local pkg
    pkg=$(get_package_name "$cmd")

    if [[ "$DRY_RUN" == "1" ]]; then
      log_dry "install '$pkg' via $pkg_mgr"
    else
      log_info "Installing $pkg via $pkg_mgr..."
      if install_package "$pkg"; then
        log_success "Installed $pkg"
        FIXES_APPLIED=$((FIXES_APPLIED + 1))
        persist_log "HEAL: installed $pkg via $pkg_mgr"
      else
        log_error "Failed to install $pkg"
      fi
    fi
  done
}

heal_broken_symlinks() {
  log_step "Checking for broken symlinks"
  local broken=()

  while IFS= read -r -d '' link; do
    if [[ ! -e "$link" ]]; then
      broken+=("$link")
    fi
  done < <(find "$HOME" -maxdepth 3 -type l -print0 2>/dev/null)

  if [[ ${#broken[@]} -eq 0 ]]; then
    log_success "No broken symlinks found"
    return 0
  fi

  ISSUES_FOUND=$((ISSUES_FOUND + ${#broken[@]}))
  log_warn "${#broken[@]} broken symlink(s) found"

  for link in "${broken[@]}"; do
    local target
    target=$(readlink "$link" 2>/dev/null || echo "unknown")
    if [[ "$DRY_RUN" == "1" ]]; then
      log_dry "remove broken symlink: $link -> $target"
    else
      if [[ "$FORCE" != "1" ]]; then
        read -rp "Remove broken symlink $link -> $target? [y/N] " response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
          log_info "Skipped: $link"
          continue
        fi
      fi
      rm -f "$link"
      log_success "Removed broken symlink: $link -> $target"
      FIXES_APPLIED=$((FIXES_APPLIED + 1))
      persist_log "HEAL: removed broken symlink $link"
    fi
  done
}

heal_chezmoi_drift() {
  log_step "Checking chezmoi state"

  if ! command -v chezmoi >/dev/null 2>&1; then
    log_warn "chezmoi not installed, skipping drift check"
    return 0
  fi

  local status_output
  status_output=$(chezmoi status 2>/dev/null || echo "")

  if [[ -z "$status_output" ]]; then
    log_success "Chezmoi state is synchronized"
    return 0
  fi

  local drift_count
  drift_count=$(echo "$status_output" | wc -l | tr -d ' ')
  ISSUES_FOUND=$((ISSUES_FOUND + 1))
  log_warn "$drift_count file(s) out of sync"

  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "run 'chezmoi apply --force' to re-sync"
    echo "$status_output" | while read -r line; do
      log_info "  $line"
    done
  else
    log_info "Re-applying dotfiles with chezmoi..."
    if chezmoi apply --force; then
      log_success "Chezmoi re-applied successfully"
      FIXES_APPLIED=$((FIXES_APPLIED + 1))
      CHEZMOI_APPLIED=1
      persist_log "HEAL: chezmoi apply --force ($drift_count files drifted)"
    else
      log_error "Chezmoi apply failed"
    fi
  fi
}

heal_missing_critical_files() {
  log_step "Checking critical files"
  local critical_files=(
    "$HOME/.zshrc"
    "$HOME/.bashrc"
    "$HOME/.profile"
  )
  local missing=()

  for file in "${critical_files[@]}"; do
    if [[ ! -f "$file" ]] && [[ ! -L "$file" ]]; then
      missing+=("$file")
      ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    log_success "All critical shell configs present"
    return 0
  fi

  log_warn "Missing critical files: ${missing[*]}"

  if ! command -v chezmoi >/dev/null 2>&1; then
    log_error "chezmoi not available to regenerate files"
    return 1
  fi

  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "run 'chezmoi apply --force' to regenerate missing files"
  elif [[ "$CHEZMOI_APPLIED" == "1" ]]; then
    log_info "chezmoi already re-applied during drift repair, verifying files..."
    local restored=0
    for file in "${missing[@]}"; do
      if [[ -f "$file" ]] || [[ -L "$file" ]]; then
        log_success "Restored (via earlier apply): $file"
        restored=$((restored + 1))
      else
        log_warn "Still missing after apply: $file"
      fi
    done
    FIXES_APPLIED=$((FIXES_APPLIED + restored))
  else
    log_info "Re-applying chezmoi to regenerate missing files..."
    if chezmoi apply --force; then
      CHEZMOI_APPLIED=1
      # Verify files were restored
      local restored=0
      for file in "${missing[@]}"; do
        if [[ -f "$file" ]] || [[ -L "$file" ]]; then
          log_success "Restored: $file"
          restored=$((restored + 1))
        else
          log_warn "Still missing after apply: $file"
        fi
      done
      FIXES_APPLIED=$((FIXES_APPLIED + restored))
      persist_log "HEAL: regenerated $restored critical file(s)"
    else
      log_error "Chezmoi apply failed"
    fi
  fi
}

heal_missing_xdg_dirs() {
  log_step "Checking XDG config directories"
  local xdg_dirs=(
    "$HOME/.config/shell"
    "$HOME/.config/nvim"
    "$HOME/.config/git"
  )
  local missing=()

  for dir in "${xdg_dirs[@]}"; do
    if [[ ! -d "$dir" ]]; then
      missing+=("$dir")
      ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    log_success "All XDG config directories present"
    return 0
  fi

  log_warn "Missing XDG directories: ${missing[*]}"

  for dir in "${missing[@]}"; do
    if [[ "$DRY_RUN" == "1" ]]; then
      log_dry "create directory: $dir"
    else
      mkdir -p "$dir"
      log_success "Created: $dir"
      FIXES_APPLIED=$((FIXES_APPLIED + 1))
      persist_log "HEAL: created directory $dir"
    fi
  done
}

# =============================================================================
# Main
# =============================================================================

main() {
  echo ""
  echo "=========================================="
  echo "     Dotfiles Heal - Auto-Repair"
  echo "=========================================="

  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "Running in dry-run mode (no changes will be made)"
  fi

  # Confirm before making changes (unless --force or --dry-run)
  if [[ "$DRY_RUN" != "1" ]] && [[ "$FORCE" != "1" ]]; then
    echo ""
    log_warn "This will attempt to auto-repair your dotfiles environment."
    log_info "A backup will be created before any changes are made."
    read -rp "Continue? [y/N] " response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
      log_info "Aborted."
      exit 0
    fi
  fi

  # Create backup before making changes
  if [[ "$DRY_RUN" != "1" ]]; then
    create_pre_heal_backup
  fi

  # Run all repairs
  heal_missing_dependencies || true
  heal_broken_symlinks || true
  heal_chezmoi_drift || true
  heal_missing_critical_files || true
  heal_missing_xdg_dirs || true

  # Summary
  echo ""
  echo "=========================================="
  if [[ "$DRY_RUN" == "1" ]]; then
    if [[ $ISSUES_FOUND -eq 0 ]]; then
      log_success "No issues found. System is healthy."
    else
      log_info "Found $ISSUES_FOUND issue(s). Run without --dry-run to apply fixes."
    fi
  else
    if [[ $ISSUES_FOUND -eq 0 ]]; then
      log_success "No issues found. System is healthy."
    elif [[ $FIXES_APPLIED -gt 0 ]]; then
      log_success "Applied $FIXES_APPLIED fix(es) for $ISSUES_FOUND issue(s) found."
      persist_log "HEAL_COMPLETE: $FIXES_APPLIED fixes applied"
    else
      log_warn "Found $ISSUES_FOUND issue(s) but no fixes could be applied."
      log_info "Try running 'dot doctor' for detailed diagnostics."
    fi
  fi
  echo "=========================================="
}

main
