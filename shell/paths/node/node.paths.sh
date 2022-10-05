#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.453) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🅽🅾🅳🅴 🅿🅰🆃🅷
if [[ "${OSTYPE}" == "darwin"* ]]; then
  NODE_PATH=/opt/homebrew/opt/node
elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
  NODE_PATH=${HOME}/.nvm/versions/node/v18.10.0/bin/node
fi
export NODE_PATH
export PATH="${NODE_PATH}:${PATH}"
