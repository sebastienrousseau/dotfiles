#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Auto-generated exercise test for dot_local/bin/executable_regex.
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

SCRIPT_FILE="$REPO_ROOT/defaults/dot_local/bin/executable_regex"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "dot_local/bin/executable_regex must exist"

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

test_start "regex_deep_branches_execute"
regex_tmp="$DOTFILES_COV_TMPDIR/regex-deep"
mkdir -p "$regex_tmp"
printf 'Error 123\nok 456\n' >"$regex_tmp/input.txt"
(
  set +e
  bash "$SCRIPT_FILE" --help
  bash "$SCRIPT_FILE" "[0-9]+" "abc123def"
  bash "$SCRIPT_FILE" --global "[0-9]+" "abc123def456"
  bash "$SCRIPT_FILE" --ignore "error" "ERROR line"
  bash "$SCRIPT_FILE" --no-color "nomatch" "plain text"
  bash "$SCRIPT_FILE" --file "^[Ee]rror" "$regex_tmp/input.txt"
  bash "$SCRIPT_FILE" --file "missing" "$regex_tmp/missing.txt"
  bash "$SCRIPT_FILE" --unknown "[0-9]+" "abc123"
  printf 'stdin 789\n' | bash "$SCRIPT_FILE" "[0-9]+"
) >/dev/null || true
assert_file_exists "$regex_tmp/input.txt" \
  "regex deep branches used sandbox input file"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
