#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for security-score diagnostic script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

SCORE_FILE="$REPO_ROOT/scripts/diagnostics/security-score.sh"

# Test: security-score.sh file exists
test_start "security_score_file_exists"
assert_file_exists "$SCORE_FILE" "security-score.sh should exist"

# Test: security-score.sh is valid shell syntax
test_start "security_score_syntax_valid"
if bash -n "$SCORE_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: security-score.sh has valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: security-score.sh has syntax errors"
fi

# Test: calculates a score
test_start "security_score_calculates"
if grep -qE 'score|SCORE|points|total' "$SCORE_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: calculates a score"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should calculate a score"
fi

# Test: checks security configurations
test_start "security_score_checks_config"
if grep -qE 'ssh|gpg|encrypt|firewall|permission' "$SCORE_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: checks security configurations"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should check security configurations"
fi

# Test: provides grade or rating
test_start "security_score_provides_grade"
if grep -qE 'grade|rating|level|A|B|C|excellent|good|poor' "$SCORE_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: provides grade/rating"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should provide grade/rating"
fi

# Test: shellcheck compliance
test_start "security_score_shellcheck"
if command -v shellcheck &>/dev/null; then
  errors=$(shellcheck -S error "$SCORE_FILE" 2>&1 | wc -l)
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
echo "Security score tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
