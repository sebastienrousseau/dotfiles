#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.451) - MAVEN Path configuration.

## 🅼🅰🆅🅴🅽 🅷🅾🅼🅴
if [[ -z "${MAVEN_HOME}" ]]; then
  if [[ "${OSTYPE}" == "darwin"* ]]; then
    MAVEN_HOME="$(brew --prefix)/Cellar/maven/$(mvn -v)/libexec"
  elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
    MAVEN_HOME="/usr/share/maven/"
  fi
  M2_HOME="${MAVEN_HOME}"
  export MAVEN_HOME M2_HOME
  export PATH="${MAVEN_HOME}:${PATH}"
fi
