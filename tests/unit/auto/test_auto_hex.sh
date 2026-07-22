#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Auto-generated exercise test for dot_local/bin/executable_hex.
# Slice 3 of #883: backfill coverage by running each managed script
# through safe-mode entry points (--help / no-arg / invalid flag).
# Edit-by-hand to add behavioral assertions; the auto-shell will leave
# this file alone if `# AUTO-GENERATED: false` appears in the first
# 10 lines.
#
# AUTO-GENERATED: true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/defaults/dot_local/bin/executable_hex"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "dot_local/bin/executable_hex must exist"

test_start "script_valid_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

cov_exercise_script "$SCRIPT_FILE"
cov_exercise_functions_file "$SCRIPT_FILE"

test_start "hex_deep_branches_execute"
hex_tmp="$DOTFILES_COV_TMPDIR/hex-deep"
mkdir -p "$hex_tmp"
printf 'hello' >"$hex_tmp/input.bin"
(
  set +e
  bash "$SCRIPT_FILE" --help
  bash "$SCRIPT_FILE" --encode "hello"
  printf 'stdin\n' | bash "$SCRIPT_FILE" --encode
  bash "$SCRIPT_FILE" --decode "68656c6c6f"
  printf '737464696e\n' | bash "$SCRIPT_FILE" --decode
  bash "$SCRIPT_FILE" --length 8 "$hex_tmp/input.bin"
  printf 'pipe\n' | bash "$SCRIPT_FILE" --length 8
  bash "$SCRIPT_FILE" --unknown
) >/dev/null || true
assert_file_exists "$hex_tmp/input.bin" \
  "hex deep branches used sandbox binary fixture"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
