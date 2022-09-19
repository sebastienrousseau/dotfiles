#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450)

# Load custom executable plugins
for plugins in "$DF_HOME"/plugins/[^.#]*/*.sh; do
    # shellcheck source=/dev/null
    source "$plugins"
done
