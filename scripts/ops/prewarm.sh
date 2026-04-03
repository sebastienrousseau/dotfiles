#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Pre-warm shell initialization caches for ultra-fast startup.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/dot/lib/ui.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/dot/lib/log.sh"
export DOT_COMMAND="prewarm"

# Prevent concurrent execution
LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-prewarm.lock"
LOCK_DIR="${LOCK_FILE}.d"
if command -v flock >/dev/null 2>&1; then
  exec 9>"$LOCK_FILE"
  if ! flock -n 9; then
    ui_warn "Already running" "Another instance is active"
    exit 0
  fi
else
  # Portable fallback when flock is unavailable (e.g. minimal macOS envs).
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    ui_warn "Already running" "Another instance is active"
    exit 0
  fi
  trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT
fi

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
mkdir -p "$CACHE_DIR/"{zsh,bash,fish,nushell}

ui_header "Pre-warming Shell Caches"

warm_tool() {
  local tool="$1"
  local cmd="$2"
  local shell="$3"
  local ext="$4"

  local cache_file="$CACHE_DIR/$shell/$tool-init.$ext"
  local tmp_file="${cache_file}.tmp.$$"

  if command -v "$tool" >/dev/null 2>&1; then
    if eval "$cmd" >"$tmp_file" 2>/dev/null && [ -s "$tmp_file" ]; then
      mv "$tmp_file" "$cache_file"
      ui_ok "$tool" "Cached for $shell"
    else
      rm -f "$tmp_file"
      ui_warn "$tool" "Failed to cache for $shell"
    fi
  fi
}

ui_section "Zsh"
warm_tool "mise" "mise activate zsh" "zsh" "zsh"
warm_tool "starship" "starship init zsh" "zsh" "zsh"
warm_tool "zoxide" "zoxide init zsh" "zsh" "zsh"
warm_tool "atuin" "atuin init zsh --disable-up-arrow" "zsh" "zsh"
warm_tool "fzf" "fzf --zsh" "zsh" "zsh"
warm_tool "direnv" "direnv hook zsh" "zsh" "zsh"

ui_section "Bash"
warm_tool "mise" "mise activate bash" "bash" "bash"
warm_tool "starship" "starship init bash" "bash" "bash"
warm_tool "zoxide" "zoxide init bash" "bash" "bash"
warm_tool "atuin" "atuin init bash --disable-up-arrow" "bash" "bash"
warm_tool "fzf" "fzf --bash" "bash" "bash"
warm_tool "direnv" "direnv hook bash" "bash" "bash"

ui_section "Fish"
warm_tool "mise" "mise activate fish" "fish" "fish"
warm_tool "starship" "starship init fish" "fish" "fish"
warm_tool "zoxide" "zoxide init fish" "fish" "fish"
warm_tool "atuin" "atuin init fish" "fish" "fish"
warm_tool "fzf" "fzf --fish" "fish" "fish"
warm_tool "direnv" "direnv hook fish" "fish" "fish"

ui_section "Nushell"
for _nu_entry in "starship:starship init nu:starship.nu" "zoxide:zoxide init nushell:zoxide.nu" "atuin:atuin init nu:atuin.nu"; do
  _nu_tool="${_nu_entry%%:*}"
  _nu_rest="${_nu_entry#*:}"
  _nu_cmd="${_nu_rest%%:*}"
  _nu_file="${_nu_rest#*:}"
  if command -v "$_nu_tool" >/dev/null 2>&1; then
    _nu_tmp="$CACHE_DIR/nushell/${_nu_file}.tmp.$$"
    if eval "$_nu_cmd" >"$_nu_tmp" 2>/dev/null && [ -s "$_nu_tmp" ]; then
      mv "$_nu_tmp" "$CACHE_DIR/nushell/$_nu_file"
      ui_ok "$_nu_tool" "Cached for nushell"
    else
      rm -f "$_nu_tmp"
      ui_warn "$_nu_tool" "Failed to cache for nushell"
    fi
  fi
done

# --- Completions ---
ui_section "Shell completions"
ZSH_COMP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/completions"
mkdir -p "$ZSH_COMP_DIR"

_prewarm_completion() {
  local name="$1" cmd="$2"
  shift 2
  if command -v "$cmd" >/dev/null 2>&1; then
    if "$cmd" "$@" >"${ZSH_COMP_DIR}/_${name}" 2>/dev/null; then
      ui_ok "$name" "completion generated"
    fi
  fi
}

_prewarm_completion "gh" "gh" completion -s zsh
_prewarm_completion "just" "just" --completions zsh
_prewarm_completion "chezmoi" "chezmoi" completion zsh
_prewarm_completion "kubectl" "kubectl" completion zsh
_prewarm_completion "mise" "mise" completion zsh
_prewarm_completion "atuin" "atuin" gen-completions --shell zsh

ui_header "Cache Pre-warming Complete"
dot_log info "prewarm_complete"
