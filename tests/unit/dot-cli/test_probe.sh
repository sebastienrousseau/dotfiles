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

# dot_bounded <seconds> <command…>: the same limit and exit codes with the
# caller's stdin and stderr left alone, for commands that are not queries.
bounded_rc() {
  dot_bounded "$@" >/dev/null 2>&1
  echo "$?"
}

test_start "bounded_keeps_the_exit_codes"
assert_equals "0" "$(bounded_rc 5 true)" "success"
assert_equals "3" "$(bounded_rc 5 sh -c 'exit 3')" "a failing command's own status"
assert_equals "127" "$(bounded_rc 5 dot-probe-no-such-command)" "not installed is 127"
start=$SECONDS
assert_equals "124" "$(bounded_rc 1 sh -c 'sleep 30 & wait')" "past the limit is 124"
assert_equals "true" "$([[ $((SECONDS - start)) -lt 10 ]] && echo true || echo false)" \
  "it returns at the limit, grandchild and all"

test_start "bounded_passes_stdin_and_stderr_through"
assert_equals "fed" "$(echo fed | dot_bounded 5 cat)" "the command reads the caller's stdin"
assert_equals "warned" "$(dot_bounded 5 sh -c 'echo warned >&2' 2>&1)" "its stderr reaches the caller"

# Neither needs timeout(1), which macOS before 27 does not ship: with no
# timeout or gtimeout on PATH the limit still holds.
test_start "bounded_needs_no_timeout_binary"
nt="$(mktemp -d "${TMPDIR:-/tmp}/probe-nt.XXXXXX")"
for t in perl sh sleep cat; do ln -s "$(command -v "$t")" "$nt/$t"; done
start=$SECONDS
rc="$(PATH="$nt" bounded_rc 1 sh -c 'sleep 30 & wait')"
assert_equals "124" "$rc" "past the limit is 124 without timeout(1)"
assert_equals "true" "$([[ $((SECONDS - start)) -lt 10 ]] && echo true || echo false)" \
  "and it returns at the limit"
rm -rf "$nt"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
