#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TRACE_DOC="$REPO_ROOT/docs/operations/TRACEABILITY.md"
MIN_TRACEABILITY_COVERAGE="${MIN_TRACEABILITY_COVERAGE:-100}"

TOTAL_TRACE_CHECKS=0
COVERED_TRACE_CHECKS=0

extract_impl_paths() {
  awk '
    /^\| BT-/ {
      cols = $0
      sub(/^\|[[:space:]]*/, "", cols)
      sub(/[[:space:]]*\|[[:space:]]*$/, "", cols)
      n = split(cols, parts, /\|/)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", parts[3])
      split(parts[3], impls, /,/)
      for (i in impls) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", impls[i])
        gsub(/`/, "", impls[i])
        print impls[i]
      }
    }
  ' "$TRACE_DOC" | sort -u
}

trim() {
  sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

record_trace_check() {
  local label="$1"
  local target="$2"

  TOTAL_TRACE_CHECKS=$((TOTAL_TRACE_CHECKS + 1))
  if [ -e "$target" ]; then
    COVERED_TRACE_CHECKS=$((COVERED_TRACE_CHECKS + 1))
  else
    printf 'Missing traceability target: %s (%s)\n' "$label" "$target" >&2
  fi
}

check_path_list() {
  local kind="$1"
  local value="$2"
  local behavior_id="$3"
  local rel=""

  while IFS= read -r rel; do
    rel="$(printf '%s' "$rel" | trim)"
    [ -n "$rel" ] || continue
    rel="${rel#\`}"
    rel="${rel%\`}"
    record_trace_check "$behavior_id $kind" "$REPO_ROOT/$rel"
  done < <(printf '%s\n' "$value" | tr ',' '\n')
}

report_traceability() {
  local pct
  pct="$(awk -v c="$COVERED_TRACE_CHECKS" -v t="$TOTAL_TRACE_CHECKS" 'BEGIN{if(t==0){print "0.00"}else{printf "%.2f", (100*c/t)}}')"

  printf 'Traceability coverage: %s/%s (%s%%)\n' "$COVERED_TRACE_CHECKS" "$TOTAL_TRACE_CHECKS" "$pct"
  printf 'Threshold: %s%%\n' "$MIN_TRACEABILITY_COVERAGE"

  awk -v p="$pct" -v min="$MIN_TRACEABILITY_COVERAGE" 'BEGIN{exit !(p+0 >= min+0)}'
}

main() {
  local line=""
  local cols=""
  local behavior_id=""
  local impls=""
  local tests=""
  local docs=""

  while IFS= read -r line; do
    case "$line" in
      \|\ BT-*)
        cols="$(printf '%s\n' "$line" | sed 's/^|//; s/|$//')"
        behavior_id="$(printf '%s\n' "$cols" | cut -d'|' -f1 | trim)"
        impls="$(printf '%s\n' "$cols" | cut -d'|' -f3 | trim)"
        tests="$(printf '%s\n' "$cols" | cut -d'|' -f4 | trim)"
        docs="$(printf '%s\n' "$cols" | cut -d'|' -f5 | trim)"

        check_path_list "implementation" "$impls" "$behavior_id"
        check_path_list "test" "$tests" "$behavior_id"
        check_path_list "doc" "$docs" "$behavior_id"
        ;;
    esac
  done < "$TRACE_DOC"

  while IFS= read -r required; do
    [ -n "$required" ] || continue
    TOTAL_TRACE_CHECKS=$((TOTAL_TRACE_CHECKS + 1))
    if extract_impl_paths | grep -Fxq "$required"; then
      COVERED_TRACE_CHECKS=$((COVERED_TRACE_CHECKS + 1))
    else
      printf 'Missing traceability row for implementation: %s\n' "$required" >&2
    fi
  done < <(
    {
      find "$REPO_ROOT/scripts/dot/commands" -maxdepth 1 -type f -name '*.sh' | sed "s#^$REPO_ROOT/##"
      find "$REPO_ROOT/scripts/qa" -maxdepth 1 -type f -name '*.sh' | sed "s#^$REPO_ROOT/##"
    } | sort -u
  )

  report_traceability

  printf 'PASS: core internal behaviors have implementation, test, and documentation traceability at or above the required threshold\n'
}

main "$@"
