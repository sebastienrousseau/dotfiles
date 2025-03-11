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

## 🅿🅰🆃🅷🆂
# Function: load_paths
#
# Description:
#   Loads all the paths from the specified directory.
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
  local count=0
  local verbose=${DOTFILES_VERBOSE:-0}

  # Check if the directory exists
  if [[ ! -d "${paths_dir}" ]]; then
    echo "Warning: Paths directory ${paths_dir} does not exist." >&2
    return 0  # Not considered a fatal error
  fi

  # Search for path files, handling no-match case
  shopt -s nullglob
  local path_files=("${paths_dir}"/[!.#]*.sh)
  shopt -u nullglob

  if [[ ${#path_files[@]} -eq 0 ]]; then
    (( verbose )) && echo "Info: No path files found in ${paths_dir}" >&2
    return 0
  fi

  for path_file in "${path_files[@]}"; do
    if [[ -f "${path_file}" ]]; then
      # shellcheck source=/dev/null
      source "${path_file}" || {
        echo "Error: Failed to source ${path_file}" >&2
        return 1
      }
      ((count++))
    fi
  done

  (( verbose )) && echo "Successfully loaded ${count} path files."
  return 0
}

# Main Execution
# ---------------------------------------------------------
load_paths
