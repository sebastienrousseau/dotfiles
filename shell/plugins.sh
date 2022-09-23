#! /bin/bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450)

# Load custom executable plugins
for plugins in "$DOTFILES"/plugins/[!.#]*/*.sh; do
    # shellcheck source=/dev/null
    . "$plugins"
done
