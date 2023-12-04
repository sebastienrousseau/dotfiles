#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.467) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

## 🅰🅽🆃 🅷🅾🅼🅴
if [[ "${OSTYPE}" == "darwin"* ]]; then
  ANT_HOME="/opt/homebrew/Cellar/ant/"
elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
  ANT_HOME="/usr/share/ant/"
fi
export ANT_HOME
export PATH="${ANT_HOME}/bin:${PATH}"
