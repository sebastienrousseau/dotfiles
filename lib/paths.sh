#!/usr/bin/env bash
# Author: Sebastien Rousseau
# Copyright (c) 2015-2023. All rights reserved
# Description: Sets paths for the current shell.
# License: MIT
# Script: paths.sh
# Version: 0.2.464
# Website: https://dotfiles.io

## 🅿🅰🆃🅷🆂

# Load custom executable paths.
for file in "${HOME}"/.dotfiles/lib/paths/[!.#]*/*.sh; do
  # shellcheck source=/dev/null
  . "${file}"
done
