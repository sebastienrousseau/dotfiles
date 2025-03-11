#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂
# Script: configurations.sh
# Version: 0.2.470
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: Script to manage shell configurations
# Website: https://dotfiles.io
# License: MIT
################################################################################

## 🅲🅾🅽🅵🅸🅶🆄🆁🅰🆃🅸🅾🅽🆂
# Function: load_custom_configurations
#
# Description:
#   Loads custom shell configurations from the specified directory.
#
# Arguments:
#   None
#
# Returns:
#   0 on success, 1 on failure
#
# Further Reading:
#   ShellCheck Documentation: https://github.com/koalaman/shellcheck

load_custom_configurations() {
  local config_dir="${HOME}/.dotfiles/lib/configurations"
  local count=0
  local verbose=${DOTFILES_VERBOSE:-0}

  # Check if the directory exists
  if [[ ! -d "${config_dir}" ]]; then
    echo "Warning: Configuration directory ${config_dir} does not exist." >&2
    return 0  # Not considered a fatal error
  fi

  # Search for configuration files, handling no-match case
  shopt -s nullglob
  local config_files=("${config_dir}"/*/[!.#]*.sh)
  shopt -u nullglob

  if [[ ${#config_files[@]} -eq 0 ]]; then
    (( verbose )) && echo "Info: No configuration files found in ${config_dir}" >&2
    return 0
  fi

  for config in "${config_files[@]}"; do
    if [[ -f "${config}" ]]; then
      # shellcheck source=/dev/null
      source "${config}" || {
        echo "Error: Failed to source ${config}" >&2
        return 1
      }
      ((count++))
    fi
  done

  (( verbose )) && echo "Successfully loaded ${count} configuration files."
  return 0
}

load_custom_configurations
