#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
EXAMPLES_DIR="$REPO_ROOT/examples"

# Per-example wall-clock budget. Bounding each example individually means one
# slow or hanging example is reported by name instead of silently consuming the
# whole script's budget and surfacing as an opaque rc=124 from the caller.
EXAMPLE_TIMEOUT="${EXAMPLE_TIMEOUT:-60}"

usage() {
  cat <<'USAGE'
Usage: validate-examples.sh [--help]

Runs every executable example in examples/ and fails if any of them fails or
exceeds the per-example timeout.

Environment:
  EXAMPLE_TIMEOUT   Per-example timeout in seconds (default: 60). Set to 0 to
                    disable the timeout.
USAGE
}

# Parse arguments before doing any work. Previously this script ignored its
# arguments entirely, so `--help` silently executed the whole examples suite —
# which meant asking for help ran a multi-minute job.
case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
  "") ;;
  *)
    printf 'Unknown option: %s\n\n' "$1" >&2
    usage >&2
    exit 2
    ;;
esac

if [ ! -d "$EXAMPLES_DIR" ]; then
  echo "No examples directory found: $EXAMPLES_DIR" >&2
  exit 1
fi

# Resolve a timeout binary. GNU coreutils ships `timeout`; on macOS it is
# `gtimeout` when coreutils is installed. Without either, run unbounded rather
# than failing outright.
timeout_cmd=()
if [ "$EXAMPLE_TIMEOUT" != "0" ]; then
  if command -v timeout >/dev/null 2>&1; then
    timeout_cmd=(timeout --kill-after=5 "$EXAMPLE_TIMEOUT")
  elif command -v gtimeout >/dev/null 2>&1; then
    timeout_cmd=(gtimeout --kill-after=5 "$EXAMPLE_TIMEOUT")
  else
    printf 'warning: no timeout binary found; examples run unbounded\n' >&2
  fi
fi

found=0
failed=0
while IFS= read -r -d '' example; do
  found=1
  name="$(basename "$example")"
  printf 'Running example: %s\n' "$name"
  rc=0
  "${timeout_cmd[@]+"${timeout_cmd[@]}"}" bash "$example" </dev/null || rc=$?
  if [ "$rc" -eq 124 ]; then
    printf 'FAIL: %s exceeded the %ss timeout\n' "$name" "$EXAMPLE_TIMEOUT" >&2
    failed=$((failed + 1))
  elif [ "$rc" -ne 0 ]; then
    printf 'FAIL: %s exited %s\n' "$name" "$rc" >&2
    failed=$((failed + 1))
  fi
done < <(find "$EXAMPLES_DIR" -maxdepth 1 -type f -name "*.sh" -print0 | sort -z)

if [ "$found" -eq 0 ]; then
  echo "No executable examples found in $EXAMPLES_DIR" >&2
  exit 1
fi

if [ "$failed" -ne 0 ]; then
  printf '%s example(s) failed.\n' "$failed" >&2
  exit 1
fi

printf 'Examples passed.\n'
