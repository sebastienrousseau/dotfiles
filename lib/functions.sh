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
#
# Arguments:
#   None
#
# Further Reading:
#   ShellCheck Documentation: https://github.com/koalaman/shellcheck

load_custom_functions() {
  local functions_dir="${HOME}/.dotfiles/lib/functions"

  # Check if the directory exists
  if [[ -d "$functions_dir" ]]; then
    for function_file in "$functions_dir"/*.sh; do
      if [[ -f "$function_file" ]]; then
        # shellcheck source=/dev/null
        source "$function_file" || {
          echo "Error: Failed to source $function_file" >&2
          return 1
        }
      fi
    done
  else
    echo "Warning: Functions directory $functions_dir does not exist." >&2
  fi
}

# Main Execution
# ---------------------------------------------------------
load_custom_functions
