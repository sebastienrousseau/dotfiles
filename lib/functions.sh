#!/usr/bin/env bash
# Author: Sebastien Rousseau
# Copyright (c) 2015-2023. All rights reserved
# Description: Sets functions for the current shell.
# License: MIT
# Script: functions.sh
# Version: 0.2.463
# Website: https://dotfiles.io

# Load custom executable functions
for function in "${HOME}"/.dotfiles/lib/functions/[!.#]*.sh; do
  # shellcheck source=/dev/null
  source "${function}"
done
