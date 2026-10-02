#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1091
# lib/dot/probe.sh: dot_probe <seconds> <command…> reports what happened
# through its exit code, so callers can tell "not installed" (127), "failed"
# (the command's own status) and "did not answer" (124) apart.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$REPO_ROOT/lib/dot/probe.sh"

probe_rc() {
  dot_probe "$@" >/dev/null
  echo "$?"
}

test_start "a_missing_command_exits_127"
assert_equals "127" "$(probe_rc 5 dot-probe-no-such-command)" "not installed is 127, not success"

test_start "the_command_status_passes_through"
assert_equals "0" "$(probe_rc 5 true)" "success"
assert_equals "3" "$(probe_rc 5 sh -c 'exit 3')" "a failing command's own status"

test_start "output_is_returned_and_stdin_is_closed"
assert_equals "hello" "$(dot_probe 5 sh -c 'echo hello')" "stdout comes back"
assert_equals "" "$(echo leaked | dot_probe 5 cat)" "the command reads nothing from the caller's stdin"

test_start "a_command_that_never_answers_exits_124"
start=$SECONDS
assert_equals "124" "$(probe_rc 1 sh -c 'sleep 30 & wait')" "past the limit is 124"
assert_equals "true" "$([[ $((SECONDS - start)) -lt 10 ]] && echo true || echo false)" \
  "it returns at the limit, grandchild and all"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
