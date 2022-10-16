#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.460) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🅲🅾🅽🅵🅸🅶🆄🆁🅰🆃🅸🅾🅽🆂
for config in "${HOME}"/.dotfiles/lib/configurations/[!.#]*/*.sh; do
  # shellcheck source=/dev/null
  source "${config}"
done
