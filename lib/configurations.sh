#!/usr/bin/env bash
# Author: Sebastien Rousseau
# Copyright (c) 2015-2023. All rights reserved
# Description: Sets configurations for the current shell.
# License: MIT
# Script: configurations.sh
# Version: 0.2.463
# Website: https://dotfiles.io

## 🅲🅾🅽🅵🅸🅶🆄🆁🅰🆃🅸🅾🅽🆂
for config in "${HOME}"/.dotfiles/lib/configurations/[!.#]*/*.sh; do
  # shellcheck source=/dev/null
  source "${config}"
done
