#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioral tests for the extract function.
# Tests dispatch logic, error handling, and format-specific routing.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"

FUNC_FILE="$REPO_ROOT/.chezmoitemplates/functions/files/extract.sh"
if [[ ! -f "$FUNC_FILE" ]]; then
  echo "SKIP: extract.sh not found at $FUNC_FILE"
  echo "RESULTS:0:0:0"
  exit 0
fi
source "$FUNC_FILE"

mock_init

# --- helpers ---

# Create a real empty file with the given extension so the -f test passes.
_make_fake_file() {
  local name="$1"
  local tmp
  tmp=$(mktemp -t "fake_XXXXXX_${name}")
  # mktemp doesn't honour double-extensions, rename it
  local target
  target="$(dirname "$tmp")/${name}"
  mv "$tmp" "$target"
  echo "$target"
}

# ──────────────────────────────────────────────────────────────────────────────
# 1. --help flag outputs usage information
# ──────────────────────────────────────────────────────────────────────────────
test_start "extract_help_flag"
output=$(extract --help 2>&1)
assert_contains "Usage" "$output" "--help should print usage"

# ──────────────────────────────────────────────────────────────────────────────
# 2. --help exits with code 0
# ──────────────────────────────────────────────────────────────────────────────
test_start "extract_help_exit_code"
extract --help >/dev/null 2>&1
assert_equals "0" "$?" "--help should return exit code 0"

# ──────────────────────────────────────────────────────────────────────────────
# 3. No arguments → error and non-zero exit
# ──────────────────────────────────────────────────────────────────────────────
test_start "extract_no_args_exits_nonzero"
output=$(extract 2>&1)
assert_equals "1" "$?" "no-arg call should return exit code 1"

test_start "extract_no_args_error_message"
output=$(extract 2>&1)
assert_contains "ERROR" "$output" "no-arg call should print ERROR"

# ──────────────────────────────────────────────────────────────────────────────
# 4. Non-existent file → error
# ──────────────────────────────────────────────────────────────────────────────
test_start "extract_missing_file_exits_nonzero"
extract /tmp/no_such_file_xyzzy.tar.gz 2>/dev/null
assert_equals "1" "$?" "missing file should return exit code 1"

test_start "extract_missing_file_error_message"
output=$(extract /tmp/no_such_file_xyzzy.tar.gz 2>&1)
assert_contains "not a valid file" "$output" "missing file should print 'not a valid file'"

# ──────────────────────────────────────────────────────────────────────────────
# 5. Unknown extension → error
# ──────────────────────────────────────────────────────────────────────────────
test_start "extract_unknown_extension"
fake=$(_make_fake_file "archive.xyz")
output=$(extract "$fake" 2>&1)
assert_contains "cannot be extracted" "$output" "unknown extension should print 'cannot be extracted'"
rm -f "$fake"

# ──────────────────────────────────────────────────────────────────────────────
# 6. .tar.gz dispatches to 'tar xzf'
# ──────────────────────────────────────────────────────────────────────────────
test_start "extract_tar_gz_calls_tar"
mock_command_spy "tar" ""
fake=$(_make_fake_file "archive.tar.gz")
extract "$fake" >/dev/null 2>&1 || true
calls=$(mock_get_calls "tar")
assert_contains "xzf" "$calls" ".tar.gz should call 'tar xzf'"
rm -f "$fake"

# ──────────────────────────────────────────────────────────────────────────────
# 7. .tar.bz2 dispatches to 'tar xjf'
# ──────────────────────────────────────────────────────────────────────────────
test_start "extract_tar_bz2_calls_tar_xjf"
# Reinitialise spy so call count is fresh
mock_init
mock_command_spy "tar" ""
fake=$(_make_fake_file "archive.tar.bz2")
extract "$fake" >/dev/null 2>&1 || true
calls=$(mock_get_calls "tar")
assert_contains "xjf" "$calls" ".tar.bz2 should call 'tar xjf'"
rm -f "$fake"

# ──────────────────────────────────────────────────────────────────────────────
# 8. .zip dispatches to 'unzip'
# ──────────────────────────────────────────────────────────────────────────────
test_start "extract_zip_calls_unzip"
mock_init
mock_command_spy "unzip" ""
fake=$(_make_fake_file "archive.zip")
extract "$fake" >/dev/null 2>&1 || true
count=$(mock_call_count "unzip")
assert_equals "1" "$count" ".zip should call 'unzip' exactly once"
rm -f "$fake"

# ──────────────────────────────────────────────────────────────────────────────
# 9. .gz (bare, not .tar.gz) dispatches to 'gunzip'
# ──────────────────────────────────────────────────────────────────────────────
test_start "extract_gz_calls_gunzip"
mock_init
mock_command_spy "gunzip" ""
fake=$(_make_fake_file "archive.gz")
extract "$fake" >/dev/null 2>&1 || true
count=$(mock_call_count "gunzip")
assert_equals "1" "$count" ".gz should call 'gunzip' exactly once"
rm -f "$fake"

# ──────────────────────────────────────────────────────────────────────────────
# 10. .7z dispatches to '7z x'
# ──────────────────────────────────────────────────────────────────────────────
test_start "extract_7z_calls_7z"
mock_init
mock_command_spy "7z" ""
fake=$(_make_fake_file "archive.7z")
extract "$fake" >/dev/null 2>&1 || true
calls=$(mock_get_calls "7z")
assert_contains "x" "$calls" ".7z should call '7z x'"
rm -f "$fake"

# ──────────────────────────────────────────────────────────────────────────────
# 11. Too many arguments → error
# ──────────────────────────────────────────────────────────────────────────────
test_start "extract_too_many_args"
output=$(extract file1.tar.gz file2.tar.gz 2>&1)
assert_equals "1" "$?" "two arguments should return exit code 1"

mock_cleanup

echo ""
echo "extract behavioral tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
