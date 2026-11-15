#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# Removes tools the dotfiles no longer ship from mise's global config.
# `dot ai install` registers each AI tool with `mise use -g`, which writes
# it into ~/.config/mise/config.toml: a file chezmoi does not manage, so a
# tool that leaves the roster stays declared there. When its installer is
# gone too (kiro-cli's mise plugin, removed in 0.2.544), every
# `mise install` and `dot upgrade` fails on it. Each entry below is a tool
# the dotfiles retired; a declaration of it is unregistered with
# `mise unuse -g --no-prune` (the installed files stay). It never stops the
# apply. defaults/run_onchange_after_33-retire-mise-tools.sh.tmpl runs it.

set -euo pipefail

# tool|release that retired it
RETIRED=(
  "kiro-cli|0.2.544"
)

cfg="${MISE_GLOBAL_CONFIG_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/mise/config.toml}"
[[ -f "$cfg" ]] || exit 0
command -v mise >/dev/null 2>&1 || exit 0

for entry in "${RETIRED[@]}"; do
  tool="${entry%%|*}"
  release="${entry#*|}"
  # A key as mise writes it: bare or quoted, at the start of a line.
  grep -Eq "^[[:space:]]*\"?${tool}\"?[[:space:]]*=" "$cfg" || continue
  if MISE_GLOBAL_CONFIG_FILE="$cfg" mise unuse -g --no-prune "$tool" >/dev/null 2>&1; then
    echo "dot: removed ${tool} from ${cfg}: the dotfiles dropped it in ${release}"
  else
    echo "dot: could not remove ${tool} from ${cfg}; delete its line by hand (dropped in ${release})" >&2
  fi
done
exit 0
