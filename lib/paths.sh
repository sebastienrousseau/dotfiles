#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂
# Script: paths.sh
# Version: 0.2.469
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
#
# Arguments:
#   None
#
# Further Reading:
#   ShellCheck Documentation: https://github.com/koalaman/shellcheck

load_paths() {
  local paths_dir="${HOME}/.dotfiles/lib/paths"

  # Check if the directory exists
  if [[ -d "$paths_dir" ]]; then
    for path_file in "$paths_dir"/*.sh; do
      if [[ -f "$path_file" ]]; then
        # shellcheck source=/dev/null
        source "$path_file" || {
          echo "Error: Failed to source $path_file" >&2
          return 1
        }
      fi
    done
  else
    echo "Warning: Paths directory $paths_dir does not exist." >&2
  fi
}

# Main Execution
# ---------------------------------------------------------
load_paths
