#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450) - NVM Path configuration.

## 🅽🆅🅼 🅿🅰🆃🅷
if [ -z "$NVM_DIR" ]; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    NVM_DIR="$HOME"/.nvm
    # shellcheck source=/dev/null
    [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && . "/opt/homebrew/opt/nvm/nvm.sh" # This loads nvm
    # shellcheck source=/dev/null
    [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && . "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" # This loads nvm bash_completion

  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    NVM_DIR="$HOME"/.nvm
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" # This loads nvm
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion" # This loads nvm bash_completion
  fi
  export NVM_DIR
  export PATH="$NVM_DIR:$PATH"
fi