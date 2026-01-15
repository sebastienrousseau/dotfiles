#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂
# Script: paths.sh
# Version: 0.2.470
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: Script to load custom paths
# Website: https://dotfiles.io
# License: MIT
################################################################################

# Function: load_paths
#
# Description:
#   Loads all the paths from the specified directory.
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

load_paths() {
  local paths_dir="${HOME}/.dotfiles/lib/paths"
  local loaded_count=0
  local verbose=${DOTFILES_VERBOSE:-0}
  local ret=0

  # Check if the directory exists
  if [[ ! -d "$paths_dir" ]]; then
    echo "Warning: Paths directory $paths_dir does not exist." >&2
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

  # Load each path file
  for path_file in "$paths_dir"/*.sh; do
    # Skip if not a regular file (handles case when no .sh files exist with nullglob)
    [[ -f "$path_file" ]] || continue

    # Source the file with error handling
    # shellcheck disable=SC1090
    if ! source "$path_file" 2>/dev/null; then
      echo "Error: Failed to source $path_file" >&2
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
      echo "Loaded $loaded_count path files from $paths_dir"
    else
      echo "No path files found in $paths_dir"
    fi
  fi

  return $ret
}

# Main Execution
# ---------------------------------------------------------
load_paths
