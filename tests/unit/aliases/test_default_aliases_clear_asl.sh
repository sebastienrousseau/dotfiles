#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# clear_asl_logs (default/default.aliases.sh) deletes the ASL logs only on
# an explicit yes; anything else aborts with status 1 and touches nothing.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

ALIAS_FILE="$REPO_ROOT/defaults/.chezmoitemplates/aliases/default/default.aliases.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# clear_asl ANSWER: runs clear_asl_logs on macOS with a recording sudo stub;
# prints the output, the status and the recorded sudo calls.
clear_asl() {
  (
    source "$ALIAS_FILE" >/dev/null 2>&1
    # The stub records the call instead of deleting anything.
    sudo() { printf '%s\n' "$*" >>"$WORK/sudo.log"; }
    OSTYPE=darwin23
    printf '%s\n' "$1" | clear_asl_logs 2>&1
    echo "rc=$?"
  )
  cat "$WORK/sudo.log" 2>/dev/null
  rm -f "$WORK/sudo.log"
}

test_start "clear_asl_no_aborts"
out="$(clear_asl n)"
assert_contains "Aborted." "$out" "a no aborts"
assert_contains "rc=1" "$out" "an abort returns 1"
assert_empty "$(printf '%s\n' "$out" | grep -F 'rm -rf')" "a no runs no sudo rm"

test_start "clear_asl_empty_answer_aborts"
out="$(clear_asl '')"
assert_contains "rc=1" "$out" "the default answer is no"

test_start "clear_asl_yes_clears"
out="$(clear_asl y)"
assert_contains "rm -rf /private/var/log/asl/" "$out" "a yes runs sudo rm"
assert_contains "rc=0" "$out" "a yes returns 0"
out="$(clear_asl Yes)"
assert_contains "rm -rf /private/var/log/asl/" "$out" "Yes counts as yes"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
