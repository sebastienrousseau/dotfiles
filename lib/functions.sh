#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂
# Script: functions.sh
# Version: 0.2.468
# Author: @wwdseb
# Copyright (c) 2015-2024. All rights reserved
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
  for function in "${HOME}"/.dotfiles/lib/functions/[!.#]*.sh; do
    # shellcheck source=/dev/null
    source "${function}"
  done
}

load_custom_functions
