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
  for path in "${HOME}"/.dotfiles/lib/paths/[!.#]*/*.sh; do
    # shellcheck source=/dev/null
    source "${path}"
  done
}

load_paths
