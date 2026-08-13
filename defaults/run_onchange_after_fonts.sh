#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Universal Nerd Font checker/installer
# Inspired by 2026 terminal aesthetics

set -euo pipefail

SOURCE_ROOT="${DOTFILES_SOURCE_DIR:-}"
[[ -n "$SOURCE_ROOT" && "$(basename "$SOURCE_ROOT")" == "defaults" ]] && SOURCE_ROOT="$(dirname "$SOURCE_ROOT")"
if [[ -z "$SOURCE_ROOT" ]] && command -v chezmoi >/dev/null 2>&1; then
  SOURCE_ROOT="$(chezmoi source-path 2>/dev/null || true)"
  [[ "$(basename "$SOURCE_ROOT")" == "defaults" ]] && SOURCE_ROOT="$(dirname "$SOURCE_ROOT")"
fi
if [[ -z "$SOURCE_ROOT" || ! -r "$SOURCE_ROOT/lib/dot/verified-download.sh" ]]; then
  printf 'Font Check: verified-download.sh unavailable; refusing unverified install\n' >&2
  exit 1
fi
# shellcheck source=../lib/dot/verified-download.sh disable=SC1091
source "$SOURCE_ROOT/lib/dot/verified-download.sh"

if [ -t 1 ] && command -v gum >/dev/null 2>&1; then
  gum style --foreground 212 --border double --align center --width 50 "Font Check"
  if ! fc-list | grep -qi "Nerd Font"; then
    gum confirm "Nerd Font not found. Install 'FiraCode Nerd Font'?" && {
      tmp_dir="$(umask 077 && mktemp -d)"
      trap 'rm -rf "$tmp_dir"' EXIT
      base_url="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0"
      download_verified_asset \
        "$base_url/FiraCode.zip" "$base_url/SHA-256.txt" \
        FiraCode.zip "$tmp_dir/FiraCode.zip" 104857600
      mkdir -p "$HOME/.local/share/fonts"
      unzip -o "$tmp_dir/FiraCode.zip" -d "$HOME/.local/share/fonts" >/dev/null
      fc-cache -f
    }
  else
    gum style --foreground 82 "󰄬 Nerd Fonts are present"
  fi
fi
