#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450) - Homebrew Path configuration.

## 🅷🅾🅼🅴🅱🆁🅴🆆 🅿🅰🆃🅷🆂
if [[ "$OSTYPE" == "darwin"* ]]; then

  ### Uniquify 'PATH' entries.
  typeset -U PATH

  export PATH=/opt/homebrew/bin:"$PATH"      # Homebrew binaries
  export PATH=/opt/homebrew/sbin:"$PATH"     # Homebrew binaries
  export PATH=/opt/homebrew/bin/bash:"$PATH" # Add /opt/homebrew/bin/bash to the path

  # Prevent Homebrew from reporting - https://github.com/Homebrew/brew/blob/master/share/doc/homebrew/Analytics.md
  export HOMEBREW_NO_ANALYTICS=1

  # set HOMEBREW_CASK_OPTS
  HOMEBREW_CASK_OPTS="--appdir=/Applications"
  export HOMEBREW_CASK_OPTS
fi
