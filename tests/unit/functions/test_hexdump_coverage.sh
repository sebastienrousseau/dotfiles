#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Behaviour tests for the hexdump function: help, missing/invalid
# arguments, full dumps (implicit and --all) and a line-limited dump.
# `file` and `xxd` are PATH stubs so the test does not depend on either
# being installed and can assert exactly what they were asked to do.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

FUNC_FILE="$REPO_ROOT/defaults/.chezmoitemplates/functions/files/hexdump.sh"

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/hexdump-cov.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home"
mkdir -p "$HOME" "$SANDBOX/bin"
LOG="$SANDBOX/calls.log"

cat >"$SANDBOX/bin/file" <<'STUB'
#!/usr/bin/env bash
echo "$1: ASCII text"
STUB
cat >"$SANDBOX/bin/xxd" <<STUB
#!/usr/bin/env bash
printf 'xxd %s\n' "\$*" >>"$LOG"
for i in 1 2 3 4 5; do echo "0000000\$i: 41 42 43"; done
STUB
chmod +x "$SANDBOX/bin/file" "$SANDBOX/bin/xxd"
export PATH="$SANDBOX/bin:$PATH"

SAMPLE="$SANDBOX/sample.txt"
printf 'ABC\n' >"$SAMPLE"

source "$FUNC_FILE"

test_start "help"
out="$(hexdump --help 2>&1)"
assert_equals "0" "$?" "help returns 0"
assert_contains "Hex Dump Viewer" "$out" "help banner"

test_start "no_argument"
out="$(hexdump "" 2>&1)"
assert_equals "1" "$?" "empty argument returns 1"
assert_contains "No file provided" "$out" "missing file error"

test_start "all_without_file"
out="$(hexdump --all 2>&1)"
assert_equals "1" "$?" "--all alone returns 1"
assert_contains "'--all' requires a file argument" "$out" "--all error"

test_start "invalid_file"
out="$(hexdump "$SANDBOX/missing.bin" 2>&1)"
assert_equals "1" "$?" "missing file returns 1"
assert_contains "is not a valid file" "$out" "invalid file error"

test_start "full_dump"
: >"$LOG"
out="$(hexdump "$SAMPLE" 2>&1)"
assert_equals "0" "$?" "full dump returns 0"
assert_contains "File type: $SAMPLE: ASCII text" "$out" "reports file type"
assert_contains "Showing full file" "$out" "full dump banner"
assert_contains "00000005: 41 42 43" "$out" "prints every xxd line"
assert_equals "xxd -u -g 1 $SAMPLE" "$(cat "$LOG")" "xxd called with upper-case grouping"

test_start "explicit_all"
out="$(hexdump "$SAMPLE" --all 2>&1)"
assert_equals "0" "$?" "--all second argument returns 0"
assert_contains "Showing full file" "$out" "--all shows full file"

test_start "line_limit"
out="$(hexdump "$SAMPLE" 2 2>&1)"
assert_equals "0" "$?" "limited dump returns 0"
assert_contains "Showing first 2 lines" "$out" "limit banner"
assert_contains "00000002: 41 42 43" "$out" "second line present"
assert_false "[[ '$out' == *'00000003'* ]]" "third line cut by head"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
