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

load_custom_configurations() {
  local config_dir="${HOME}/.dotfiles/lib/configurations"
  local loaded_count=0
  local verbose=${DOTFILES_VERBOSE:-0}
  local ret=0

  # Check if the directory exists
  if [[ ! -d "${config_dir}" ]]; then
    echo "Warning: Configuration directory ${config_dir} does not exist." >&2
    return 0  # Not a critical error, return success
  fi

  # Enable extended glob and nullglob for both shells
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    setopt local_options nullglob extendedglob
  elif [[ -n "${BASH_VERSION:-}" ]]; then
    # Save current state
    local globstate extglobstate
    globstate=$(shopt -p nullglob)
    extglobstate=$(shopt -p extglob)
    shopt -s nullglob extglob
  fi

  # Process configuration files in subdirectories
  for config in "${config_dir}"/[!.#]*/*.sh; do
    # Skip if not a regular file (handles case when no matches with nullglob)
    [[ -f "${config}" ]] || continue

    # Source the file with error handling
    # shellcheck disable=SC1090
    if ! source "${config}" 2>/dev/null; then
      echo "Error: Failed to source ${config}" >&2
      ret=1
      continue
    fi

    ((loaded_count++))
  done

  # Restore globbing settings in Bash
  if [[ -n "${BASH_VERSION:-}" ]]; then
    eval "$globstate"
    eval "$extglobstate"
  fi

  # Report status if verbose mode is enabled
  if ((verbose)); then
    if ((loaded_count > 0)); then
      echo "Loaded $loaded_count configuration files from ${config_dir}"
    else
      echo "No configuration files found in ${config_dir}"
    fi
  fi

  return $ret
}

# Main Execution
# ---------------------------------------------------------
load_custom_configurations
