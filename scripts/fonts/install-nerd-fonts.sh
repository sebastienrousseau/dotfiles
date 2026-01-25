#!/bin/sh
set -e

DEFAULT_FONTS="JetBrainsMono FiraCode Iosevka"
FONT_LIST="${*:-$DEFAULT_FONTS}"

install_linux() {
  font_name="$1"
  target_dir="$HOME/.local/share/fonts/${font_name}NerdFont"
  mkdir -p "$target_dir"
  tmp_dir="$(mktemp -d)"
  url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font_name}.zip"
  echo "Downloading $font_name Nerd Font..."
  curl -fL "$url" -o "$tmp_dir/${font_name}.zip"
  unzip -o "$tmp_dir/${font_name}.zip" -d "$target_dir" >/dev/null
  rm -rf "$tmp_dir"
  if command -v fc-cache >/dev/null; then
    fc-cache -f "$target_dir"
  fi
  echo "Installed to: $target_dir"
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
    echo "Homebrew not found. Install font manually."
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
    echo "Unsupported OS for font install."
    exit 1
    ;;
esac
