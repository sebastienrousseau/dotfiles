#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# cdls changes directory and lists the new one. Runs the function in a
# subshell against a fixture directory.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

FUNC_FILE="$REPO_ROOT/defaults/.chezmoitemplates/functions/nav/cdls.sh"
WORK="$(mktemp -d -t dot-cdls.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/dir/sub" "$WORK/home"
touch "$WORK/dir/alpha.txt" "$WORK/home/in-home.txt"

# cdls_run <args…> — run cdls, then print the working directory it left.
cdls_run() {
  RC=0
  OUT="$(HOME="$WORK/home" bash -c 'source "$1"; shift; cdls "$@" && printf "PWD=%s\n" "$PWD"' _ "$FUNC_FILE" "$@" 2>&1)" || RC=$?
}

test_start "help_prints_usage"
cdls_run --help
assert_equals "0" "$RC" "--help exits 0"
assert_contains "cdls: Change Directory and List Contents" "$OUT" "the title"
assert_contains "cdls [directory]" "$OUT" "the usage line"

test_start "changes_directory_and_lists_it"
cdls_run "$WORK/dir"
assert_equals "0" "$RC" "exits 0"
assert_contains "alpha.txt" "$OUT" "lists the new directory"
assert_contains "PWD=$(cd "$WORK/dir" && pwd)" "$OUT" "and stays in it"

test_start "no_argument_goes_home"
cdls_run
assert_contains "in-home.txt" "$OUT" "lists HOME"

test_start "a_missing_directory_fails_without_listing"
cdls_run "$WORK/nope"
assert_not_equals "0" "$RC" "exits non-zero"
assert_equals "0" "$(grep -c 'PWD=' <<<"$OUT")" "and does not continue"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
