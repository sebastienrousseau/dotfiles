#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.456) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

# Load custom executable functions
for function in "${HOME}"/.dotfiles/shell/functions/[!.#]*.sh; do
  # shellcheck source=/dev/null
  source "${function}"
done
