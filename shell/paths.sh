#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.452) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🅿🅰🆃🅷🆂

# Load custom executable paths.
for file in "${DOTFILES}"/paths/[!.#]*/*.sh; do
  # shellcheck source=/dev/null
  source "${file}"
done
