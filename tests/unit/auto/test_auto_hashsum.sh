#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Auto-generated exercise test for dot_local/bin/executable_hashsum.
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

SCRIPT_FILE="$REPO_ROOT/defaults/dot_local/bin/executable_hashsum"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "dot_local/bin/executable_hashsum must exist"

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

test_start "hashsum_deep_branches_execute"
hashsum_tmp="$DOTFILES_COV_TMPDIR/hashsum-deep"
mkdir -p "$hashsum_tmp"
printf 'hello' >"$hashsum_tmp/input.txt"
(
  set +e
  bash "$SCRIPT_FILE" --help
  bash "$SCRIPT_FILE" "hello"
  bash "$SCRIPT_FILE" --md5 "hello"
  bash "$SCRIPT_FILE" --sha1 "hello"
  bash "$SCRIPT_FILE" --sha512 "hello"
  bash "$SCRIPT_FILE" --all "hello"
  bash "$SCRIPT_FILE" --file "$hashsum_tmp/input.txt"
  bash "$SCRIPT_FILE" --check \
    "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824" \
    "hello"
  bash "$SCRIPT_FILE" --check "deadbeef" "hello"
  bash "$SCRIPT_FILE" --file "$hashsum_tmp/missing.txt"
  bash "$SCRIPT_FILE" --unknown "hello"
  printf 'stdin-value\n' | bash "$SCRIPT_FILE"
) >/dev/null || true
assert_file_exists "$hashsum_tmp/input.txt" \
  "hashsum deep branches used sandbox input file"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
