#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.468) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2024. All rights reserved
# License: MIT
# Script: configurations.sh
# Version: 0.2.468
# Website: https://dotfiles.io

## 🅲🅾🅽🅵🅸🅶🆄🆁🅰🆃🅸🅾🅽🆂
for config in "${HOME}"/.dotfiles/lib/configurations/[!.#]*/*.sh; do
  # shellcheck source=/dev/null
  source "${config}"
done
