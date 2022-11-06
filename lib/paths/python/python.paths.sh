#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.462) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2022. All rights reserved
# License: MIT

## 🅿🆈🆃🅷🅾🅽 🅿🅰🆃🅷
if [[ "${OSTYPE}" == "darwin"* ]]; then
  if [[ -d "/opt/homebrew/opt/python/bin" ]]; then
    PYTHONHOME="/opt/homebrew/opt/python/bin"
  fi
elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
  if [[ -d "/usr/bin/python3.9" ]]; then
    PYTHONHOME="/usr/lib/python3.9"
  fi
fi

# Encoding[:errors] used for stdin/stdout/stderr.
export PYTHONIOENCODING='UTF-8'

# If set to 1, enables the UTF-8 mode.
export PYTHONUTF8=1

# Export PYTHONHOME variable
export PYTHONHOME
export PATH="${PYTHONHOME}:${PATH}"

# Export PYTHONPATH variable
export PYTHONPATH="${PYTHONHOME}"
export PATH="${PYTHONPATH}:${PATH}"
