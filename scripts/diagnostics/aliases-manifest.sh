#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Emit alias manifest as TSV:
# name<TAB>value<TAB>file<TAB>line

set -euo pipefail

resolve_source_dir() {
  if [[ -n "${CHEZMOI_SOURCE_DIR:-}" && -d "${CHEZMOI_SOURCE_DIR}" ]]; then
    printf "%s\n" "${CHEZMOI_SOURCE_DIR}"
    return
  fi
  if [[ -d "$HOME/.dotfiles" ]]; then
    printf "%s\n" "$HOME/.dotfiles"
    return
  fi
  if [[ -d "$HOME/.local/share/chezmoi" ]]; then
    printf "%s\n" "$HOME/.local/share/chezmoi"
    return
  fi
  return 1
}

# Descend into the chezmoi source subdir (per `.chezmoiroot`) if
# present — post-Phase-4b (v0.2.503) the aliases + functions trees
# live under `defaults/.chezmoitemplates/`, not at the repo root.
# See `resolve_chezmoi_source_dir` in lib/dot/utils.sh.
resolve_chezmoi_source_dir() {
  local root="$1"
  if [[ -f "$root/.chezmoiroot" ]]; then
    local sub
    sub="$(head -1 "$root/.chezmoiroot" | tr -d '[:space:]')"
    if [[ -n "$sub" && -d "$root/$sub" ]]; then
      printf "%s\n" "$root/$sub"
      return
    fi
  fi
  printf "%s\n" "$root"
}

src_root="${1:-$(resolve_source_dir)}"
src_dir="$(resolve_chezmoi_source_dir "$src_root")"

rg -n \
  -e '^[[:space:]]*alias[[:space:]]+[A-Za-z0-9_.:-]+=' \
  -e '^[[:space:]]*[^#"'\'']*&&[[:space:]]*alias[[:space:]]+[A-Za-z0-9_.:-]+=' \
  "$src_dir/.chezmoitemplates/aliases" \
  "$src_dir/.chezmoitemplates/functions" |
  sed -E 's#^([^:]+):([0-9]+):.*alias[[:space:]]+([A-Za-z0-9_.:-]+)=(.*)$#\3\t\4\t\1\t\2#'
