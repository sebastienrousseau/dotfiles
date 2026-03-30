#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TRACE_DOC="$REPO_ROOT/docs/operations/TRACEABILITY.md"

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

check_path_list() {
  local kind="$1"
  local value="$2"
  local behavior_id="$3"
  local failed=0
  local rel=""

  while IFS= read -r rel; do
    rel="$(printf '%s' "$rel" | trim)"
    [ -n "$rel" ] || continue
    rel="${rel#\`}"
    rel="${rel%\`}"
    if [ ! -e "$REPO_ROOT/$rel" ]; then
      printf 'Missing %s path for %s: %s\n' "$kind" "$behavior_id" "$rel" >&2
      failed=1
    fi
  done < <(printf '%s\n' "$value" | tr ',' '\n')

  return "$failed"
}

main() {
  local failed=0
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

        check_path_list "implementation" "$impls" "$behavior_id" || failed=1
        check_path_list "test" "$tests" "$behavior_id" || failed=1
        check_path_list "doc" "$docs" "$behavior_id" || failed=1
        ;;
    esac
  done < "$TRACE_DOC"

  while IFS= read -r required; do
    [ -n "$required" ] || continue
    if ! extract_impl_paths | grep -Fxq "$required"; then
      printf 'Missing traceability row for implementation: %s\n' "$required" >&2
      failed=1
    fi
  done < <(
    {
      find "$REPO_ROOT/scripts/dot/commands" -maxdepth 1 -type f -name '*.sh' | sed "s#^$REPO_ROOT/##"
      find "$REPO_ROOT/scripts/qa" -maxdepth 1 -type f -name '*.sh' | sed "s#^$REPO_ROOT/##"
    } | sort -u
  )

  if [ "$failed" -ne 0 ]; then
    return 1
  fi

  printf 'PASS: core internal behaviors have implementation, test, and documentation traceability\n'
}

main "$@"
