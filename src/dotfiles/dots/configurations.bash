#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450) - Configuration loader.

## 🅲🅾🅽🅵🅸🅶🆄🆁🅰🆃🅸🅾🅽🆂
for config in "$DF_HOME"/configurations/[^.#]*.bash; do
  # shellcheck source=/dev/null
  source "$config"
done
