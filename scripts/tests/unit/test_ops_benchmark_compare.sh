#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for benchmark-compare.sh - competitive benchmarking suite
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

BENCHMARK_FILE="$REPO_ROOT/scripts/ops/benchmark-compare.sh"

echo "Testing benchmark-compare.sh..."

# Test: file exists
test_start "benchmark_compare_exists"
assert_file_exists "$BENCHMARK_FILE" "benchmark-compare.sh should exist"

# Test: valid shell syntax
test_start "benchmark_compare_syntax"
assert_exit_code 0 "bash -n '$BENCHMARK_FILE'"

# Test: has executable permission
test_start "benchmark_compare_executable"
if [[ -x "$BENCHMARK_FILE" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: file is executable"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: file should be executable"
fi

# Test: defines measure_startup function
test_start "benchmark_compare_measure_startup"
assert_file_contains "$BENCHMARK_FILE" "measure_startup()" "should define measure_startup function"

# Test: defines benchmark_startup function
test_start "benchmark_compare_benchmark_startup"
assert_file_contains "$BENCHMARK_FILE" "benchmark_startup()" "should define benchmark_startup function"

# Test: defines benchmark_features function
test_start "benchmark_compare_benchmark_features"
assert_file_contains "$BENCHMARK_FILE" "benchmark_features()" "should define benchmark_features function"

# Test: defines benchmark_memory function
test_start "benchmark_compare_benchmark_memory"
assert_file_contains "$BENCHMARK_FILE" "benchmark_memory()" "should define benchmark_memory function"

# Test: defines generate_report function
test_start "benchmark_compare_generate_report"
assert_file_contains "$BENCHMARK_FILE" "generate_report()" "should define generate_report function"

# Test: uses Time::HiRes for precision timing
test_start "benchmark_compare_uses_hires"
assert_file_contains "$BENCHMARK_FILE" "Time::HiRes" "should use Perl Time::HiRes for precision timing"

# Test: supports warmup runs
test_start "benchmark_compare_warmup"
assert_file_contains "$BENCHMARK_FILE" "WARMUP" "should support warmup runs"

# Test: supports configurable iterations
test_start "benchmark_compare_iterations"
assert_file_contains "$BENCHMARK_FILE" "ITERATIONS" "should support configurable iterations"

# Test: compares against Oh My Zsh
test_start "benchmark_compare_omz"
assert_file_contains "$BENCHMARK_FILE" "oh-my-zsh" "should compare against Oh My Zsh"

# Test: compares against Prezto
test_start "benchmark_compare_prezto"
assert_file_contains "$BENCHMARK_FILE" "zprezto" "should compare against Prezto"

# Test: compares against minimal zsh
test_start "benchmark_compare_minimal"
assert_file_contains "$BENCHMARK_FILE" "Minimal zsh" "should compare against minimal zsh baseline"

# Test: compares against Fish shell
test_start "benchmark_compare_fish"
assert_file_contains "$BENCHMARK_FILE" "Fish" "should compare against Fish shell"

# Test: provides help command
test_start "benchmark_compare_help"
assert_file_contains "$BENCHMARK_FILE" "show_help" "should provide help function"

# Test: defines main entry point
test_start "benchmark_compare_main"
assert_file_contains "$BENCHMARK_FILE" "main()" "should define main function"

# Test: uses ui library
test_start "benchmark_compare_uses_ui"
assert_file_contains "$BENCHMARK_FILE" "source.*ui.sh" "should use ui library"

# Test: creates benchmark directory
test_start "benchmark_compare_benchmark_dir"
assert_file_contains "$BENCHMARK_FILE" "BENCHMARK_DIR" "should define benchmark directory"

# Test: calculates mean, min, max statistics
test_start "benchmark_compare_statistics"
if grep -q "mean" "$BENCHMARK_FILE" && grep -q "min" "$BENCHMARK_FILE" && grep -q "max" "$BENCHMARK_FILE"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: calculates mean/min/max statistics"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should calculate mean/min/max statistics"
fi

# Test: feature completeness tracking
test_start "benchmark_compare_features_list"
features_found=0
for feature in "Syntax highlighting" "Autosuggestions" "Fuzzy finder" "Git integration"; do
  if grep -q "$feature" "$BENCHMARK_FILE"; then
    ((features_found++))
  fi
done
if [[ $features_found -ge 4 ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: tracks multiple features for comparison"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should track multiple features"
fi

# Test: memory measurement uses ps
test_start "benchmark_compare_memory_ps"
assert_file_contains "$BENCHMARK_FILE" "ps -o rss" "should use ps for memory measurement"

# Test: performance thresholds defined
test_start "benchmark_compare_thresholds"
if grep -qE '(100|200)' "$BENCHMARK_FILE" && grep -q "Performance" "$BENCHMARK_FILE"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines performance thresholds"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define performance thresholds"
fi

# Test: help shows usage
test_start "benchmark_compare_help_usage"
set +e
output=$(bash "$BENCHMARK_FILE" help 2>&1)
ec=$?
set -e
if [[ "$output" == *"Usage:"* ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: help shows usage"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: help should show usage"
fi

echo ""
echo "benchmark-compare.sh tests completed."
print_summary
