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

## 🅵🆄🅽🅲🆃🅸🅾🅽🆂
# Function: load_custom_functions
#
# Description:
#   Loads custom executable functions from the specified directory.
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
  local count=0
  local verbose=${DOTFILES_VERBOSE:-0}

  # Check if the directory exists
  if [[ ! -d "${functions_dir}" ]]; then
    echo "Warning: Functions directory ${functions_dir} does not exist." >&2
    return 0  # Not considered a fatal error
  fi

  # Search for function files, handling no-match case
  shopt -s nullglob
  local function_files=("${functions_dir}"/[!.#]*.sh)
  shopt -u nullglob

  if [[ ${#function_files[@]} -eq 0 ]]; then
    (( verbose )) && echo "Info: No function files found in ${functions_dir}" >&2
    return 0
  fi

  for function_file in "${function_files[@]}"; do
    if [[ -f "${function_file}" ]]; then
      # shellcheck source=/dev/null
      source "${function_file}" || {
        echo "Error: Failed to source ${function_file}" >&2
        return 1
      }
      ((count++))
    fi
  done

  (( verbose )) && echo "Successfully loaded ${count} function files."
  return 0
}

# Main Execution
# ---------------------------------------------------------
load_custom_functions
