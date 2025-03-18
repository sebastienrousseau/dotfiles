#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂
# Script: aliases.sh
# Version: 0.2.470
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: Script to manage shell aliases
# Website: https://dotfiles.io
# License: MIT
################################################################################

## 🅰🅻🅸🅰🆂🅴🆂

# Function: remove_all_aliases
#
# Description:
#   Removes all aliases from the current shell.
#
# Arguments:
#   None
#
# Returns:
#   0 on success
#
# Further Reading:
#   Bash Unalias Documentation: https://www.gnu.org/software/bash/manual/html_node/Bash-Builtins.html#Bash-Builtins

remove_all_aliases() {
  local verbose=${DOTFILES_VERBOSE:-0}

  unalias -a # Remove all previous environment defined aliases.

  (( verbose )) && echo "Removed all aliases from current environment"
  return 0
}

# Function: load_custom_aliases
#
# Description:
#   Loads custom Dotfiles aliases from the specified directory.
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

load_custom_aliases() {
  local aliases_dir="${HOME}/.dotfiles/lib/aliases"
  local loaded_count=0
  local verbose=${DOTFILES_VERBOSE:-0}
  local ret=0

  if [[ ! -d "${aliases_dir}" ]]; then
    echo "Warning: Aliases directory not found: ${aliases_dir}" >&2
    return 1
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

  # Process alias files in subdirectories
  for file in "${aliases_dir}"/*/[!.#]*.sh; do
    # Skip if not a regular file (handles case when no matches with nullglob)
    [[ -f "${file}" ]] || continue

    # Source the file with error handling
    # shellcheck disable=SC1090
    if ! source "${file}" 2>/dev/null; then
      echo "Error: Failed to source ${file}" >&2
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

  # Report status
  if ((verbose)); then
    if ((loaded_count > 0)); then
      echo "Loaded $loaded_count alias files from ${aliases_dir}" >&2
    else
      echo "Warning: No alias files found in ${aliases_dir}" >&2
    fi
  elif [[ ${loaded_count} -eq 0 ]]; then
    echo "Warning: No alias files found in ${aliases_dir}" >&2
  fi

  return $ret
}

# Main execution
remove_all_aliases
load_custom_aliases
