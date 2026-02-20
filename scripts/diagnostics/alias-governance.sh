#!/usr/bin/env bash
# Alias governance checks:
# - duplicate alias names
# - risky overrides must be gated
# - no hardcoded /Users paths

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
manifest_script="$SCRIPT_DIR/aliases-manifest.sh"
deprecations_file="$SCRIPT_DIR/../dot/data/alias-deprecations.tsv"
policy="${DOTFILES_ALIAS_POLICY:-standard}"
if [[ -n "${CI:-}" && "${DOTFILES_ALIAS_POLICY:-}" == "" ]]; then
  policy="strict"
fi

if [[ ! -x "$manifest_script" ]]; then
  echo "ERROR: aliases-manifest.sh not found or not executable" >&2
  exit 1
fi

tmp_manifest="$(mktemp)"
trap 'rm -f "$tmp_manifest"' EXIT

bash "$manifest_script" >"$tmp_manifest"

errors=0

echo "Alias Governance"
echo ""
echo "Policy: $policy"
echo ""

version_ge() {
  local a="${1#v}" b="${2#v}"
  local IFS=.
  local i
  read -r -a av <<<"$a"
  read -r -a bv <<<"$b"
  for i in 0 1 2; do
    local ai="${av[$i]:-0}"
    local bi="${bv[$i]:-0}"
    ((10#$ai > 10#$bi)) && return 0
    ((10#$ai < 10#$bi)) && return 1
  done
  return 0
}

repo_version="0.0.0"
if [[ -f "$SCRIPT_DIR/../../package.json" ]]; then
  repo_version="$(sed -n 's/^[[:space:]]*"version"[[:space:]]*:[[:space:]]*"\([0-9][0-9.]*\)".*/\1/p' "$SCRIPT_DIR/../../package.json" | head -1)"
fi
repo_version="${repo_version:-0.0.0}"

# 1) Duplicate alias names
dupes="$(awk -F'\t' '{count[$1]++} END {for (k in count) if (count[k] > 1) print k}' "$tmp_manifest" | sort)"
if [[ -n "$dupes" ]]; then
  if [[ "$policy" == "strict" ]]; then
    echo "ERROR: duplicate alias names detected:"
    printf "%s\n" "$dupes" | sed 's/^/  - /'
    errors=$((errors + 1))
  else
    echo "WARN: duplicate alias names detected (review recommended):"
    printf "%s\n" "$dupes" | sed 's/^/  - /'
  fi
else
  echo "OK: no duplicate alias names"
fi

# 2) Risky overrides must be gated
while IFS=$'\t' read -r name _value file _line; do
  case "$name" in
  cd | sudo | su | cp | mv | rm | mkdir | alias)
    # GNU coreutils aliases are intentionally centralized overrides.
    if [[ "$file" == *"/aliases/gnu/"* ]]; then
      continue
    fi
    if ! rg -q 'DOTFILES_(ENABLE|SAFE|ALIAS)' "$file"; then
      echo "ERROR: risky override '$name' in $file is not gated by a DOTFILES_* flag"
      errors=$((errors + 1))
    fi
    ;;
  esac
done <"$tmp_manifest"

if [[ $errors -eq 0 ]]; then
  echo "OK: risky overrides are gated"
fi

# 3) Hardcoded /Users path check (alias value only)
hardcoded="$(awk -F'\t' '$2 ~ /\/Users\// {print $1 "\t" $2 "\t" $3 ":" $4}' "$tmp_manifest")"
if [[ -n "$hardcoded" ]]; then
  echo "ERROR: hardcoded /Users paths detected in aliases:"
  printf "%s\n" "$hardcoded" | sed 's/^/  - /'
  errors=$((errors + 1))
else
  echo "OK: no hardcoded /Users paths in aliases"
fi

# 4) Deprecation window enforcement
if [[ -f "$deprecations_file" ]]; then
  expired_hits=0
  while IFS=$'\t' read -r alias_name replacement remove_in note; do
    [[ -z "${alias_name:-}" ]] && continue
    [[ "${alias_name:0:1}" == "#" ]] && continue
    if version_ge "$repo_version" "$remove_in"; then
      alias_found=0
      if awk -F'\t' -v n="$alias_name" '$1==n{found=1} END{exit(found?0:1)}' "$tmp_manifest"; then
        alias_found=1
      fi
      function_found=0
      if rg -q --glob '*.sh' --glob '*.aliases.sh' --glob '*.tmpl' "^[[:space:]]*(function[[:space:]]+)?${alias_name}[[:space:]]*\\(\\)" "$SCRIPT_DIR/../../.chezmoitemplates/aliases" "$SCRIPT_DIR/../../scripts/dot"; then
        function_found=1
      fi
      if [[ $alias_found -eq 1 || $function_found -eq 1 ]]; then
        [[ $expired_hits -eq 0 ]] && echo "ERROR: expired deprecated aliases still present:"
        echo "  - $alias_name (remove_in=$remove_in, replacement=$replacement)"
        expired_hits=$((expired_hits + 1))
      fi
    fi
  done <"$deprecations_file"
  if [[ $expired_hits -gt 0 ]]; then
    errors=$((errors + 1))
  else
    echo "OK: no expired deprecated aliases (repo version: v$repo_version)"
  fi
fi

echo ""
if [[ $errors -eq 0 ]]; then
  echo "Alias governance checks passed."
  exit 0
fi

echo "Alias governance checks failed: $errors issue(s)." >&2
exit 1
