#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.470) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# License: MIT

## HISTORY MANAGEMENT
##
## This module provides shell history management with deduplication, sorting,
## and clearing capabilities. It's organized into logical submodules:
##
##   - logging.sh:   Structured logging with configurable levels
##   - utils.sh:     Temporary file management and formatting
##   - backup.sh:    File backup and atomic replacement utilities
##   - core.sh:      Main history management functions
##   - config.sh:    Shell-specific configuration and aliases
##
## Usage:
##   h              Display history
##   h -c           Clear history
##   h -s           Sort history and remove duplicates
##   h -l [args]    List history with the given arguments
##
## Environment variables:
##   DOTFILES_VERBOSE       - Verbosity level (0=minimal, 1=normal, 2=debug, 3=trace)
##   DOTFILES_BACKUP_SUFFIX - Suffix for backup files (default: .bak)
##   DOTFILES_NO_BACKUP     - Set to 1 to disable backups
##   DOTFILES_NUM_COLOR     - ANSI color code for history numbers (default: 33=yellow)
##   DOTFILES_CMD_COLOR     - ANSI color code for commands (default: terminal default)
##   DOTFILES_LOG_FILE      - Path to log file (default: log to stderr only)
##   DOTFILES_LOG_LEVEL     - Log level (0=errors, 1=warnings, 2=info, 3=debug)

# Set DOTFILES_ROOT for submodule sourcing
DOTFILES_ROOT="${DOTFILES_ROOT:-${HOME}/.dotfiles}"

# Source all history submodules
# shellcheck source=./history/config.sh
source "${DOTFILES_ROOT}/lib/history/config.sh"

# Main execution for direct script invocation
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Script is being executed directly
  if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    print_usage
    exit 0
  fi
fi
