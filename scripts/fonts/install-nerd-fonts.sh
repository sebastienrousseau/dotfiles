#!/bin/sh
set -e

FONT_NAME="${1:-JetBrainsMono}"
TARGET_DIR="$HOME/.local/share/fonts/${FONT_NAME}NerdFont"

install_linux() {
  mkdir -p "$TARGET_DIR"
  tmp_dir="$(mktemp -d)"
  url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${FONT_NAME}.zip"
  echo "Downloading $FONT_NAME Nerd Font..."
  curl -fL "$url" -o "$tmp_dir/${FONT_NAME}.zip"
  unzip -o "$tmp_dir/${FONT_NAME}.zip" -d "$TARGET_DIR" >/dev/null
  rm -rf "$tmp_dir"
  if command -v fc-cache >/dev/null; then
    fc-cache -f "$TARGET_DIR"
  fi
  echo "Installed to: $TARGET_DIR"
}

install_macos() {
  if command -v brew >/dev/null; then
    brew tap homebrew/cask-fonts >/dev/null 2>&1 || true
    brew install --cask "font-${FONT_NAME,,}-nerd-font" || true
  else
    echo "Homebrew not found. Install font manually."
    exit 1
  fi
}

case "$(uname -s)" in
  Linux)
    install_linux
    ;;
  Darwin)
    install_macos
    ;;
  *)
    echo "Unsupported OS for font install."
    exit 1
    ;;
esac
