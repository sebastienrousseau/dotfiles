#!/usr/bin/env bash
# Alias/Command Conflicts Report
# Usage: dot conflicts

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
manifest="$src_dir/scripts/diagnostics/aliases-manifest.sh"
if [[ ! -x "$manifest" ]]; then
  ui_err "Alias manifest" "not found"
  exit 1
fi

tmp_manifest=$(mktemp)
trap 'rm -f "$tmp_manifest"' EXIT
bash "$manifest" >"$tmp_manifest"

ui_header "Alias & Command Conflicts"

ui_section "Duplicate alias definitions"

dupes=$(awk -F$'\t' '{print $1}' "$tmp_manifest" | sort | uniq -d)
if [[ -z "$dupes" ]]; then
  ui_ok "Aliases" "No duplicate alias names"
else
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    ui_warn "Alias" "${name} defined multiple times"
    awk -F$'\t' -v k="$name" '$1==k {printf "  - %s (%s:%s)\n", $2, $3, $4}' "$tmp_manifest"
  done <<<"$dupes"
fi

ui_section "Alias shadows real commands"
shadow_found=false
while IFS=$'\t' read -r name value line; do
  if command -v "$name" >/dev/null 2>&1; then
    shadow_found=true
    ui_warn "Shadow" "${name} -> ${value} (also command)"
  fi
done <"$tmp_manifest"

if ! $shadow_found; then
  ui_ok "Shadowing" "No alias shadows detected"
fi

ui_section "Quick actions"
ui_info "List aliases" "dot aliases list"
ui_info "Regenerate cheatsheet" "dot aliases cheatsheet"
