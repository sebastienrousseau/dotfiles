#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.466) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2023. All rights reserved
# License: MIT
# Script: paths.sh
# Version: 0.2.466
# Website: https://dotfiles.io

## 🅿🅰🆃🅷🆂

# Load custom executable paths.
for file in "${HOME}"/.dotfiles/lib/paths/[!.#]*/*.sh; do
  # shellcheck source=/dev/null
  . "${file}"
done
