#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
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
    /opt/* | /usr/local/* | "$HOME"/.local/*)
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

# select_privilege: root needs nothing, a user gets sudo, and without sudo
# the install falls back to ~/.local.
select_privilege() {
  sudo_cmd=""
  [ "$(id -u)" -ne 0 ] || return 0
  if command -v sudo >/dev/null; then
    sudo_cmd="sudo"
    return 0
  fi
  INSTALL_DIR="${HOME}/.local/opt"
  BIN_DIR="${HOME}/.local/bin"
  echo "[INFO] No sudo available, installing to ${INSTALL_DIR}"
}
select_privilege

# Ensure directories exist
mkdir -p "$INSTALL_DIR" "$BIN_DIR" 2>/dev/null || ${sudo_cmd:+$sudo_cmd} mkdir -p "$INSTALL_DIR" "$BIN_DIR"

TARBALL="$HOME/nvim-linux64.tar.gz"
CHECKSUM_FILE="$HOME/nvim-linux64.tar.gz.sha256sum"

# verify_tarball <tarball> <checksum_file>: exit unless <tarball> matches
# the first SHA-256 in <checksum_file>.
verify_tarball() {
  local tarball="$1" checksum_file="$2" expected actual
  # Ensure we use the absolute path to the downloaded file
  if [ ! -f "$tarball" ]; then
    echo "[ERROR] $tarball not found." >&2
    echo "[INFO] Download from: https://github.com/neovim/neovim/releases" >&2
    exit 1
  fi

  # A checksum is mandatory: this script installs an executable with user or
  # root privileges and must never silently downgrade to transport-only trust.
  if [ -f "$checksum_file" ]; then
    echo "   Checking SHA256 checksum..."
    # Hash $tarball itself. `sha256sum -c` would check the file NAMED in the
    # checksum file relative to the current directory instead.
    expected="$(awk 'NF { print $1; exit }' "$checksum_file")"
    if command -v sha256sum >/dev/null 2>&1; then
      actual="$(sha256sum "$tarball" | awk '{print $1}')"
    elif command -v shasum >/dev/null 2>&1; then
      actual="$(shasum -a 256 "$tarball" | awk '{print $1}')"
    else
      echo "[ERROR] No SHA-256 verifier available; refusing installation" >&2
      exit 1
    fi
    if [ -z "$expected" ] || [ "$expected" != "$actual" ]; then
      echo "[ERROR] Checksum verification failed for $tarball" >&2
      echo "[INFO] The file may be corrupted or tampered with." >&2
      exit 1
    fi
    echo "   Checksum verified."
  else
    echo "[ERROR] No checksum file found at $checksum_file" >&2
    echo "[ERROR] Refusing to install an unverified executable archive." >&2
    echo "[INFO] Download checksums from: https://github.com/neovim/neovim/releases" >&2
    exit 1
  fi
}

echo "Verifying tarball integrity..."
verify_tarball "$TARBALL" "$CHECKSUM_FILE"

echo "Removing old version..."
${sudo_cmd:+$sudo_cmd} rm -rf "${INSTALL_DIR}/nvim-linux64" 2>/dev/null || true

# extract_tarball: unpack $TARBALL into $INSTALL_DIR and check the binary.
extract_tarball() {
  echo "Extracting new version..."
  if ! ${sudo_cmd:+$sudo_cmd} tar -C "$INSTALL_DIR" -xzf "$TARBALL"; then
    echo "[ERROR] Failed to extract $TARBALL" >&2
    exit 1
  fi

  # Validate extracted binary exists and is executable
  NVIM_BIN="${INSTALL_DIR}/nvim-linux64/bin/nvim"
  if [ ! -f "$NVIM_BIN" ] || [ ! -x "$NVIM_BIN" ]; then
    echo "[ERROR] Extracted binary not found or not executable: $NVIM_BIN" >&2
    exit 1
  fi
}
extract_tarball

echo "Linking binary..."
# Validate symlink target is the expected binary
TARGET_LINK="${BIN_DIR}/nvim"
${sudo_cmd:+$sudo_cmd} ln -sf "$NVIM_BIN" "$TARGET_LINK"

# Portable readlink -f (fallback to realpath)
portable_readlink() {
  readlink -f "$1" 2>/dev/null || realpath "$1" 2>/dev/null || echo ""
}

# Verify the symlink points to our binary
LINK_TARGET=$(portable_readlink "$TARGET_LINK")
if [ "$LINK_TARGET" != "$NVIM_BIN" ] && [ "$LINK_TARGET" != "$(portable_readlink "$NVIM_BIN")" ]; then
  echo "[WARN] Symlink verification: expected $NVIM_BIN, got $LINK_TARGET" >&2
fi

echo "Done! Verifying..."
"${BIN_DIR}/nvim" --version
