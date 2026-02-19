#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for benchmark diagnostic script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

BENCH_FILE="$REPO_ROOT/scripts/diagnostics/benchmark.sh"

# Test: benchmark.sh file exists
test_start "benchmark_file_exists"
assert_file_exists "$BENCH_FILE" "benchmark.sh should exist"

# Test: benchmark.sh is valid shell syntax
test_start "benchmark_syntax_valid"
if bash -n "$BENCH_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: benchmark.sh has valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: benchmark.sh has syntax errors"
fi

# Test: measures shell startup time
test_start "benchmark_measures_startup"
if grep -qE 'startup|time|zsh.*exit|bash.*exit' "$BENCH_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: measures shell startup time"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should measure shell startup time"
fi

# Test: reports timing in milliseconds
test_start "benchmark_reports_ms"
if grep -qE 'ms|millisecond|[0-9]+ms' "$BENCH_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: reports timing in ms"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should report timing in ms"
fi

# Test: defines threshold
test_start "benchmark_defines_threshold"
if grep -qE 'threshold|THRESHOLD|500|200' "$BENCH_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines performance threshold"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define performance threshold"
fi

# Test: shellcheck compliance
test_start "benchmark_shellcheck"
if command -v shellcheck &>/dev/null; then
  errors=$(shellcheck -S error "$BENCH_FILE" 2>&1 | wc -l)
  if [[ "$errors" -eq 0 ]]; then
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: passes shellcheck"
  else
    ((TESTS_FAILED++))
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: has shellcheck errors"
  fi
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: shellcheck not available, skipped"
fi

echo ""
echo "Benchmark diagnostic tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
