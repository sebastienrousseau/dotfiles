#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.456) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🅼🅰🆅🅴🅽 🅷🅾🅼🅴
if [[ -z "${MAVEN_HOME}" ]]; then
  if [[ "${OSTYPE}" == "darwin"* ]]; then
    MAVEN_HOME=/opt/homebrew/Cellar/maven/3.8.6/libexec
  elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
    MAVEN_HOME="/usr/share/maven/"
  fi
  M2_HOME="${MAVEN_HOME}"
  export MAVEN_HOME M2_HOME
  export PATH="${MAVEN_HOME}:${PATH}"
  export MAVEN_OPTS="-Xms1g -Xmx1g"
fi
