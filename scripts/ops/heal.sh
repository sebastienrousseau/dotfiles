#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC2034
# =============================================================================
# Dotfiles Heal Script - Auto-repair common dotfiles issues
# Runs diagnostics and attempts automatic fixes
# Usage: ./scripts/ops/heal.sh [OPTIONS]
# =============================================================================

set -euo pipefail

_cleanup_files=()
LOCK_DIR=""
cleanup() {
  rm -f "${_cleanup_files[@]:-}"
  if [[ -n "$LOCK_DIR" ]]; then
    rmdir "$LOCK_DIR" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../dot/lib/ui.sh"
# shellcheck source=../dot/lib/log.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../dot/lib/log.sh"
DOT_COMMAND="heal"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
DOTFILES_SOURCE="$REPO_ROOT"
BACKUP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/backups"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
HEAL_LOG="$STATE_DIR/heal.log"

# Logging — delegates to shared ui.sh primitives
ui_init
log() { printf '%b\n' "$*"; }
log_info() { ui_info "$@"; }
log_success() { ui_ok "$@"; }
log_warn() { ui_warn "$@"; }
log_error() { ui_err "$@"; }
log_step() {
  echo ""
  ui_section "$*"
}
log_dry() { ui_warn "DRY-RUN" "Would: $*"; }

# Persistent logging
persist_log() {
  mkdir -p "$STATE_DIR"
  echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*" >>"$HEAL_LOG"
}

# Options
DRY_RUN=0
FORCE=0
FIXES_APPLIED=0
ISSUES_FOUND=0
CHEZMOI_APPLIED=0
MISSING_DEPS_FOUND=0

usage() {
  cat <<EOF
Dotfiles Heal - Auto-repair common issues

Usage: $(basename "$0") [OPTIONS]

Options:
  -n, --dry-run   Preview what would be fixed without making changes
  -f, --force     Skip confirmation prompts
  -h, --help      Show this help message

Environment:
  DOTFILES_NONINTERACTIVE=1   Skip all interactive prompts (same as --force)

Repairs:
  - Missing tools (zsh, starship, rg, bat, fzf, zoxide, atuin, yazi, zellij,
    nushell, pueue, wasmtime, sops, age, hyperfine)
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

# Prevent concurrent execution
# Prefer XDG runtime dir when it exists and is writable; fallback to /tmp.
LOCK_BASE="/tmp"
if [[ -n "${XDG_RUNTIME_DIR:-}" ]] && [[ -d "${XDG_RUNTIME_DIR}" ]] && [[ -w "${XDG_RUNTIME_DIR}" ]]; then
  LOCK_BASE="${XDG_RUNTIME_DIR}"
fi
LOCK_FILE="${LOCK_BASE}/dotfiles-heal.lock"
LOCK_DIR="${LOCK_FILE}.d"
if command -v flock >/dev/null 2>&1; then
  exec 9>"$LOCK_FILE"
  if ! flock -n 9; then
    # Fallback path for systems where flock exists but cannot lock reliably.
    if ! mkdir "$LOCK_DIR" 2>/dev/null; then
      ui_warn "Already running" "Another instance is active"
      exit 0
    fi
  fi
else
  # Portable fallback when flock is unavailable (e.g. default macOS envs).
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    ui_warn "Already running" "Another instance is active"
    exit 0
  fi
fi

# =============================================================================
# Load modules (inherit scope: set -euo pipefail, ui.sh, and all variables)
# =============================================================================

# shellcheck source=heal-tools.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/heal-tools.sh"

# shellcheck source=heal-system.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/heal-system.sh"

# shellcheck source=heal-chezmoi.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/heal-chezmoi.sh"

# =============================================================================
# Main
# =============================================================================

main() {
  echo ""
  printf '  \033[1mDotfiles Heal\033[0m\n'
  echo ""

  if [[ "$DRY_RUN" == "1" ]]; then
    log_info "Dry-run mode (no changes will be made)"
  fi

  # Confirm before making changes (unless --force, --dry-run, or non-interactive)
  if [[ "$DRY_RUN" != "1" ]] && [[ "$FORCE" != "1" ]] && [[ "${DOTFILES_NONINTERACTIVE:-0}" != "1" ]]; then
    log_warn "This will auto-repair your dotfiles environment."
    read -rp "  Continue? [y/N] " response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
      log_info "Aborted."
      exit 0
    fi
    echo ""
  fi

  # Create backup before making changes
  if [[ "$DRY_RUN" != "1" ]]; then
    _pkg_install "backup" 0 1 create_pre_heal_backup 2>/dev/null || true
  fi

  # Run all repairs
  heal_missing_dependencies || true
  heal_mise_tools || true

  # Quick checks (no animation needed)
  heal_chezmoi_drift || true
  heal_broken_symlinks || true
  heal_missing_critical_files || true
  heal_missing_xdg_dirs || true

  # Pre-warm shell caches for fast startup (< 50ms target)
  local prewarm_script="$SCRIPT_DIR/prewarm.sh"
  if [[ -f "$prewarm_script" ]] && [[ "$DRY_RUN" != "1" ]]; then
    log_step "Performance"
    _pkg_install "shell cache pre-warm" 0 1 bash "$prewarm_script" || true
  fi

  # Summary
  echo ""
  if [[ "$DRY_RUN" == "1" ]]; then
    if [[ $ISSUES_FOUND -eq 0 ]]; then
      printf '  \033[1;38;5;42mHealthy.\033[0m No issues found.\n'
    else
      printf '  Found %d issue(s). Run without --dry-run to apply fixes.\n' "$ISSUES_FOUND"
    fi
  else
    if [[ $ISSUES_FOUND -eq 0 ]]; then
      printf '  \033[1;38;5;42mHealthy.\033[0m No issues found.\n'
    elif [[ $FIXES_APPLIED -gt 0 ]]; then
      printf '  \033[1;38;5;42mDone!\033[0m Applied %d fix(es) for %d issue(s).\n' "$FIXES_APPLIED" "$ISSUES_FOUND"
      persist_log "HEAL_COMPLETE: $FIXES_APPLIED fixes applied"
      dot_log info "heal_complete" "fixes=$FIXES_APPLIED" "issues=$ISSUES_FOUND"
    else
      printf '  Found %d issue(s) but no fixes could be applied.\n' "$ISSUES_FOUND"
      printf '  Run \033[38;5;211mdot doctor\033[0m for diagnostics.\n'
    fi
  fi
  echo ""
}

main
