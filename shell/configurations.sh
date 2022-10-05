#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.453) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🅲🅾🅽🅵🅸🅶🆄🆁🅰🆃🅸🅾🅽🆂
for config in "${HOME}"/.dotfiles/shell/configurations/[!.#]*/*.sh; do
  # shellcheck source=/dev/null
  source "${config}"
done
