#!/usr/bin/env bash
# Author: Sebastien Rousseau
# Copyright (c) 2015-2023. All rights reserved
# Description: Sets aliases for the current shell.
# License: MIT
# Script: aliases.sh
# Version: 0.2.464
# Website: https://dotfiles.io

## 🅰🅻🅸🅰🆂🅴🆂

# Remove all aliases from the current shell.
unalias -a # Remove all previous environment defined aliases.

# Then load custom Dotfiles aliases.
for file in "${HOME}"/.dotfiles/lib/aliases/[!.#]*/*.sh; do
  # shellcheck source=/dev/null
  source "${file}"
done
