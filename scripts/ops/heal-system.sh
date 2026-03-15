#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC2034
# =============================================================================
# heal-system.sh — System-level repair functions for heal.sh
# Sourced by heal.sh; inherits set -euo pipefail, ui.sh, and shared variables.
# =============================================================================

heal_broken_symlinks() {
  local broken=()

  while IFS= read -r -d '' link; do
    # Skip known false positives (e.g., Chrome lock files in backups)
    [[ "$link" == *"google-chrome-backup"* ]] && continue

    if [[ ! -e "$link" ]]; then
      broken+=("$link")
    fi
  done < <(find "$HOME" -maxdepth 3 -type l -print0 2>/dev/null)

  # Special handling for common transient/app locks that dot doctor reported
  local lock_patterns=("SingletonLock" "SingletonCookie")

  if [[ ${#broken[@]} -eq 0 ]]; then
    printf '  \033[38;5;42m✓\033[0m symlinks\n'
    return 0
  fi

  ISSUES_FOUND=$((ISSUES_FOUND + ${#broken[@]}))

  for link in "${broken[@]}"; do
    local target
    target=$(readlink "$link" 2>/dev/null || echo "unknown")
    local filename
    filename=$(basename "$link")

    local is_lock=0
    for pat in "${lock_patterns[@]}"; do
      if [[ "$filename" == *"$pat"* ]]; then
        is_lock=1
        break
      fi
    done

    if [[ "$DRY_RUN" == "1" ]]; then
      log_dry "remove broken symlink: $link -> $target"
    else
      if [[ "$is_lock" == "0" ]] && [[ "$FORCE" != "1" ]] && [[ "${DOTFILES_NONINTERACTIVE:-0}" != "1" ]]; then
        read -rp "Remove broken symlink $link -> $target? [y/N] " response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
          continue
        fi
      fi
      rm -f "$link"
      printf '  \033[38;5;42m✓\033[0m removed %s\n' "$link"
      FIXES_APPLIED=$((FIXES_APPLIED + 1))
      persist_log "HEAL: removed broken symlink $link"
    fi
  done
}

heal_missing_critical_files() {
  local critical_files=("$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile")
  local missing=()

  for file in "${critical_files[@]}"; do
    if [[ ! -f "$file" ]] && [[ ! -L "$file" ]]; then
      missing+=("$file")
      ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    printf '  \033[38;5;42m✓\033[0m shell configs\n'
    return 0
  fi

  if ! command -v chezmoi >/dev/null 2>&1; then return 1; fi

  if [[ "$DRY_RUN" == "1" ]]; then
    log_dry "regenerate missing files via chezmoi"
  elif [[ "$CHEZMOI_APPLIED" != "1" ]]; then
    if _pkg_install "shell configs" 0 1 chezmoi apply --force; then
      CHEZMOI_APPLIED=1
      local restored=0
      for file in "${missing[@]}"; do
        [[ -f "$file" ]] || [[ -L "$file" ]] && restored=$((restored + 1))
      done
      FIXES_APPLIED=$((FIXES_APPLIED + restored))
      persist_log "HEAL: regenerated $restored critical file(s)"
    fi
  fi
}

heal_missing_xdg_dirs() {
  local xdg_dirs=("$HOME/.config/shell" "$HOME/.config/nvim" "$HOME/.config/git")
  local missing=()

  for dir in "${xdg_dirs[@]}"; do
    [[ -d "$dir" ]] || missing+=("$dir")
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    printf '  \033[38;5;42m✓\033[0m xdg directories\n'
    return 0
  fi

  ISSUES_FOUND=$((ISSUES_FOUND + ${#missing[@]}))
  for dir in "${missing[@]}"; do
    if [[ "$DRY_RUN" == "1" ]]; then
      log_dry "create directory: $dir"
    else
      mkdir -p "$dir"
      printf '  \033[38;5;42m✓\033[0m %s\n' "$(basename "$dir")"
      FIXES_APPLIED=$((FIXES_APPLIED + 1))
      persist_log "HEAL: created directory $dir"
    fi
  done
}
