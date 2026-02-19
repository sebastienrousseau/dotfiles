#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"

ui_init
ui_header "Nerd Fonts"

DEFAULT_FONTS="JetBrainsMono FiraCode Iosevka"
FONT_LIST="${*:-$DEFAULT_FONTS}"

install_linux() {
  font_name="$1"
  target_dir="$HOME/.local/share/fonts/${font_name}NerdFont"
  mkdir -p "$target_dir"
  tmp_dir="$(mktemp -d)"
  url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font_name}.zip"
  ui_info "Downloading" "$font_name Nerd Font"
  curl -fL --connect-timeout 10 --max-time 300 "$url" -o "$tmp_dir/${font_name}.zip"
  if ! unzip -o "$tmp_dir/${font_name}.zip" -d "$target_dir" >/dev/null; then
    ui_err "Unzip failed" "${font_name}.zip" >&2
    rm -rf "$tmp_dir"
    return 1
  fi
  rm -rf "$tmp_dir"
  if command -v fc-cache >/dev/null; then
    fc-cache -f "$target_dir"
  fi
  ui_ok "Installed" "$target_dir"
}

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
