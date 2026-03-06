#!/usr/bin/env bash
# Copyright (c) 2015-2026 . All rights reserved.
# Pre-warm shell initialization caches for ultra-fast startup.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/dot/lib/ui.sh"

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
mkdir -p "$CACHE_DIR/"{zsh,bash,fish,nushell}

ui_header "Pre-warming Shell Caches"

warm_tool() {
  local tool="$1"
  local cmd="$2"
  local shell="$3"
  local ext="$4"

  local cache_file="$CACHE_DIR/$shell/$tool-init.$ext"

  if command -v "$tool" >/dev/null 2>&1; then
    eval "$cmd" >"$cache_file" 2>/dev/null || true
    ui_ok "$tool" "Cached for $shell"
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
if command -v starship >/dev/null 2>&1; then
  starship init nu >"$CACHE_DIR/nushell/starship.nu" 2>/dev/null || true
  ui_ok "starship" "Cached for nushell"
fi
if command -v zoxide >/dev/null 2>&1; then
  zoxide init nushell >"$CACHE_DIR/nushell/zoxide.nu" 2>/dev/null || true
  ui_ok "zoxide" "Cached for nushell"
fi
if command -v atuin >/dev/null 2>&1; then
  atuin init nu >"$CACHE_DIR/nushell/atuin.nu" 2>/dev/null || true
  ui_ok "atuin" "Cached for nushell"
fi

ui_header "Cache Pre-warming Complete"
