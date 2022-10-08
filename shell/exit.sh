#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.456) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

# When leaving the console clear the screen to increase privacy
if [[ "${SHLVL}" = 1 ]]; then
  clear && printf '\e[3J'
fi
