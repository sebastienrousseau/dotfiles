#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.458) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🅽🆅🅼 🅿🅰🆃🅷
if [[ "${OSTYPE}" == "darwin"* ]]; then
  NVM_DIR="${HOME}"/.nvm
  # shellcheck source=/dev/null
  [[ -s "/opt/homebrew/opt/nvm/nvm.sh" ]] && . "/opt/homebrew/opt/nvm/nvm.sh" # This loads nvm
  # shellcheck source=/dev/null
  [[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ]] && . "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" # This loads nvm bash_completion
elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
  NVM_DIR="${HOME}"/.nvm
  # shellcheck source=/dev/null
  . "${NVM_DIR}/nvm.sh" # This loads nvm
  # shellcheck source=/dev/null
  . "${NVM_DIR}/bash_completion" # This loads nvm bash_completion
fi
export NVM_DIR
export PATH="${NVM_DIR}:${PATH}"