#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Contract for lib/dot/log.sh dot_agent_checkpoint_create, found by mutation
# testing (mutant L2): every extra positional argument is captured in the
# checkpoint's `argv` array. The existing coverage passed two extras, so a
# guard mutated from `$# -gt 0` to `$# -gt 1` (silently dropping a lone
# argument) survived. Cases pin one extra, zero extras, and the existing
# two-extra shape. Every write lands in a mktemp XDG_STATE_HOME.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
# shellcheck source=../../framework/assertions.sh
source "$REPO_ROOT/tests/framework/assertions.sh"

LOG_LIB="$REPO_ROOT/lib/dot/log.sh"
REAL_BASH="${BASH:-$(command -v bash)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/log-argv.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP: jq not installed; argv is only captured in the jq form"
  echo ""
  echo "RESULTS:0:0:0"
  exit 0
fi

# checkpoint <id> <args...> — create a checkpoint in a fresh bash, print its path.
checkpoint() {
  local id="$1"
  shift
  XDG_STATE_HOME="$WORK/state" HOME="$WORK/home" DOT_TRACE_ID="trace42" \
    DOT_AGENT_CHECKPOINT_ID="$id" "$REAL_BASH" -c \
    'source "$0"; dot_agent_checkpoint_create "$@"' "$LOG_LIB" "$@" 2>&1
}

test_start "checkpoint_captures_a_single_extra_argument"
f="$(checkpoint one apply ready lone-arg)"
assert_file_exists "$f" "checkpoint written"
assert_equals '["lone-arg"]' "$(jq -c .argv "$f")" "one extra lands in argv (mutant L2: dropped)"

test_start "checkpoint_with_no_extra_arguments_has_empty_argv"
f="$(checkpoint zero apply ready)"
assert_file_exists "$f" "checkpoint written"
assert_equals '[]' "$(jq -c .argv "$f")" "argv is an empty array"

test_start "checkpoint_captures_every_extra_argument_in_order"
f="$(checkpoint two ask ready first "second word" third)"
assert_file_exists "$f" "checkpoint written"
assert_equals '["first","second word","third"]' "$(jq -c .argv "$f")" "all extras in order"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
