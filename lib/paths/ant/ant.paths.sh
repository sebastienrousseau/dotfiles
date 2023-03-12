#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.463) - https://dotfiles.io
# Made with ♥ in London, UK by @sebastienrousseau
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

## 🅰🅽🆃 🅷🅾🅼🅴
if [[ -z "${ANT_HOME}" ]]; then
  if [[ "${OSTYPE}" == "darwin"* ]]; then
    ANT_HOME="/usr/local/opt/ant"
  elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
    ANT_HOME="/usr/share/ant/"
  fi
  export ANT_HOME
  export PATH="${ANT_HOME}/bin:${PATH}"
fi
