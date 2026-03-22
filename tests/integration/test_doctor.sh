#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2030,SC2031
# Integration tests for scripts/diagnostics/doctor.sh
# Validates that dot doctor runs without crash and produces expected output.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
export REPO_ROOT
source "$SCRIPT_DIR/../framework/assertions.sh"

DOCTOR_SCRIPT="$REPO_ROOT/scripts/diagnostics/doctor.sh"

run_doctor_with_timeout() {
  local timeout_cmd=""
  timeout_cmd="$(command -v timeout || command -v gtimeout || true)"
  if [[ -n "$timeout_cmd" ]]; then
    "$timeout_cmd" 60 bash "$DOCTOR_SCRIPT" 2>&1
    return $?
  fi
  bash "$DOCTOR_SCRIPT" 2>&1
}

# ── Script existence and structure ──────────────────────────────

test_start "doctor_script_exists"
assert_file_exists "$DOCTOR_SCRIPT" "doctor.sh should exist"

test_start "doctor_script_shebang"
first_line=$(head -n 1 "$DOCTOR_SCRIPT")
assert_equals "#!/usr/bin/env bash" "$first_line" "should have bash shebang"

test_start "doctor_script_strict_mode"
if grep -q 'set -euo pipefail' "$DOCTOR_SCRIPT"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: uses strict mode"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should use set -euo pipefail"
fi

# ── Required sections ─────────────────────────────────────────

test_start "doctor_has_core_sections"
missing_sections=()
for section in "Core Shells" "Modern CLI Tools" "Environment" "Platform" "State" "Performance"; do
  if ! grep -q "$section" "$DOCTOR_SCRIPT"; then
    missing_sections+=("$section")
  fi
done
if [[ ${#missing_sections[@]} -eq 0 ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: all expected sections present"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: missing sections: ${missing_sections[*]}"
fi

# ── Cache freshness check ────────────────────────────────────

test_start "doctor_has_cache_check"
if grep -q 'shell caches' "$DOCTOR_SCRIPT"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: includes shell cache freshness check"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should include shell cache freshness check"
fi

# ── Execution test ────────────────────────────────────────────

test_start "doctor_runs_without_crash"
output=""
exit_code=0
output=$(run_doctor_with_timeout) || exit_code=$?
# doctor exits 0 (healthy) or 1 (errors found) — both are valid
if [[ $exit_code -le 1 ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: exits cleanly (code=$exit_code)"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: unexpected exit code $exit_code"
fi

test_start "doctor_output_has_status_symbols"
if echo "$output" | grep -qE '✓|✗|⚠|\[OK\]|\[FAIL\]|\[WARN\]'; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: output contains status indicators"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: output should contain status indicators"
fi

test_start "doctor_output_has_summary"
if echo "$output" | grep -qiE 'Healthy|error'; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: output contains summary line"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: output should contain summary"
fi

# ── Summary ────────────────────────────────────────────────────

echo ""
echo "Doctor integration tests completed."
print_summary
