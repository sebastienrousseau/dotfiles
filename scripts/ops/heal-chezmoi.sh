#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
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

  # Partition the drift: column 2 is what `chezmoi apply` would fix
  # (destination differs from source). Column 1 is source-only drift
  # (unstaged edits in the chezmoi source tree). Apply can't help with
  # the second case — that needs `git commit` in the source repo.
  local applicable
  local source_only
  applicable=$(printf '%s\n' "$status_output" | awk 'substr($0,2,1)!=" "' | wc -l | tr -d ' ')
  source_only=$(printf '%s\n' "$status_output" | awk 'substr($0,1,1)!=" " && substr($0,2,1)==" "' | wc -l | tr -d ' ')

  ISSUES_FOUND=$((ISSUES_FOUND + 1))

  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "run 'chezmoi apply --force' to re-sync ($applicable file(s))"
    return 0
  fi

  # Skip the apply if every file is source-only drift; nothing to fix.
  if [[ "$applicable" -eq 0 ]]; then
    printf '  \033[38;5;220m⚠\033[0m chezmoi state                       %s file(s) modified in source only — commit or revert in the source repo\n' "$source_only"
    return 0
  fi

  # Capture apply output so we can surface failure reasons.
  local apply_log
  apply_log=$(mktemp)
  if chezmoi apply --force >"$apply_log" 2>&1; then
    FIXES_APPLIED=$((FIXES_APPLIED + 1))
    CHEZMOI_APPLIED=1
    persist_log "HEAL: chezmoi apply --force"

    # Verify: did apply actually clean the drift?
    local remaining
    remaining=$(chezmoi status 2>/dev/null | awk 'substr($0,2,1)!=" "' | wc -l | tr -d ' ')
    if [[ "$remaining" -eq 0 ]]; then
      printf '  \033[38;5;42m✓\033[0m chezmoi re-apply                     %s file(s) synced\n' "$applicable"
    else
      # shellcheck disable=SC2016
      printf '  \033[38;5;220m⚠\033[0m chezmoi re-apply                     %s applied, %s still drifted — run `chezmoi diff` to inspect\n' \
        "$((applicable - remaining))" "$remaining"
    fi
  else
    printf '  \033[38;5;196m✗\033[0m chezmoi re-apply                     failed; see %s\n' "$apply_log"
    tail -5 "$apply_log" | sed 's/^/      /'
    return 1
  fi
  rm -f "$apply_log"
}
