#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.452) - Loading paths.

## 🅿🅰🆃🅷🆂

# Load custom executable paths.
for file in "${DOTFILES}"/paths/[!.#]*/*.sh; do
  # shellcheck source=/dev/null
  source "${file}"
done
