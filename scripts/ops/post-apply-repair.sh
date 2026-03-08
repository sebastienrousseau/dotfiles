#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../dot/lib/ui.sh"

ZWC_CACHE_DIRS_DEFAULT=("$HOME/.config/shell" "$HOME/.config/zsh")

repair_zwc_cache() {
  local repaired=0
  local failed=0
  local file
  local dirs=()
  local raw_dirs="${DOTFILES_ZWC_CACHE_DIRS:-}"

  if [[ -n "$raw_dirs" ]]; then
    # shellcheck disable=SC2206
    dirs=($raw_dirs)
  else
    dirs=("${ZWC_CACHE_DIRS_DEFAULT[@]}")
  fi

  while IFS= read -r -d '' file; do
    if [[ ! -w "$file" ]]; then
      if rm -f "$file" >/dev/null 2>&1; then
        ((repaired++)) || true
      else
        ((failed++)) || true
      fi
    fi
  done < <(find "${dirs[@]}" -type f -name '*.zwc' -print0 2>/dev/null || true)

  if ((failed > 0)); then
    ui_err "Zsh cache repair" "failed to remove ${failed} stale .zwc file(s)"
    return
  fi

  if ((repaired > 0)); then
    ui_warn "Zsh cache repair" "removed ${repaired} stale read-only .zwc file(s)"
  else
    ui_ok "Zsh cache repair" "no stale .zwc permissions detected"
  fi
}

resolve_zsh_bin() {
  if [[ -n "${DOTFILES_ZSH_BIN:-}" ]]; then
    printf "%s\n" "${DOTFILES_ZSH_BIN}"
    return
  fi
  if command -v zsh >/dev/null 2>&1; then
    command -v zsh
    return
  fi
  printf "%s\n" ""
}

validate_dot_cli() {
  local dot_bin="${HOME}/.local/bin/dot"
  local zsh_out dot_alias dot_path
  local zsh_bin

  if [[ ! -x "$dot_bin" ]]; then
    ui_err "dot CLI binary" "missing executable at ${dot_bin}"
    return
  fi
  ui_ok "dot CLI binary" "$dot_bin"

  zsh_bin="$(resolve_zsh_bin)"
  if [[ -z "$zsh_bin" || ! -x "$zsh_bin" ]]; then
    ui_warn "dot CLI resolution" "zsh not available; skipping shell validation"
    return
  fi

  zsh_out="$("$zsh_bin" -lic '
    alias dot 2>/dev/null || true
    whence -p dot 2>/dev/null || true
  ' 2>/dev/null || true)"
  dot_alias="$(printf "%s\n" "$zsh_out" | head -n 1)"
  dot_path="$(printf "%s\n" "$zsh_out" | tail -n 1)"

  if [[ "$dot_alias" == *"cd_with_history"* ]]; then
    ui_warn "dot alias collision" "legacy sessions may still map dot to navigation; run: unalias dot && exec zsh"
  fi

  if [[ "$dot_path" == "$dot_bin" ]]; then
    ui_ok "dot CLI resolution" "$dot_path"
  elif [[ -n "$dot_path" ]]; then
    ui_warn "dot CLI resolution" "resolved to ${dot_path} (expected ${dot_bin})"
  else
    ui_err "dot CLI resolution" "dot not found in a fresh zsh login shell"
  fi
}

main() {
  ui_init
  ui_header "Post-apply checks"
  repair_zwc_cache
  validate_dot_cli
}

if [[ "${DOTFILES_POST_APPLY_TESTING:-0}" != "1" ]]; then
  main
fi
