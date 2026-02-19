#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="$(dirname "$(dirname "$TESTS_DIR")")"

MIN_COVERAGE="${MIN_COVERAGE:-95}"

mapfile -t modules < <(
  while IFS= read -r file; do
    rel="${file#"$REPO_ROOT/scripts/"}"
    rel="${rel%.sh}"
    printf "%s\n" "$rel"
  done < <(find "$REPO_ROOT/scripts" -type f -name "*.sh" ! -path "$REPO_ROOT/scripts/tests/*")
)

total=0
covered=0
missing=()

for m in "${modules[@]}"; do
  [[ -z "$m" ]] && continue
  total=$((total + 1))

  base="$(basename "$m")"
  flat="${m//\//_}"
  flat="${flat//-/_}"
  base_u="${base//-/_}"

  if command -v rg >/dev/null 2>&1; then
    matcher=(rg -q "${base}|${base_u}|${flat}|test_.*${base}" "$TESTS_DIR/unit" -g "test_*.sh")
  else
    matcher=(grep -R -E -q "${base}|${base_u}|${flat}|test_.*${base}" "$TESTS_DIR/unit")
  fi

  if "${matcher[@]}"; then
    covered=$((covered + 1))
  else
    missing+=("$m")
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
