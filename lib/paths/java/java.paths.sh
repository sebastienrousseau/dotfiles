#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.466) - <https://dotfiles.io>
# Made with ♥ in London, UK by @wwdseb
# Copyright (c) 2015-2023. All rights reserved
# License: MIT

## 🅹🅰🆅🅰_🅷🅾🅼🅴
# Set JAVA_HOME
if [[ "${OSTYPE}" == "darwin"* ]]; then
  export CPPFLAGS="-I/opt/homebrew/opt/openjdk/include"
  export JAVA_HOME="/opt/homebrew/Cellar/openjdk@11/11.0.18/libexec/openjdk.jdk/Contents/Home"
  export PATH="/opt/homebrew/opt/openjdk@11/bin:$PATH"
elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
  JAVA_HOME="/usr/lib/jvm/java-11-openjdk-arm64/"

fi
export JAVA_HOME
export JRE_HOME="${JAVA_HOME}"/jre
