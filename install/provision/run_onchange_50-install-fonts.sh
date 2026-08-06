#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Install Nerd Fonts (JetBrainsMono & Symbols)
# This script runs when the checksum of this file changes (user triggered or manual update)

set -euo pipefail

SOURCE_ROOT="${DOTFILES_SOURCE_DIR:-}"
if [[ -z "$SOURCE_ROOT" ]]; then
  SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  [[ -r "$SCRIPT_ROOT/lib/dot/verified-download.sh" ]] && SOURCE_ROOT="$SCRIPT_ROOT"
fi
if [[ -z "$SOURCE_ROOT" ]] && command -v chezmoi >/dev/null 2>&1; then
  SOURCE_ROOT="$(chezmoi source-path 2>/dev/null || true)"
  [[ "$(basename "$SOURCE_ROOT")" == "defaults" ]] && SOURCE_ROOT="$(dirname "$SOURCE_ROOT")"
fi
if [[ -z "$SOURCE_ROOT" || ! -r "$SOURCE_ROOT/lib/dot/verified-download.sh" ]]; then
  printf '[ERROR] verified-download.sh not found; refusing unverified font installation\n' >&2
  exit 1
fi
# shellcheck source=../../lib/dot/verified-download.sh disable=SC1091
source "$SOURCE_ROOT/lib/dot/verified-download.sh"

# Support for DOTFILES_SILENT
log_info() { if [[ "${DOTFILES_SILENT:-0}" != "1" ]]; then printf '\n[INFO] %s\n' "$*"; fi; }

FONT_VERSION="v3.4.0"
NERD_FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${FONT_VERSION}"
NERD_FONT_CHECKSUM_URL="${NERD_FONT_URL}/SHA-256.txt"

# Define fonts to install
FONTS=(
  "JetBrainsMono"
  "NerdFontsSymbolsOnly"
)

# Detect OS and set font directory
if [[ "$(uname)" == "Darwin" ]]; then
  FONT_DIR="$HOME/Library/Fonts"
  OS_TYPE="macOS"
else
  FONT_DIR="$HOME/.local/share/fonts"
  OS_TYPE="Linux"
fi

mkdir -p "$FONT_DIR"

# Idempotency check: only install if fonts are missing or version mismatch
# We use a simple marker file to track version
MARKER_FILE="$FONT_DIR/.nerd-fonts-version"
if [[ -f "$MARKER_FILE" ]] && [[ "$(cat "$MARKER_FILE")" == "$FONT_VERSION" ]]; then
  log_info "Nerd Fonts ($FONT_VERSION) already installed. Skipping."
  exit 0
fi

TMP_DIR="$(umask 077 && mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

log_info "Installing Nerd Fonts ($FONT_VERSION) for $OS_TYPE..."

# Parallel download and extraction
for font in "${FONTS[@]}"; do
  (
    if [[ "${DOTFILES_SILENT:-0}" != "1" ]]; then
      echo "   -> Processing $font..."
    fi
    download_verified_asset \
      "${NERD_FONT_URL}/${font}.zip" \
      "$NERD_FONT_CHECKSUM_URL" \
      "${font}.zip" \
      "$TMP_DIR/${font}.zip" \
      104857600
    unzip -o -q "$TMP_DIR/${font}.zip" -d "$FONT_DIR"
    rm -f "$TMP_DIR/${font}.zip"
  ) &
done

# Wait for all background processes
wait

# Save version marker
echo "$FONT_VERSION" >"$MARKER_FILE"

# Cleanup Windows compatible files if they exist (optional, mostly for cleanliness)
rm -f "$FONT_DIR/"*Windows Compatible.ttf* 2>/dev/null || true

# Update font cache
if command -v fc-cache >/dev/null; then
  if [[ "${DOTFILES_SILENT:-0}" != "1" ]]; then
    echo "   -> Updating font cache..."
  fi
  fc-cache -f "$FONT_DIR" >/dev/null 2>&1
fi

log_info "Nerd Fonts installed successfully!"
