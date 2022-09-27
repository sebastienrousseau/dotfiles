#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450) - Loading configurations.

## 🅲🅾🅽🅵🅸🅶🆄🆁🅰🆃🅸🅾🅽🆂
for config in "$DOTFILES"/configurations/*.sh; do
  # shellcheck source=/dev/null
  . "$config"
done
