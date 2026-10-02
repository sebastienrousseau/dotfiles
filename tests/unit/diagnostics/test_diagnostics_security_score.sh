#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

TEST_SCRIPT="$REPO_ROOT/scripts/diagnostics/security-score.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "security_score_exists"
assert_file_exists "$TEST_SCRIPT" "security-score.sh should exist"

test_start "security_score_syntax"
if bash -n "$TEST_SCRIPT" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: syntax error"
fi

# Each short flag produces exactly what its long form does, and the modes
# differ: quiet prints less than the default, JSON is a document.
test_start "security_score_flag_aliases"
for pair in "-v --verbose" "-q --quiet" "-j --json"; do
  assert_equals "$(bash "$TEST_SCRIPT" "${pair#* }" 2>&1)" "$(bash "$TEST_SCRIPT" "${pair% *}" 2>&1)" \
    "${pair% *} matches ${pair#* }"
done
full_lines="$(bash "$TEST_SCRIPT" 2>&1 | wc -l | tr -d ' ')"
quiet_lines="$(bash "$TEST_SCRIPT" --quiet 2>&1 | wc -l | tr -d ' ')"
assert_equals "true" "$([[ $quiet_lines -lt $full_lines ]] && echo true || echo false)" \
  "--quiet prints less than the default ($quiet_lines < $full_lines lines)"
assert_equals "ok" "$(bash "$TEST_SCRIPT" --json 2>/dev/null | python3 -c 'import json,sys; d=json.load(sys.stdin); print("ok" if "grade" in d else "no grade")' 2>&1)" \
  "--json is a document with a grade"

# Slice 2: drive real line coverage of the script under test
cov_exercise_script "$TEST_SCRIPT"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
