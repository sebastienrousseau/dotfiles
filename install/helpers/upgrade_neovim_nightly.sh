#!/usr/bin/env bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
# SPDX-License-Identifier: MIT
#
# Linux-only Neovim nightly installer
# For macOS, use: brew install --HEAD neovim
set -euo pipefail

# Only run on Linux
if [[ "$(uname -s)" != "Linux" ]]; then
  echo "[ERROR] This script is for Linux only. On macOS, use: brew install --HEAD neovim" >&2
  exit 1
fi

# Cleanup any partial downloads
rm -f nvim-linux-x86_64.tar.gz nvim-linux-x86_64.tar.gz.sha256sum nvim-linux64.tar.gz

sha256_file() {
  if command -v sha256sum >/dev/null; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    echo "sha256sum or shasum is required for verified downloads."
    exit 1
  fi
}

echo "Downloading Nightly (v0.11) [Correct URL]..."
curl -fLo nvim-linux-x86_64.tar.gz https://github.com/neovim/neovim/releases/download/nightly/nvim-linux-x86_64.tar.gz
curl -fLo nvim-linux-x86_64.tar.gz.sha256sum https://github.com/neovim/neovim/releases/download/nightly/nvim-linux-x86_64.tar.gz.sha256sum

expected="$(awk -v f="nvim-linux-x86_64.tar.gz" '$2==f {print $1}' nvim-linux-x86_64.tar.gz.sha256sum)"
if [ -z "$expected" ]; then
  expected="$(awk '{print $1}' nvim-linux-x86_64.tar.gz.sha256sum | head -n1)"
fi
actual="$(sha256_file nvim-linux-x86_64.tar.gz)"
if [ -z "$expected" ] || [ "$expected" != "$actual" ]; then
  echo "Checksum verification failed for nvim-linux-x86_64.tar.gz."
  exit 1
fi

# Determine if sudo is needed
sudo_cmd=""
INSTALL_DIR="/opt"
BIN_DIR="/usr/local/bin"
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
$sudo_cmd rm -rf "${INSTALL_DIR}/nvim-linux64" "${INSTALL_DIR}/nvim-linux-x86_64" 2>/dev/null || true

echo "Extracting..."
$sudo_cmd tar -C "$INSTALL_DIR" -xzf nvim-linux-x86_64.tar.gz

echo "Linking binary..."
# Note: The folder name changed to nvim-linux-x86_64
$sudo_cmd ln -sf "${INSTALL_DIR}/nvim-linux-x86_64/bin/nvim" "${BIN_DIR}/nvim"
mkdir -p "$HOME/.local/bin"
ln -sf "${INSTALL_DIR}/nvim-linux-x86_64/bin/nvim" "$HOME/.local/bin/nvim" 2>/dev/null || true

echo "Done! Verifying..."
"${BIN_DIR}/nvim" --version || "$HOME/.local/bin/nvim" --version
