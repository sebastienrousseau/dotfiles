#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Version Locks Summary
# Usage: dot locks

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/dot/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../lib/dot/ui.sh"

ui_init

resolve_source_dir() {
  if [[ -n "${CHEZMOI_SOURCE_DIR:-}" && -d "$CHEZMOI_SOURCE_DIR" ]]; then
    printf "%s\n" "$CHEZMOI_SOURCE_DIR"
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

src_dir=$(resolve_source_dir)

# resolve_source_dir returns the repo root, but since the defaults/ reorg the
# deployable tree lives under the .chezmoiroot subdir (defaults/). Descend
# into it so paths like dot_config/... resolve. (Without this the mise lookup
# below silently reported "config not found" on every run.)
cm_src="$src_dir"
if [[ -f "$src_dir/.chezmoiroot" ]]; then
  _cm_root="$(tr -d '[:space:]' <"$src_dir/.chezmoiroot")"
  [[ -n "$_cm_root" && -d "$src_dir/$_cm_root" ]] && cm_src="$src_dir/$_cm_root"
fi

ui_header "Version Locks"

ui_section "mise toolchain"
mise_config="$cm_src/dot_config/mise/conf.d/00-dotfiles.toml"
if [[ -f "$mise_config" ]]; then
  awk -F= '
    /^\[tools\]/ {in_tools=1; next}
    /^\[/ {in_tools=0}
    in_tools && NF {
      gsub(/"/, "", $0)
      tool=$1
      gsub(/[[:space:]]+/, "", tool)
      ver=$2
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", ver)
      if (tool != "") {
        printf "%s\t%s\n", tool, ver
      }
    }
  ' "$mise_config" | while IFS=$'\t' read -r tool ver; do
    [[ -n "$tool" ]] && ui_kv "$tool" "$ver"
  done
else
  ui_warn "mise" "config not found"
fi

ui_section "Node/Python pins"
# Chezmoi-tracked files (dot_*) live under $cm_src (defaults/) post-
# Phase-4b, NOT at repo root. Using $src_dir here silently rendered
# an empty section on every workstation.
if [[ -f "$cm_src/dot_node-version" ]]; then
  ui_kv "node" "$(cat "$cm_src/dot_node-version")"
fi
if [[ -f "$cm_src/dot_noderc.tmpl" ]]; then
  ui_kv "noderc" "$(sed -n '1p' "$cm_src/dot_noderc.tmpl")"
fi

ui_section "Package manager locks"
if [[ -f "$cm_src/dot_config/shell/Brewfile" ]]; then
  ui_kv "brew" "Brewfile present"
fi
if [[ -f "$cm_src/dot_config/shell/Brewfile.cli" ]]; then
  ui_kv "brew-cli" "Brewfile.cli present"
fi
# package.json (if any) is a repo-root artefact — use $src_dir.
if [[ -f "$src_dir/package.json" ]]; then
  ui_kv "node" "package.json version pinned"
fi

ui_section "Notes"
ui_info "Policy" "Prefer LTS and explicit pins for core runtimes"
ui_info "Update" "Edit ~/.config/mise/config.toml to adjust pins"
