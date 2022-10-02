#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.452) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🅽🅾🅳🅴 🅿🅰🆃🅷
if [[ -z "${NODE_PATH}" ]]; then
  if [[ "${OSTYPE}" == "darwin"* ]]; then
    NODE_PATH=${HOME}/.nvm/versions/node/v18.9.1/bin/node
  elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
    NODE_PATH=${HOME}/.nvm/versions/node/$(node -v)/bin/node
  fi
  export NODE_PATH
  export PATH="${NODE_PATH}:${PATH}"
fi
