#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.453) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🅿🆈🆃🅷🅾🅽 🅿🅰🆃🅷
if [[ "${OSTYPE}" == "darwin"* ]]; then
  if [[ -d "/opt/homebrew/opt/python/bin" ]]; then
    PYTHONHOME="/opt/homebrew/opt/python/bin"
  fi
elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
  PYTHONHOME="/usr/lib/python*/"
fi
export PYTHONHOME
export PATH="${PYTHONHOME}:${PATH}"
