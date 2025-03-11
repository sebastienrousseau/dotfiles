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
# Further Reading:
#   Bash Unalias Documentation: https://www.gnu.org/software/bash/manual/html_node/Bash-Builtins.html#Bash-Builtins

remove_all_aliases() {
  unalias -a # Remove all previous environment defined aliases.
}

# Function: load_custom_aliases
#
# Description:
#   Loads custom Dotfiles aliases from the specified directory.
#
# Arguments:
#   None
#
# Further Reading:
#   ShellCheck Documentation: https://github.com/koalaman/shellcheck

load_custom_aliases() {
  local aliases_dir="${HOME}/.dotfiles/lib/aliases"

  if [[ ! -d "${aliases_dir}" ]]; then
    echo "Warning: Aliases directory not found: ${aliases_dir}" >&2
    return 1
  fi

  # Count loaded files for reporting
  local count=0

  for file in "${aliases_dir}"/*/[!.#]*.sh; do
    if [[ -f "${file}" ]]; then
      # shellcheck source=/dev/null
      source "${file}"
      ((count++))
    fi
  done

  if [[ ${count} -eq 0 ]]; then
    echo "Warning: No alias files found in ${aliases_dir}" >&2
    return 0
  fi

  return 0
}

# Main execution
remove_all_aliases
load_custom_aliases
