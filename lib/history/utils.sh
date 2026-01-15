#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.470) - History Utilities
# Made with ♥ in London, UK by Sebastien Rousseau
# License: MIT

## UTILITIES MODULE
## Provides temporary file management, cleanup, and formatting helpers

# Source logging module
DOTFILES_ROOT="${DOTFILES_ROOT:-${HOME}/.dotfiles}"
# shellcheck source=./logging.sh
source "${DOTFILES_ROOT}/lib/history/logging.sh"

#------------------------------------------------------------------------------
# Global variables for temporary file tracking and cleanup
#------------------------------------------------------------------------------
declare -a TEMP_FILES=()  # Array to track temporary files for cleanup

#------------------------------------------------------------------------------
# Creates a temporary file and registers it for cleanup
# Returns:
#   Prints the path to the temporary file
#------------------------------------------------------------------------------
create_temp_file() {
  local temp_file
  temp_file="$(mktemp)" || {
    log_message 0 "Failed to create temporary file"
    return 1
  }

  # Add to the array of temp files to clean up
  TEMP_FILES+=("$temp_file")

  # Return the temp file path
  echo "$temp_file"
}

#------------------------------------------------------------------------------
# Cleanup function for temporary files and resources
#------------------------------------------------------------------------------
cleanup() {
  # Remove all tracked temporary files
  for temp_file in "${TEMP_FILES[@]}"; do
    if [[ -f "$temp_file" ]]; then
      rm -f "$temp_file"
      log_message 3 "Cleaned up temporary file: $temp_file"
    fi
  done

  # Reset the array
  TEMP_FILES=()
}

# Set up the cleanup trap for multiple signals
trap cleanup EXIT INT TERM HUP

#------------------------------------------------------------------------------
# Helper function to format and colorize history output
# Args:
#   $1: The history output to format
#------------------------------------------------------------------------------
format_history_output() {
  local input="$1"
  local num_color="${DOTFILES_NUM_COLOR:-33}"  # Default: yellow
  local cmd_color="${DOTFILES_CMD_COLOR:-}"    # Default: terminal default

  # If no command color specified, just use reset code
  local cmd_color_code=""
  if [[ -n "$cmd_color" ]]; then
    cmd_color_code="\033[${cmd_color}m"
  fi

  # Remove date/time format (matches YYYY-MM-DD HH:MM format)
  # Then colorize the line number while keeping the command
  echo "$input" |
    sed -E 's/[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}//g' |
    sed 's/^ *//' |
    awk -v num_color="$num_color" -v cmd_color="$cmd_color_code" '{
      # Print history number in specified color (default yellow)
      printf("\033[%sm%s\033[0m ", num_color, $1);

      # Find where the command part starts (after the first field)
      cmd_part = substr($0, index($0,$2));

      # Print command in specified color or default terminal color
      printf("%s%s\n", cmd_color, cmd_part);
    }'
}
