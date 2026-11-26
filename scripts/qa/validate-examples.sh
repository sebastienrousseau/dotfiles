#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
EXAMPLES_DIR="$REPO_ROOT/examples"
# shellcheck source-path=SCRIPTDIR source=../../lib/dot/probe.sh
source "$REPO_ROOT/lib/dot/probe.sh" # dot_bounded

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

# resolve_timeout_cmd: set timeout_cmd to the prefix that bounds one example,
# or to nothing when EXAMPLE_TIMEOUT=0. GNU coreutils ships `timeout`; on
# macOS it is `gtimeout` when coreutils is installed. Without either, as on
# macOS before 27, dot_bounded keeps the budget (it used to run unbounded).
resolve_timeout_cmd() {
  timeout_cmd=()
  [ "$EXAMPLE_TIMEOUT" != "0" ] || return 0
  if command -v timeout >/dev/null 2>&1; then
    timeout_cmd=(timeout --kill-after=5 "$EXAMPLE_TIMEOUT")
  elif command -v gtimeout >/dev/null 2>&1; then
    timeout_cmd=(gtimeout --kill-after=5 "$EXAMPLE_TIMEOUT")
  else
    timeout_cmd=(dot_bounded "$EXAMPLE_TIMEOUT")
  fi
}
resolve_timeout_cmd

# run_example FILE: run one example within its budget; count it in `failed`
# when it times out or exits non-zero.
run_example() {
  local name rc=0
  name="$(basename "$1")"
  printf 'Running example: %s\n' "$name"
  "${timeout_cmd[@]+"${timeout_cmd[@]}"}" bash "$1" </dev/null || rc=$?
  if [ "$rc" -eq 124 ]; then
    printf 'FAIL: %s exceeded the %ss timeout\n' "$name" "$EXAMPLE_TIMEOUT" >&2
  elif [ "$rc" -ne 0 ]; then
    printf 'FAIL: %s exited %s\n' "$name" "$rc" >&2
  fi
  [ "$rc" -eq 0 ] || failed=$((failed + 1))
}

found=0
failed=0
while IFS= read -r -d '' example; do
  found=1
  run_example "$example"
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
