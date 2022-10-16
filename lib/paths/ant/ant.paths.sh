#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.460) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🅰🅽🆃 🅷🅾🅼🅴
if [[ -z "${ANT_HOME}" ]]; then
  if [[ "${OSTYPE}" == "darwin"* ]]; then
    ANT_HOME="/opt/homebrew/Cellar/ant/1.10.12/"
  elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
    ANT_HOME="/usr/share/ant/"
  fi
  export ANT_HOME
  export PATH="${ANT_HOME}:${PATH}"
fi
