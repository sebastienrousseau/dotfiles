#!/usr/bin/env bash
# Install Nerd Fonts (JetBrainsMono & Symbols)
# This script runs when the checksum of this file changes (user triggered or manual update)

set -euo pipefail

# Support for DOTFILES_SILENT
log_info() { if [[ "${DOTFILES_SILENT:-0}" != "1" ]]; then printf '\n[INFO] %s\n' "$*"; fi; }

FONT_VERSION="v3.4.0"
NERD_FONT_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${FONT_VERSION}"

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
        curl -fLo "$TMP_DIR/${font}.zip" "${NERD_FONT_URL}/${font}.zip" >/dev/null 2>&1
        unzip -o -q "$TMP_DIR/${font}.zip" -d "$FONT_DIR"
        rm -f "$TMP_DIR/${font}.zip"
    ) &
done

# Wait for all background processes
wait

# Save version marker
echo "$FONT_VERSION" > "$MARKER_FILE"

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
