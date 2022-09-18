#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450)

## 🅲🅾🅽🅵🅸🅶🆄🆁🅰🆃🅸🅾🅽🆂
for config in "$DF_HOME"/configurations/[^.#]*.zsh; do
  # shellcheck source=/dev/null
  source "$config"
done
