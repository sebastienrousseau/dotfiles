#!/usr/bin/env sh
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450) - Configuration loader.

## 🅲🅾🅽🅵🅸🅶🆄🆁🅰🆃🅸🅾🅽🆂
for config in "$DOTFILES"/configurations/[!.#]*.sh; do
  # shellcheck source=/dev/null
  . "$config"
done
