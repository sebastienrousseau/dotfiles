#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450) - Loading aliases.

## 🅰🅻🅸🅰🆂🅴🆂

# Load custom executable aliases
for file in "$DOTFILES"/aliases/[!.#]*/*.sh; do
  # shellcheck source=/dev/null
  source "$file"
done