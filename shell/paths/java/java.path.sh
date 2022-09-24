#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450) - Java Path configuration.

## 🅹🅰🆅🅰_🅷🅾🅼🅴
# Set JAVA_HOME
if [[ "$OSTYPE" == "darwin"* ]]; then
  export CPPFLAGS="-I/opt/homebrew/opt/openjdk/include"
  export PATH=/opt/homebrew/opt/openjdk/bin:"$PATH" # Java binaries
  JAVA_HOME="$(brew --prefix)/Cellar/openjdk/18.0.2.1_1/libexec"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  JAVA_HOME="/usr/lib/jvm/java-11-openjdk-arm64/bin/java"
fi
export JAVA_HOME
export JRE_HOME="${JAVA_HOME}"/jre
