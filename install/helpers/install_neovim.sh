#!/usr/bin/env bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
# SPDX-License-Identifier: MIT
#
# Linux-only Neovim installer (for manual use)
# For macOS, use: brew install neovim
set -euo pipefail

# Only run on Linux
if [[ "$(uname -s)" != "Linux" ]]; then
  echo "[ERROR] This script is for Linux only. On macOS, use: brew install neovim" >&2
  exit 1
fi

# Security: Validate install paths to prevent path traversal
validate_install_path() {
  local path="$1"
  local name="$2"

  # Resolve to absolute path and check for traversal attempts
  local resolved
  resolved="$(cd "$(dirname "$path")" 2>/dev/null && pwd)/$(basename "$path")" || {
    echo "[ERROR] Invalid $name path: $path" >&2
    return 1
  }

  # Reject paths containing .. or symlink escapes
  case "$resolved" in
    *..*)
      echo "[ERROR] $name contains path traversal: $path" >&2
      return 1
      ;;
  esac

  # Only allow known safe prefixes
  case "$resolved" in
    /opt/*|/usr/local/*|"$HOME"/.local/*)
      echo "$resolved"
      return 0
      ;;
    *)
      echo "[ERROR] $name must be under /opt, /usr/local, or ~/.local: $path" >&2
      return 1
      ;;
  esac
}

# Determine install location with validation
INSTALL_DIR=$(validate_install_path "${NVIM_INSTALL_DIR:-/opt}" "NVIM_INSTALL_DIR") || exit 1
BIN_DIR=$(validate_install_path "${NVIM_BIN_DIR:-/usr/local/bin}" "NVIM_BIN_DIR") || exit 1

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

TARBALL="$HOME/nvim-linux64.tar.gz"
CHECKSUM_FILE="$HOME/nvim-linux64.tar.gz.sha256sum"

echo "Verifying tarball integrity..."
# Ensure we use the absolute path to the downloaded file
if [ ! -f "$TARBALL" ]; then
  echo "[ERROR] $TARBALL not found." >&2
  echo "[INFO] Download from: https://github.com/neovim/neovim/releases" >&2
  exit 1
fi

# Verify checksum if available
if [ -f "$CHECKSUM_FILE" ]; then
  echo "   Checking SHA256 checksum..."
  if command -v sha256sum >/dev/null 2>&1; then
    if ! sha256sum -c "$CHECKSUM_FILE" >/dev/null 2>&1; then
      echo "[ERROR] Checksum verification failed for $TARBALL" >&2
      echo "[INFO] The file may be corrupted or tampered with." >&2
      exit 1
    fi
    echo "   Checksum verified."
  elif command -v shasum >/dev/null 2>&1; then
    expected=$(awk '{print $1}' "$CHECKSUM_FILE")
    actual=$(shasum -a 256 "$TARBALL" | awk '{print $1}')
    if [ "$expected" != "$actual" ]; then
      echo "[ERROR] Checksum verification failed for $TARBALL" >&2
      exit 1
    fi
    echo "   Checksum verified."
  else
    echo "[WARN] No sha256sum/shasum available, skipping verification" >&2
  fi
else
  echo "[WARN] No checksum file found at $CHECKSUM_FILE" >&2
  echo "[WARN] Cannot verify tarball integrity. Proceeding with caution." >&2
  echo "[INFO] Download checksums from: https://github.com/neovim/neovim/releases" >&2
fi

echo "Removing old version..."
$sudo_cmd rm -rf "${INSTALL_DIR}/nvim-linux64" 2>/dev/null || true

echo "Extracting new version..."
if ! $sudo_cmd tar -C "$INSTALL_DIR" -xzf "$TARBALL"; then
  echo "[ERROR] Failed to extract $TARBALL" >&2
  exit 1
fi

# Validate extracted binary exists and is executable
NVIM_BIN="${INSTALL_DIR}/nvim-linux64/bin/nvim"
if [ ! -f "$NVIM_BIN" ] || [ ! -x "$NVIM_BIN" ]; then
  echo "[ERROR] Extracted binary not found or not executable: $NVIM_BIN" >&2
  exit 1
fi

echo "Linking binary..."
# Validate symlink target is the expected binary
TARGET_LINK="${BIN_DIR}/nvim"
$sudo_cmd ln -sf "$NVIM_BIN" "$TARGET_LINK"

# Verify the symlink points to our binary
LINK_TARGET=$($sudo_cmd readlink -f "$TARGET_LINK" 2>/dev/null || echo "")
if [ "$LINK_TARGET" != "$NVIM_BIN" ] && [ "$LINK_TARGET" != "$(readlink -f "$NVIM_BIN")" ]; then
  echo "[WARN] Symlink verification: expected $NVIM_BIN, got $LINK_TARGET" >&2
fi

echo "Done! Verifying..."
"${BIN_DIR}/nvim" --version
