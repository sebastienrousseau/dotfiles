#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC2034
# =============================================================================
# heal-chezmoi.sh — Chezmoi drift and backup repair functions for heal.sh
# Sourced by heal.sh; inherits set -euo pipefail, ui.sh, and shared variables.
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
      if [[ -f "$f" ]]; then
        cp -a "$f" "$backup_path/" 2>/dev/null || true
      fi
    done
    log_info "Backup created at $backup_path"
  fi
}

heal_chezmoi_drift() {
  if ! command -v chezmoi >/dev/null 2>&1; then return 0; fi

  local status_output
  status_output=$(chezmoi status 2>/dev/null || echo "")

  if [[ -z "$status_output" ]]; then
    printf '  \033[38;5;42m✓\033[0m chezmoi state\n'
    return 0
  fi

  ISSUES_FOUND=$((ISSUES_FOUND + 1))

  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "run 'chezmoi apply --force' to re-sync"
  else
    if _pkg_install "chezmoi re-apply" 0 1 chezmoi apply --force; then
      FIXES_APPLIED=$((FIXES_APPLIED + 1))
      CHEZMOI_APPLIED=1
      persist_log "HEAL: chezmoi apply --force"
    fi
  fi
}
