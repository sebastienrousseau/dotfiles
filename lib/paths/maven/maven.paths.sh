#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.469) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# License: MIT

## 🅼🅰🆅🅴🅽 🅷🅾🅼🅴
if [[ "${OSTYPE}" == "darwin"* ]]; then
  export M2_HOME=/opt/homebrew/Cellar/maven/3.9.0/libexec
  export PATH=${PATH}:${M2_HOME}/bin
  MAVEN_HOME=/opt/homebrew/Cellar/maven/3.9.0/libexec
elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
  MAVEN_HOME="/usr/share/maven/"
fi
export MAVEN_HOME
export PATH="${MAVEN_HOME}:${PATH}"
export MAVEN_OPTS="-Xms1g -Xmx1g"
