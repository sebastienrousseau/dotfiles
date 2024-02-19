#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.468) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2024. All rights reserved
# License: MIT

## 🅽🅾🅳🅴 🅿🅰🆃🅷
if [[ "${OSTYPE}" == "darwin"* ]]; then
  NODE_PATH=/opt/homebrew/Cellar/node@18/18.10.0
elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
  NODE_PATH=${HOME}/.nvm/versions/node/v18.10.0/bin/node
fi
export NODE_PATH
export PATH="${NODE_PATH}:${PATH}"
