#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.452) - https://dotfiles.io
# Copyright (c) Sebastien Rousseau 2022. All rights reserved
# License: MIT

## 🅹🅰🆅🅰_🅷🅾🅼🅴
# Set JAVA_HOME
if [[ "${OSTYPE}" == "darwin"* ]]; then
  export CPPFLAGS="-I/opt/homebrew/opt/openjdk/include"
  export PATH=/opt/homebrew/opt/openjdk/bin:"${PATH}" # Java binaries
  JAVA_HOME="/opt/homebrew/Cellar/openjdk/$(java -version 2>&1 | head -n 1 | cut -d'"' -f2)/libexec/openjdk.jdk/Contents/Home"
elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
  JAVA_HOME="/usr/lib/jvm/java-11-openjdk-arm64/"
fi
export JAVA_HOME
export JRE_HOME="${JAVA_HOME}"/jre
