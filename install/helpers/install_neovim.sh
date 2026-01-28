#!/usr/bin/env bash
# Linux-only Neovim installer (for manual use)
# For macOS, use: brew install neovim
set -euo pipefail

# Only run on Linux
if [[ "$(uname -s)" != "Linux" ]]; then
  echo "[ERROR] This script is for Linux only. On macOS, use: brew install neovim" >&2
  exit 1
fi

# Determine install location
INSTALL_DIR="${NVIM_INSTALL_DIR:-/opt}"
BIN_DIR="${NVIM_BIN_DIR:-/usr/local/bin}"

sudo_cmd=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null; then
    sudo_cmd="sudo"
  else
    # Fall back to user-local installation
    INSTALL_DIR="${HOME}/.local/opt"
    BIN_DIR="${HOME}/.local/bin"
    echo "[INFO] No sudo available, installing to ${INSTALL_DIR}"
  fi
fi

# Ensure directories exist
mkdir -p "$INSTALL_DIR" "$BIN_DIR" 2>/dev/null || $sudo_cmd mkdir -p "$INSTALL_DIR" "$BIN_DIR"

echo "Removing old version..."
$sudo_cmd rm -rf "${INSTALL_DIR}/nvim-linux64" 2>/dev/null || true

echo "Extracting new version..."
# Ensure we use the absolute path to the downloaded file
if [ ! -f "$HOME/nvim-linux64.tar.gz" ]; then
  echo "[ERROR] $HOME/nvim-linux64.tar.gz not found." >&2
  exit 1
fi
if ! $sudo_cmd tar -C "$INSTALL_DIR" -xzf "$HOME/nvim-linux64.tar.gz"; then
  echo "[ERROR] Failed to extract $HOME/nvim-linux64.tar.gz" >&2
  exit 1
fi

echo "Linking binary..."
$sudo_cmd ln -sf "${INSTALL_DIR}/nvim-linux64/bin/nvim" "${BIN_DIR}/nvim"

echo "Done! Verifying..."
"${BIN_DIR}/nvim" --version
