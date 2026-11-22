#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Pre-warm shell initialization caches for ultra-fast startup.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/dot/ui.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/dot/log.sh"
export DOT_COMMAND="prewarm"

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
mkdir -p "$CACHE_DIR"

# Prevent concurrent execution. The lock lives in XDG_RUNTIME_DIR when it is
# usable, else in the cache this run warms. A machine-wide /tmp lock let any
# other prewarm (another user's, another HOME's) make this one stand down,
# and let another user block it.
_prewarm_lock_base() {
  if [[ -n "${XDG_RUNTIME_DIR:-}" && -d "$XDG_RUNTIME_DIR" && -w "$XDG_RUNTIME_DIR" ]]; then
    printf '%s\n' "$XDG_RUNTIME_DIR"
  else
    printf '%s\n' "$CACHE_DIR"
  fi
}

# _prewarm_lock: 0 when this run holds the lock. flock where it exists; a
# lock directory where it does not (macOS ships no flock).
_prewarm_lock() {
  local file
  file="$(_prewarm_lock_base)/dotfiles-prewarm.lock"
  if command -v flock >/dev/null 2>&1; then
    exec 9>"$file"
    flock -n 9
    return
  fi
  LOCK_DIR="$file.d"
  mkdir "$LOCK_DIR" 2>/dev/null || return 1
  trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT
}

if ! _prewarm_lock; then
  ui_warn "Already running" "Another instance is active"
  exit 0
fi

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
# Not mise, in any shell: its activation embeds the PATH of the shell that
# ran it. zsh and fish write their mise cache themselves, with that PATH
# replaced by $PATH (_cached_eval_generate); a copy cached here would pin this
# script's PATH into every later shell. bash never reads one. Clear stale
# copies, then have zsh and fish write theirs again through their own
# _cached_eval, so the caches are fresh before the next shell (and `dot
# doctor`) looks.
rm -f "$CACHE_DIR/zsh/mise-init.zsh" "$CACHE_DIR/zsh/mise-init.zsh.zwc" "$CACHE_DIR/zsh/mise-init.zsh.bin" \
  "$CACHE_DIR/bash/mise-init.bash" "$CACHE_DIR/bash/mise-init.bin" \
  "$CACHE_DIR/fish/mise-init.fish" "$CACHE_DIR/fish/mise-init.bin"

# _warm_mise SHELL CMD...: run CMD (the shell with its own config) to write
# SHELL's mise cache; a shell without the dotfiles' _cached_eval writes none
# and leaves it to its next start.
_warm_mise() {
  local shell="$1"
  shift
  command -v mise >/dev/null 2>&1 && command -v "$shell" >/dev/null 2>&1 || return 0
  "$@" </dev/null >/dev/null 2>&1 || true
  if [ -s "$CACHE_DIR/$shell/mise-init.$shell" ]; then
    ui_ok "mise" "Cached for $shell"
  else
    ui_warn "mise" "Not cached for $shell; its next start writes it"
  fi
}
_warm_mise zsh zsh -i -c '_cached_eval mise-init mise activate zsh'
warm_tool "starship" "starship init zsh" "zsh" "zsh"
warm_tool "zoxide" "zoxide init zsh" "zsh" "zsh"
warm_tool "atuin" "atuin init zsh --disable-up-arrow" "zsh" "zsh"
warm_tool "fzf" "fzf --zsh" "zsh" "zsh"
warm_tool "direnv" "direnv hook zsh" "zsh" "zsh"

ui_section "Bash"
warm_tool "starship" "starship init bash" "bash" "bash"
warm_tool "zoxide" "zoxide init bash" "bash" "bash"
warm_tool "atuin" "atuin init bash --disable-up-arrow" "bash" "bash"
warm_tool "fzf" "fzf --bash" "bash" "bash"
warm_tool "direnv" "direnv hook bash" "bash" "bash"

ui_section "Fish"
_warm_mise fish fish -c '_cached_eval mise activate fish'
warm_tool "starship" "starship init fish" "fish" "fish"
warm_tool "zoxide" "zoxide init fish" "fish" "fish"
warm_tool "atuin" "atuin init fish" "fish" "fish"
warm_tool "fzf" "fzf --fish" "fish" "fish"
warm_tool "direnv" "direnv hook fish" "fish" "fish"

ui_section "Nushell"
# _warm_nu TOOL CMD FILE: cache TOOL's nushell init (CMD) as FILE.
_warm_nu() {
  local tmp
  command -v "$1" >/dev/null 2>&1 || return 0
  tmp="$CACHE_DIR/nushell/$3.tmp.$$"
  if eval "$2" >"$tmp" 2>/dev/null && [ -s "$tmp" ]; then
    mv "$tmp" "$CACHE_DIR/nushell/$3"
    ui_ok "$1" "Cached for nushell"
  else
    rm -f "$tmp"
    ui_warn "$1" "Failed to cache for nushell"
  fi
}
_warm_nu starship "starship init nu" starship.nu
_warm_nu zoxide "zoxide init nushell" zoxide.nu
_warm_nu atuin "atuin init nu" atuin.nu

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
