#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.463) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2022. All rights reserved
# License: MIT

## 🅿🅰🆃🅷🆂

# Load custom executable paths.
for file in "${HOME}"/.dotfiles/lib/paths/[!.#]*/*.sh; do
  # shellcheck source=/dev/null
  . "${file}"
done
