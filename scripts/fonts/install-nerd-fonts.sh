#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/dot/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../lib/dot/ui.sh"
# shellcheck source=../../lib/dot/verified-download.sh disable=SC1091
source "$SCRIPT_DIR/../../lib/dot/verified-download.sh"

ui_init
ui_header "Nerd Fonts"

DEFAULT_FONTS="JetBrainsMono FiraCode Iosevka"
FONT_LIST="${*:-$DEFAULT_FONTS}"
FONT_VERSION="v3.4.0"
FONT_BASE_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${FONT_VERSION}"
FONT_CHECKSUM_URL="${FONT_BASE_URL}/SHA-256.txt"

install_linux() (
  local font_name="$1"
  local target_dir="$HOME/.local/share/fonts/${font_name}NerdFont"
  mkdir -p "$target_dir"
  local tmp_dir
  tmp_dir="$(umask 077 && mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT
  local asset="${font_name}.zip"
  local url="${FONT_BASE_URL}/${asset}"
  ui_info "Downloading" "$font_name Nerd Font"
  download_verified_asset "$url" "$FONT_CHECKSUM_URL" "$asset" "$tmp_dir/$asset" 104857600
  if ! unzip -o "$tmp_dir/$asset" -d "$target_dir" >/dev/null; then
    ui_err "Unzip failed" "$asset" >&2
    return 1
  fi
  if command -v fc-cache >/dev/null; then
    fc-cache -f "$target_dir"
  fi
  ui_ok "Installed" "$target_dir"
)

install_macos() {
  font_name="$1"
  if command -v brew >/dev/null; then
    brew tap homebrew/cask-fonts >/dev/null 2>&1 || true
    cask_name="$(printf "%s" "$font_name" | tr '[:upper:]' '[:lower:]')"
    case "$cask_name" in
      jetbrainsmono) cask_name="jetbrains-mono" ;;
      firacode) cask_name="fira-code" ;;
      iosevka) cask_name="iosevka" ;;
    esac
    brew install --cask "font-${cask_name}-nerd-font" || true
  else
    ui_err "Homebrew" "not found. Install font manually."
    exit 1
  fi
}

case "$(uname -s)" in
  Linux)
    for font in $FONT_LIST; do
      install_linux "$font"
    done
    ;;
  Darwin)
    for font in $FONT_LIST; do
      install_macos "$font"
    done
    ;;
  *)
    ui_err "Unsupported OS" "font install"
    exit 1
    ;;
esac
