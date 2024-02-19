#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.468) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2024. All rights reserved
# License: MIT
# Script: functions.sh
# Version: 0.2.468
# Website: https://dotfiles.io

# Load custom executable functions
for function in "${HOME}"/.dotfiles/lib/functions/[!.#]*.sh; do
  # shellcheck source=/dev/null
  source "${function}"
done
