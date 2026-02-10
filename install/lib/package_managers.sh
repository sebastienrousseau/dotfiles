#!/usr/bin/env bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
# SPDX-License-Identifier: MIT
#
# Package Manager Library
# Handles package manager detection and bootstrapping

# Source dependencies
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=os_detection.sh
source "$SCRIPT_DIR/os_detection.sh" 2>/dev/null || true

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
  echo -e "${CYAN:-}   SECURITY NOTE: This will download and execute code from brew.sh${NC:-}"
  echo "   Verify at: https://github.com/Homebrew/install"

  # In non-interactive mode, proceed with warning
  if [ "${DOTFILES_NONINTERACTIVE:-0}" != "1" ]; then
    read -r -p "   Continue with Homebrew installation? [y/N] " response
    case "$response" in
      [yY][eE][sS]|[yY]) ;;
      *) return 1 ;;
    esac
  fi

  echo "   Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # Add brew to PATH for Apple Silicon
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

# Verify required package manager is available for the current OS
# Returns: 0 if package manager is available, exits with error otherwise
verify_package_manager() {
  # shellcheck disable=SC2154  # target_os set by os_detection.sh
  case "$target_os" in
    debian|wsl2)
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
  if [ "$target_os" = "macos" ]; then
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

  if [ ${#missing[@]} -gt 0 ]; then
    echo "Error: Missing required commands: ${missing[*]}" >&2
    return 1
  fi

  return 0
}
