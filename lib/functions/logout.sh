#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - Cross-Platform Logout Utility (logout)
# Made with ♥ by Sebastien Rousseau
# License: MIT
#
# Description:
#   logout is a utility function to log out from macOS, Linux, or Windows via
#   the terminal. It provides options for confirmation and forceful logout if
#   necessary.
#
# Usage:
#   logout [--force] [--help]
#
# Arguments:
#   --force     Skips confirmation and forces logout.
#   --help      Displays this help menu and exits.
#
################################################################################

log_info() {
  echo "[INFO] $*"
}

log_warning() {
  echo "[WARNING] $*" >&2
}

log_error() {
  echo "[ERROR] $*" >&2
  exit 1
}

logout() {
  # Display help menu
  if [[ "$1" == "--help" ]]; then
    cat << 'EOH'
Cross-Platform Logout Utility (logout)

Description:
  logout is a utility function to log out from macOS, Linux, or Windows via the
  terminal. It provides options for confirmation and forceful logout if
  necessary.

Usage:
  logout [--force] [--help]

Arguments:
  --force     Skips confirmation and forces logout.
  --help      Displays this help menu and exits.

Examples:
  logout
      # Prompts for confirmation before logging out.

  logout --force
      # Logs out immediately without confirmation.

Notes:
  - Requires administrative privileges for some systems (Linux/Windows).
  - May prompt for a password depending on system settings.
EOH
    return 0
  fi

  # Check if the user passed --force
  local force=false
  if [[ "$1" == "--force" ]]; then
    force=true
  fi

  # Prompt for confirmation if not forced
  if [[ "$force" == false ]]; then
    echo "Are you sure you want to log out? (y/n):"
    read -r response
    case "$response" in
      [Yy]*)
        ;;
      *)
        log_info "Logout canceled."
        return 0
        ;;
    esac
  fi

  # Detect operating system
  local os
  os=$(uname | tr '[:upper:]' '[:lower:]')

  case "$os" in
    "darwin")
      log_info "Logging out from macOS..."
      if ! osascript -e 'tell application "System Events" to log out'; then
        log_error "Failed to log out using AppleScript. Try logging out manually."
      fi
      ;;
    "linux")
      log_info "Logging out from Linux..."
      if command -v gnome-session-quit &>/dev/null; then
        gnome-session-quit --logout --no-prompt
      elif command -v loginctl &>/dev/null; then
        loginctl terminate-user "$USER"
      else
        log_error "Unable to determine logout method for your Linux system. Try logging out manually."
      fi
      ;;
    "msys" | "cygwin" | "mingw"*)
      log_info "Logging out from Windows..."
      if ! shutdown /l; then
        log_error "Failed to log out from Windows. Try logging out manually."
      fi
      ;;
    *)
      log_error "Unsupported operating system: $os"
      ;;
  esac

  return 0
}
