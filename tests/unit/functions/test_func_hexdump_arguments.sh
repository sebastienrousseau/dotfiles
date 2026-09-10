#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Argument handling in the hexdump function.
#
# The existing suite covers --help, the no-argument error and the full-file
# dump. This one covers the three arms it does not: `--all` used as if it were
# a filename, a path that is not a file, and the line-limited dump.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

FUNC_FILE="$REPO_ROOT/defaults/.chezmoitemplates/functions/files/hexdump.sh"

WORK="$(mktemp -d -t hexdump.XXXXXX)"
cov_setup_sandbox
trap 'rm -rf "$WORK"; cov_teardown_sandbox' EXIT

source "$FUNC_FILE"

if ! command -v xxd >/dev/null 2>&1; then
  echo "SKIP: xxd is not available"
  echo "RESULTS:0:0:0"
  exit 0
fi

SAMPLE="$WORK/sample.bin"
printf 'abcdefghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOP' >"$SAMPLE"

test_start "hexdump_rejects_all_without_a_file"
out="$(hexdump --all 2>&1)"
rc=$?
assert_equals "1" "$rc" "'--all' on its own should return 1"
assert_contains "requires a file argument" "$out" \
  "the error should explain how to use --all"

test_start "hexdump_rejects_a_path_that_is_not_a_file"
out="$(hexdump "$WORK/does-not-exist" 2>&1)"
rc=$?
assert_equals "1" "$rc" "a missing path should return 1"
assert_contains "is not a valid file" "$out" "the error should name the problem"

test_start "hexdump_limits_the_dump_to_a_line_count"
out="$(hexdump "$SAMPLE" 2 2>&1)"
assert_contains "Showing first 2 lines" "$out" \
  "the line-limited form should announce the limit"
# The header lines are the two [INFO] lines; the rest is the dump itself.
dump_lines="$(printf '%s\n' "$out" | grep -c '^[0-9a-f]\{8\}:')"
assert_equals "2" "$dump_lines" "exactly two dump lines should be emitted"

test_start "hexdump_full_file_is_longer_than_the_limited_one"
full="$(hexdump "$SAMPLE" 2>&1 | grep -c '^[0-9a-f]\{8\}:')"
assert_true "[[ $full -gt 2 ]]" \
  "the unlimited dump should be longer than the two-line one"

print_summary
