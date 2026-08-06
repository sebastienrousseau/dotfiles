#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# Package Manager Library
# Handles package manager detection and bootstrapping

set -euo pipefail

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=os_detection.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/os_detection.sh" 2>/dev/null || true
# shellcheck source=../../lib/dot/verified-download.sh disable=SC1091
source "$SCRIPT_DIR/../../lib/dot/verified-download.sh"

# Check if Homebrew is installed
has_brew() {
  command -v brew >/dev/null 2>&1
}

# Check if apt is available
has_apt() {
  command -v apt-get >/dev/null 2>&1
}

# Check if dnf is available
has_dnf() {
  command -v dnf >/dev/null 2>&1
}

# Check if pacman is available
has_pacman() {
  command -v pacman >/dev/null 2>&1
}

# Install Homebrew on macOS
# Returns: 0 on success, 1 on failure or cancellation
install_homebrew() {
  if has_brew; then
    return 0
  fi

  echo "   Homebrew not found."
  printf '%b\n' "${CYAN:-}   SECURITY NOTE: This will download and execute code from brew.sh${NC:-}"
  echo "   Verify at: https://github.com/Homebrew/install"

  # In non-interactive mode, proceed with warning
  if [[ "${DOTFILES_NONINTERACTIVE:-0}" != "1" ]]; then
    read -r -p "   Continue with Homebrew installation? [y/N] " response
    case "$response" in
      [yY][eE][sS] | [yY]) ;;
      *) return 1 ;;
    esac
  fi

  echo "   Installing Homebrew..."
  local installer actual_sha256
  local HOMEBREW_INSTALLER_REVISION="24173182915f24bdd52a22fd073e421953b2a252"
  local HOMEBREW_INSTALLER_SHA256="12479a24be3f5307eecac7cde670fad7118640f031229e964f544b1367b52a41"
  local HOMEBREW_INSTALLER_URL="https://raw.githubusercontent.com/Homebrew/install/${HOMEBREW_INSTALLER_REVISION}/install.sh"
  installer="$(umask 077 && mktemp)"
  if ! download_verified_script "$HOMEBREW_INSTALLER_URL" "$installer" 65536; then
    rm -f "$installer"
    echo "Error: failed to download Homebrew installer." >&2
    return 1
  fi
  actual_sha256="$(_dot_sha256_file "$installer")" || {
    rm -f "$installer"
    echo "Error: cannot verify Homebrew installer checksum." >&2
    return 1
  }
  if [[ "$actual_sha256" != "$HOMEBREW_INSTALLER_SHA256" ]]; then
    rm -f "$installer"
    echo "Error: Homebrew installer checksum mismatch." >&2
    return 1
  fi

  /bin/bash "$installer"
  rm -f "$installer"

  # Add brew to PATH for Apple Silicon
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

# Verify required package manager is available for the current OS
# Returns: 0 if package manager is available, exits with error otherwise
verify_package_manager() {
  # shellcheck disable=SC2154  # target_os set by os_detection.sh
  case "$target_os" in
    debian | wsl2)
      if ! has_apt; then
        echo "Error: apt-get is required on Debian/Ubuntu/WSL2." >&2
        return 1
      fi
      ;;
    fedora)
      if ! has_dnf; then
        echo "Error: dnf is required on Fedora/RHEL." >&2
        return 1
      fi
      ;;
    arch)
      if ! has_pacman; then
        echo "Error: pacman is required on Arch Linux." >&2
        return 1
      fi
      ;;
  esac
  return 0
}

# Bootstrap package manager for the current OS
# This ensures the appropriate package manager is available
bootstrap_package_manager() {
  if [[ "$target_os" = "macos" ]]; then
    if ! install_homebrew; then
      echo "Error: Homebrew installation cancelled. Install manually: https://brew.sh" >&2
      return 1
    fi
  fi

  verify_package_manager
}

# Check for required commands
check_prerequisites() {
  local missing=()

  if ! command -v curl >/dev/null 2>&1; then
    missing+=("curl")
  fi

  if ! command -v git >/dev/null 2>&1; then
    missing+=("git")
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Error: Missing required commands: ${missing[*]}" >&2
    return 1
  fi

  return 0
}
