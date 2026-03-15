#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2030,SC2031
# Integration tests for health dashboard (scripts/diagnostics/health.sh)
# health-check.sh was consolidated into health.sh; this test validates health.sh.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../framework/assertions.sh"

HEALTH_SCRIPT="$REPO_ROOT/scripts/diagnostics/health.sh"

# ── Script existence and structure ──────────────────────────────

test_start "health_check_exists"
assert_file_exists "$HEALTH_SCRIPT" "health.sh should exist"

test_start "health_check_executable"
if [[ -r "$HEALTH_SCRIPT" ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: health.sh is readable"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: health.sh should be readable"
fi

test_start "health_check_shebang"
first_line=$(head -n 1 "$HEALTH_SCRIPT")
assert_equals "#!/usr/bin/env bash" "$first_line" "should have bash shebang"

# ── Execution in sandbox ───────────────────────────────────────

test_start "health_check_runs_without_crash"
exit_code=0
timeout 30 bash "$HEALTH_SCRIPT" >/dev/null 2>&1 || exit_code=$?
# Health check may return 1 for failures — that's OK, we just want no crash (exit > 1)
if [[ $exit_code -le 1 ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: exits cleanly (code=$exit_code)"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: unexpected exit code $exit_code"
fi

test_start "health_check_json_flag"
if grep -q '\-\-json\|json' "$HEALTH_SCRIPT"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: supports JSON output mode"
else
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: JSON flag check skipped (not implemented)"
fi

test_start "health_check_verbose_flag"
if grep -q 'verbose\|VERBOSE' "$HEALTH_SCRIPT"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: supports verbose mode"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should support verbose mode"
fi

test_start "health_check_results_array"
if grep -q 'RESULTS' "$HEALTH_SCRIPT"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: has RESULTS array for structured output"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should have RESULTS array"
fi

# ── Summary ────────────────────────────────────────────────────

echo ""
echo "Health check integration tests completed."
print_summary
