#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.460) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

# Load custom executable functions
for function in "${HOME}"/.dotfiles/lib/functions/[!.#]*.sh; do
  # shellcheck source=/dev/null
  source "${function}"
done
