# shellcheck shell=bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Description:
#   last is a utility function to list recently modified files within a
#   specified time range. By default, it lists files modified in the last 60
#   minutes but allows customization.
#
# Usage:
#   last [minutes]
#   last --help
#
# Arguments:
#   minutes     Number of minutes to look back for modified files (default: 60)
#             Maximum: 7 days (10080 minutes)
#   --help      Displays this help menu and exits
#
################################################################################

#
################################################################################

# Source shared logging utilities if not already defined
if ! declare -f log_error >/dev/null 2>&1; then
  _last_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
  if [[ -f "${_last_dir}/utils/logging.sh" ]]; then
    # shellcheck source=utils/logging.sh
    source "${_last_dir}/utils/logging.sh"
  else
    # Minimal fallback logging functions
    log_error() { echo "[ERROR] $*" >&2; }
    log_info() { echo "[INFO] $*"; }
    log_warning() { echo "[WARNING] $*" >&2; }
  fi
  unset _last_dir
fi

detect_tool() {
  if command -v /usr/bin/find &>/dev/null; then
    echo "find"
  elif command -v fd &>/dev/null; then
    echo "fd"
  elif command -v rg &>/dev/null; then
    echo "rg"
  else
    log_error "No compatible tools found (find, fd, or rg)."
    return 1
  fi
}

last() {
  # Display help menu
  if [[ "${1:-}" == "--help" ]]; then
    cat <<'EOH'
🅳🅾🆃🅵🅸🅻🅴🆂 - Recently Modified Files Viewer

Description:
  last is a utility function to list recently modified files within a specified
  time range. By default, it lists files modified in the last 60 minutes.

Usage:
  last [minutes]
  last --help

Arguments:
  minutes     Number of minutes to look back for modified files (default: 60)
             Maximum: 7 days (10080 minutes)
  --help      Displays this help menu and exits

Examples:
  last
      # Lists files modified within the last 60 minutes
  last 120
      # Lists files modified within the last 120 minutes

Notes:
  - Only regular files are shown
  - Symbolic links and directories are excluded from the results
  - Searches recursively starting from the current directory
  - Maximum time range is 7 days (10080 minutes)
EOH
    return 0
  fi

  # Default time range (60 minutes)
  local minutes=${1:-60}

  # Validate that the input is a positive integer
  if ! [[ "$minutes" =~ ^[0-9]+$ ]]; then
    log_error "Invalid input: '$minutes'. Please provide a positive integer for minutes."
    return 1
  fi

  # Check maximum time range (7 days = 10080 minutes)
  if ((minutes > 10080)); then
    log_error "Time range too large. Maximum is 7 days (10080 minutes)."
    return 1
  fi

  # Detect which tool to use
  local tool
  tool=$(detect_tool)

  # Find and list modified files
  log_info "Listing files modified in the last ${minutes} minutes (using $tool):"
  case "$tool" in
    "find")
      command find . -type f -mmin -"${minutes}"
      ;;
    "fd")
      fd --type file --changed-within "${minutes}m"
      ;;
    "rg")
      rg --type file --changed-within "${minutes}m"
      ;;
    *)
      log_error "Unknown tool detected."
      return 1
      ;;
  esac
}
