#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.462) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2022. All rights reserved
# License: MIT

## 🅰🅻🅸🅰🆂🅴🆂

# Remove all aliases from the current shell.
unalias -a # Remove all previous environment defined aliases.

# Then load custom Dotfiles aliases.
for file in "${HOME}"/.dotfiles/lib/aliases/[!.#]*/*.sh; do
  # shellcheck source=/dev/null
  source "${file}"
done
