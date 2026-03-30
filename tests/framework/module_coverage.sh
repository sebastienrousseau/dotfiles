#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="${TESTS_DIR:-$(dirname "$SCRIPT_DIR")}"
REPO_ROOT="${REPO_ROOT:-$(dirname "$TESTS_DIR")}"

MIN_COVERAGE="${MIN_COVERAGE:-95}"

escape_regex() {
  printf '%s' "$1" | sed 's/[][(){}.^$*+?|\\/]/\\&/g'
}

modules=()

while IFS= read -r file; do
  rel="${file#"$REPO_ROOT/scripts/"}"
  rel="${rel%.sh}"
  modules+=("scripts:$rel")
done < <(find "$REPO_ROOT/scripts" -type f -name "*.sh" ! -path "$REPO_ROOT/scripts/tests/*")

while IFS= read -r file; do
  rel="${file#"$REPO_ROOT/.chezmoitemplates/functions/"}"
  rel="${rel%.sh}"
  modules+=("functions:$rel")
done < <(find "$REPO_ROOT/.chezmoitemplates/functions" -type f -name "*.sh")

while IFS= read -r file; do
  rel="${file#"$REPO_ROOT/dot_local/bin/"}"
  rel="${rel#executable_}"
  modules+=("bin:$rel")
done < <(find "$REPO_ROOT/dot_local/bin" -maxdepth 1 -type f -name "executable_*")

total=0
covered=0
missing=()

for m in "${modules[@]}"; do
  [[ -z "$m" ]] && continue
  total=$((total + 1))

  area="${m%%:*}"
  path_part="${m#*:}"

  base="$(basename "$path_part")"
  flat="${path_part//\//_}"
  flat="${flat//-/_}"
  base_u="${base//-/_}"
  area_path="${area}_${flat}"
  escaped_flat="$(escape_regex "$flat")"
  escaped_base_u="$(escape_regex "$base_u")"
  escaped_area_path="$(escape_regex "$area_path")"
  escaped_module="$(escape_regex "$path_part")"

  if command -v rg >/dev/null 2>&1; then
    matcher=(rg -q -e "(^|[^A-Za-z0-9_])${escaped_flat}([^A-Za-z0-9_]|$)" \
      -e "(^|[^A-Za-z0-9_])${escaped_base_u}([^A-Za-z0-9_]|$)" \
      -e "(^|[^A-Za-z0-9_])${escaped_area_path}([^A-Za-z0-9_]|$)" \
      -e "${escaped_module}" \
      "$TESTS_DIR/unit" -g "test_*.sh")
  else
    matcher=(grep -R -E -q "(^|[^A-Za-z0-9_])${escaped_flat}([^A-Za-z0-9_]|$)|(^|[^A-Za-z0-9_])${escaped_base_u}([^A-Za-z0-9_]|$)|(^|[^A-Za-z0-9_])${escaped_area_path}([^A-Za-z0-9_]|$)|${escaped_module}" "$TESTS_DIR/unit")
  fi

  if "${matcher[@]}"; then
    covered=$((covered + 1))
  else
    missing+=("${area}/${path_part}")
  fi
done

pct="$(awk -v c="$covered" -v t="$total" 'BEGIN{if(t==0){print "0.00"}else{printf "%.2f", (100*c/t)}}')"

echo "Module coverage: ${covered}/${total} (${pct}%)"
echo "Threshold: ${MIN_COVERAGE}%"

if ((${#missing[@]} > 0)); then
  echo "Uncovered modules:"
  printf "  - %s\n" "${missing[@]}"
fi

awk -v p="$pct" -v min="$MIN_COVERAGE" 'BEGIN{exit !(p+0 >= min+0)}'
