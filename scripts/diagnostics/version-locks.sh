#!/usr/bin/env bash
# Version Locks Summary
# Usage: dot locks

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"

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

ui_header "Version Locks"

ui_section "mise toolchain"
mise_config="$src_dir/dot_config/mise/config.toml"
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
if [[ -f "$src_dir/dot_node-version" ]]; then
  ui_kv "node" "$(cat "$src_dir/dot_node-version")"
fi
if [[ -f "$src_dir/dot_noderc.tmpl" ]]; then
  ui_kv "noderc" "$(sed -n '1p' "$src_dir/dot_noderc.tmpl")"
fi

ui_section "Package manager locks"
if [[ -f "$src_dir/dot_config/shell/Brewfile" ]]; then
  ui_kv "brew" "Brewfile present"
fi
if [[ -f "$src_dir/dot_config/shell/Brewfile.cli" ]]; then
  ui_kv "brew-cli" "Brewfile.cli present"
fi
if [[ -f "$src_dir/package.json" ]]; then
  ui_kv "node" "package.json version pinned"
fi

ui_section "Notes"
ui_info "Policy" "Prefer LTS and explicit pins for core runtimes"
ui_info "Update" "Edit ~/.config/mise/config.toml to adjust pins"
