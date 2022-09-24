#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450) - Loading functions.

# Load custom executable functions
for function in "$DOTFILES"/functions/[!.#]*.bash; do
  # shellcheck source=/dev/null
  . "$function"
done
