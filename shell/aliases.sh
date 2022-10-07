#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.454) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🅰🅻🅸🅰🆂🅴🆂

# Load custom executable aliases
for file in "${HOME}"/.dotfiles/shell/aliases/[!.#]*/*.sh; do
  # shellcheck source=/dev/null
  source "${file}"
done
