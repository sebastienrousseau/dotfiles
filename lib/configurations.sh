#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂
# Script: configurations.sh
# Version: 0.2.469
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
# Further Reading:
#   ShellCheck Documentation: https://github.com/koalaman/shellcheck

load_custom_configurations() {
  local config_dir="${HOME}/.dotfiles/lib/configurations"

  # Check if the directory exists
  if [[ -d "${config_dir}" ]]; then
    for config in "${config_dir}"/[!.#]*/*.sh; do
      if [[ -f "${config}" ]]; then
        # shellcheck source=/dev/null
        source "${config}" || {
          echo "Error: Failed to source ${config}" >&2
          return 1
        }
      fi
    done
  else
    echo "Warning: Configuration directory ${config_dir} does not exist." >&2
  fi
}

load_custom_configurations
