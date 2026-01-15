#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂
# Script: functions.sh
# Version: 0.2.470
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: Script to load custom executable functions
# Website: https://dotfiles.io
# License: MIT
################################################################################

# Function: load_custom_functions
#
# Description:
#   Loads custom executable functions from the specified directory.
#   Compatible with both Bash and Zsh shells.
#
# Arguments:
#   None
#
# Returns:
#   0 on success, 1 on failure
#
# Further Reading:
#   ShellCheck Documentation: https://github.com/koalaman/shellcheck

load_custom_functions() {
  local functions_dir="${HOME}/.dotfiles/lib/functions"
  local loaded_count=0
  local verbose=${DOTFILES_VERBOSE:-0}
  local ret=0

  # Check if the directory exists
  if [[ ! -d "$functions_dir" ]]; then
    echo "Warning: Functions directory $functions_dir does not exist." >&2
    return 0  # Not a critical error, return success
  fi

  # Enable nullglob to handle empty directories
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    setopt local_options nullglob
  elif [[ -n "${BASH_VERSION:-}" ]]; then
    # Save current state
    local globstate
    globstate=$(shopt -p nullglob)
    shopt -s nullglob
  fi

  # Load each function file
  for function_file in "$functions_dir"/*.sh; do
    # Skip if not a regular file (handles case when no .sh files exist with nullglob)
    [[ -f "$function_file" ]] || continue

    # Source the file with error handling
    # shellcheck disable=SC1090
    if ! source "$function_file" 2>/dev/null; then
      echo "Error: Failed to source $function_file" >&2
      ret=1
      continue
    fi

    ((loaded_count++))
  done

  # Restore globbing settings in Bash
  if [[ -n "${BASH_VERSION:-}" ]]; then
    eval "$globstate"
  fi

  # Report status if verbose mode is enabled
  if ((verbose)); then
    if ((loaded_count > 0)); then
      echo "Loaded $loaded_count function files from $functions_dir"
    else
      echo "No function files found in $functions_dir"
    fi
  fi

  return $ret
}

# Main Execution
# ---------------------------------------------------------
load_custom_functions
