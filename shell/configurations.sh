#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.451) - Loading configurations.

## 🅲🅾🅽🅵🅸🅶🆄🆁🅰🆃🅸🅾🅽🆂
for config in "${DOTFILES}"/configurations/[!.#]*/*.sh; do
  # shellcheck source=/dev/null
  . "${config}"
done
