#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.470) - History Backup
# Made with ♥ in London, UK by Sebastien Rousseau
# License: MIT

## BACKUP MODULE
## Provides file backup and atomic replacement utilities

# Configurable environment variables:
# DOTFILES_BACKUP_SUFFIX - Suffix for backup files (default: .bak)
# DOTFILES_NO_BACKUP     - Set to 1 to disable backups
# DOTFILES_VERBOSE       - Controls verbosity (0=minimal, 1=normal, 2=debug, 3=trace)

# Source logging module
DOTFILES_ROOT="${DOTFILES_ROOT:-${HOME}/.dotfiles}"
# shellcheck source=./logging.sh
source "${DOTFILES_ROOT}/lib/history/logging.sh"

#------------------------------------------------------------------------------
# Create a backup of a file if backup is enabled
# Args:
#   $1: Path to file to backup
# Returns:
#   0 on success, 1 on failure
#------------------------------------------------------------------------------
backup_file() {
  local file="$1"
  local backup_suffix="${DOTFILES_BACKUP_SUFFIX:-.bak}"
  local no_backup="${DOTFILES_NO_BACKUP:-0}"
  local verbose="${DOTFILES_VERBOSE:-0}"

  # Skip backup if disabled
  if [[ "$no_backup" -eq 1 ]]; then
    (( verbose >= 1 )) && echo "Backups disabled, skipping backup of $file" >&2
    return 0
  fi

  # Create backup if file exists
  if [[ -f "$file" ]]; then
    if cp "$file" "${file}${backup_suffix}"; then
      (( verbose >= 1 )) && echo "Created backup: ${file}${backup_suffix}" >&2
      return 0
    else
      (( verbose >= 1 )) && echo "Warning: Failed to create backup of $file" >&2
      return 1
    fi
  fi

  return 0
}

#------------------------------------------------------------------------------
# Atomically replace a file
# Args:
#   $1: Source file
#   $2: Destination file
# Returns:
#   0 on success, 1 on failure
#------------------------------------------------------------------------------
atomic_replace() {
  local src="$1"
  local dst="$2"
  # Use mv for atomic replacement
  log_message 3 "Atomically replacing $dst with $src"
  if mv "$src" "$dst"; then
    log_message 2 "Successfully replaced $dst"
    return 0
  else
    log_message 0 "Failed to replace $dst with $src"
    return 1
  fi
}
