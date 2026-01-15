#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.470) - History Logging
# Made with ♥ in London, UK by Sebastien Rousseau
# License: MIT

## LOGGING MODULE
## Provides structured logging with configurable levels and output targets

# Configurable environment variables:
# DOTFILES_VERBOSE       - Controls verbosity (0=minimal, 1=normal, 2=debug, 3=trace)
# DOTFILES_LOG_FILE      - Path to log file (empty=log to stderr only)
# DOTFILES_LOG_LEVEL     - Log level (0=errors, 1=warnings, 2=info, 3=debug)

#------------------------------------------------------------------------------
# Enhanced logging function
# Args:
#   $1: Log level (0=ERROR, 1=WARN, 2=INFO, 3=DEBUG)
#   $2: Message to log
#------------------------------------------------------------------------------
log_message() {
  local level="$1"
  local message="$2"
  local log_level="${DOTFILES_LOG_LEVEL:-1}"  # Default log level: warnings and errors
  local log_file="${DOTFILES_LOG_FILE:-}"     # Default: no log file
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

  # Only log if the current level is less than or equal to the configured level
  if [[ "$level" -le "$log_level" ]]; then
    # Determine the log level text
    local level_text
    case "$level" in
      0) level_text="ERROR" ;;
      1) level_text="WARN " ;;
      2) level_text="INFO " ;;
      3) level_text="DEBUG" ;;
      *) level_text="?????" ;;
    esac

    # Format the log message
    local formatted_message="[$timestamp] [$level_text] $message"

    # Always output errors and warnings to stderr
    if [[ "$level" -le 1 ]]; then
      echo "$formatted_message" >&2
    fi

    # If log file is specified and writable, log to file
    if [[ -n "$log_file" ]]; then
      echo "$formatted_message" >> "$log_file" 2>/dev/null || \
        echo "[$timestamp] [ERROR] Failed to write to log file: $log_file" >&2
    # If no log file and level > 1, output to stderr if verbose mode
    elif [[ "$level" -gt 1 ]]; then
      local verbose="${DOTFILES_VERBOSE:-0}"
      if [[ "$verbose" -ge "$level" ]]; then
        echo "$formatted_message" >&2
      fi
    fi
  fi
}
