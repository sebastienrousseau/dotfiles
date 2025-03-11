#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂
# Script: aliases.sh
# Version: 0.2.470
# Author: @wwdseb
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
  for file in "${HOME}"/.dotfiles/lib/aliases/[!.#]*/*.sh; do
    # shellcheck source=/dev/null
    source "${file}"
  done
}

remove_all_aliases
load_custom_aliases
