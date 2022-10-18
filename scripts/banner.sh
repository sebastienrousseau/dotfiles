#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.461) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2022. All rights reserved
# License: MIT

## 🅱🅰🅽🅽🅴🆁 - Display banner.

# shellcheck disable=SC2154
clear
cat <<EOF

┌───────────────────────────────────────────────┐
│             $(echo -e "\033[1;96mDotfiles (v${DF_VERSION})\033[0m\n")               │
├───────────────────────────────────────────────┤
│    $(echo -e "\033[0;93mSimply designed to fit your shell life\033[0m\n")     │
└───────────────────────────────────────────────┘

EOF
