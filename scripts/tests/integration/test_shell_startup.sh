#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2030,SC2031
# Integration tests for shell startup performance
# Measures actual startup time across available shells and enforces thresholds

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../framework/assertions.sh"

STARTUP_THRESHOLD_MS=500

# Portable millisecond timing
measure_startup_ms() {
  local shell_cmd="$1"
  local total=0
  local iterations=3

  for ((i = 1; i <= iterations; i++)); do
    local start end
    if command -v perl >/dev/null 2>&1; then
      start=$(perl -MTime::HiRes=time -e 'printf "%.0f\n", time * 1000')
      $shell_cmd -i -c 'exit' >/dev/null 2>&1 || true
      end=$(perl -MTime::HiRes=time -e 'printf "%.0f\n", time * 1000')
    else
      start=$(($(date +%s%N 2>/dev/null || echo 0) / 1000000))
      $shell_cmd -i -c 'exit' >/dev/null 2>&1 || true
      end=$(($(date +%s%N 2>/dev/null || echo 0) / 1000000))
    fi
    total=$((total + end - start))
  done

  echo $((total / iterations))
}

# ── Bash startup ───────────────────────────────────────────────

test_start "bash_startup_performance"
if command -v bash >/dev/null 2>&1; then
  time_ms=$(measure_startup_ms bash)
  if [[ $time_ms -le $STARTUP_THRESHOLD_MS ]]; then
    ((TESTS_PASSED++))
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: bash starts in ${time_ms}ms (threshold: ${STARTUP_THRESHOLD_MS}ms)"
  else
    ((TESTS_FAILED++))
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: bash startup ${time_ms}ms exceeds ${STARTUP_THRESHOLD_MS}ms"
  fi
else
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: skipped (bash not available)"
fi

# ── Zsh startup ────────────────────────────────────────────────

test_start "zsh_startup_performance"
if command -v zsh >/dev/null 2>&1; then
  time_ms=$(measure_startup_ms zsh)
  if [[ $time_ms -le $STARTUP_THRESHOLD_MS ]]; then
    ((TESTS_PASSED++))
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: zsh starts in ${time_ms}ms (threshold: ${STARTUP_THRESHOLD_MS}ms)"
  else
    ((TESTS_FAILED++))
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: zsh startup ${time_ms}ms exceeds ${STARTUP_THRESHOLD_MS}ms"
  fi
else
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: skipped (zsh not available)"
fi

# ── Fish startup ───────────────────────────────────────────────

test_start "fish_startup_performance"
if command -v fish >/dev/null 2>&1; then
  # Fish uses -c not -i -c
  total=0
  iterations=3
  for ((i = 1; i <= iterations; i++)); do
    local start end
    if command -v perl >/dev/null 2>&1; then
      start=$(perl -MTime::HiRes=time -e 'printf "%.0f\n", time * 1000')
      fish -c 'exit' >/dev/null 2>&1 || true
      end=$(perl -MTime::HiRes=time -e 'printf "%.0f\n", time * 1000')
    else
      start=$(($(date +%s%N 2>/dev/null || echo 0) / 1000000))
      fish -c 'exit' >/dev/null 2>&1 || true
      end=$(($(date +%s%N 2>/dev/null || echo 0) / 1000000))
    fi
    total=$((total + end - start))
  done
  time_ms=$((total / iterations))

  if [[ $time_ms -le $STARTUP_THRESHOLD_MS ]]; then
    ((TESTS_PASSED++))
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: fish starts in ${time_ms}ms (threshold: ${STARTUP_THRESHOLD_MS}ms)"
  else
    ((TESTS_FAILED++))
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: fish startup ${time_ms}ms exceeds ${STARTUP_THRESHOLD_MS}ms"
  fi
else
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: skipped (fish not available)"
fi

# ── Summary ────────────────────────────────────────────────────

echo ""
echo "Shell startup performance tests completed."
print_summary
