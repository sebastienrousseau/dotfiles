#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.452) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🆁🆄🅱🆈 🅷🅾🅼🅴
if [[ -z "${RUBY_HOME}" ]]; then
  if [[ "${OSTYPE}" == "darwin"* ]]; then
    if [[ -d "/opt/homebrew/opt/ruby/bin" ]]; then
      RUBY_HOME="/opt/homebrew/opt/ruby/bin"
    fi
  elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
    RUBY_HOME="/usr/lib/ruby/2.6.0/"
  fi
  export RUBY_HOME
  export PATH="${RUBY_HOME}:${PATH}"
fi

## 🅶🅴🅼 🅷🅾🅼🅴
if [[ -z "${GEM_HOME}" ]]; then
  if [[ "${OSTYPE}" == "darwin"* ]]; then
    if [[ -d "/opt/homebrew/opt/ruby/bin" ]]; then
      # shellcheck disable=SC2006
      GEM_HOME=$(gem environment gemdir)
      GEM_PATH=$(gem environment gemdir)
    fi
  elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
    GEM_HOME="/usr/lib/ruby/2.6.0/"
    GEM_PATH="/usr/lib/ruby/2.6.0/"
  fi
  export GEM_HOME
  export GEM_PATH
  export PATH="${GEM_PATH}:${PATH}"
  export PATH="${GEM_HOME}:${PATH}"
fi
