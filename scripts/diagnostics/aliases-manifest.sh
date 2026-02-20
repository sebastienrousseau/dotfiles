#!/usr/bin/env bash
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

src_dir="${1:-$(resolve_source_dir)}"

rg -n \
  -e '^[[:space:]]*alias[[:space:]]+[A-Za-z0-9_.:-]+=' \
  -e '^[[:space:]]*[^#"'\'']*&&[[:space:]]*alias[[:space:]]+[A-Za-z0-9_.:-]+=' \
  "$src_dir/.chezmoitemplates/aliases" \
  "$src_dir/.chezmoitemplates/functions" \
  | sed -E 's#^([^:]+):([0-9]+):.*alias[[:space:]]+([A-Za-z0-9_.:-]+)=(.*)$#\3\t\4\t\1\t\2#'
