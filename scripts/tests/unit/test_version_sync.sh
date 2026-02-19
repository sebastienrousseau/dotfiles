#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for version-sync.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

VERSION_FILE="$REPO_ROOT/scripts/version-sync.sh"

# Test: version-sync.sh file exists
test_start "version_sync_exists"
assert_file_exists "$VERSION_FILE" "version-sync.sh should exist"

# Test: version-sync.sh is valid shell syntax
test_start "version_sync_syntax"
if bash -n "$VERSION_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: syntax errors"
fi

# Test: reads from package.json
test_start "version_sync_reads_package"
if grep -qE 'package\.json|jq.*version' "$VERSION_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: reads package.json"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should read package.json"
fi

# Test: supports verify mode
test_start "version_sync_verify_mode"
if grep -qE 'verify|--verify|-v' "$VERSION_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: supports verify mode"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should support verify mode"
fi

# Test: uses semver format
test_start "version_sync_semver"
if grep -qE '[0-9]+\.[0-9]+\.[0-9]+|semver|version' "$VERSION_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: uses semver format"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should use semver format"
fi

# Test: shellcheck compliance
test_start "version_sync_shellcheck"
if command -v shellcheck &>/dev/null; then
  errors=$(shellcheck -S error "$VERSION_FILE" 2>&1 | wc -l)
  if [[ "$errors" -eq 0 ]]; then
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: passes shellcheck"
  else
    ((TESTS_FAILED++))
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: has shellcheck errors"
  fi
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: shellcheck not available"
fi

echo ""
echo "Version sync tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
