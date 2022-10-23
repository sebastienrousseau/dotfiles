#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.462) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2022. All rights reserved
# License: MIT

# Load custom executable functions
for function in "${HOME}"/.dotfiles/lib/functions/[!.#]*.sh; do
  # shellcheck source=/dev/null
  source "${function}"
done
