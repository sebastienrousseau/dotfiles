#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.452) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

# Load custom executable functions
for function in "${DOTFILES}"/functions/[!.#]*.sh; do
  # shellcheck source=/dev/null
  . "${function}"
done
