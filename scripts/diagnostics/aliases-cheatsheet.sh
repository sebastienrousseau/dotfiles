#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/utils.sh
source "$SCRIPT_DIR/../dot/lib/utils.sh"

src_dir="$(require_source_dir)"
manifest="$src_dir/scripts/diagnostics/aliases-manifest.sh"
if [[ ! -x "$manifest" ]]; then
  echo "Alias manifest not found: $manifest" >&2
  exit 1
fi

cat <<'HEADER'
# Alias Cheatsheet

Auto-generated from alias manifest.

## Core shortcuts
HEADER

# Core list we care about (preserve ordering).
core_aliases=(c q e h _ i l ll la lr lra lt lta a d)

tmp_manifest="$(mktemp)"
trap 'rm -f "$tmp_manifest"' EXIT
bash "$manifest" > "$tmp_manifest"

pick_alias() {
  local name="$1"
  shift
  local value=""
  local pattern
  while [[ $# -gt 0 ]]; do
    pattern="$1"
    value="$(awk -F$'\t' -v key="$name" -v pat="$pattern" '$1==key && $3 ~ pat {print $2; exit}' "$tmp_manifest")"
    [[ -n "$value" ]] && { printf '%s\n' "$value"; return 0; }
    shift
  done
  value="$(awk -F$'\t' -v key="$name" '$1==key {print $2; exit}' "$tmp_manifest")"
  [[ -n "$value" ]] && printf '%s\n' "$value"
}

for a in "${core_aliases[@]}"; do
  case "$a" in
    a)
      line="$(pick_alias "$a" "/ai/")"
      ;;
    d)
      line="$(pick_alias "$a" "/system/" "/configuration/" "/docker/")"
      ;;
    *)
      line="$(pick_alias "$a")"
      ;;
  esac
  if [[ -n "$line" ]]; then
    printf '%s\n' "- \`$a\` $line"
  fi
done

cat <<'FOOTER'

## Notes

- Regenerate: `dot aliases cheatsheet`
- Apply changes: `chezmoi apply`
FOOTER
