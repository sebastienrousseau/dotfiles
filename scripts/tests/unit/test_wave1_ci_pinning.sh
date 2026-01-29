#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for Wave 1: CI chezmoi version pinning
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

CI_FILE="$REPO_ROOT/.github/workflows/ci.yml"

echo "Testing Wave 1: CI chezmoi version pinning..."

test_start "ci_yml_exists"
assert_file_exists "$CI_FILE" "ci.yml should exist"

test_start "ci_chezmoi_version_env"
assert_file_contains "$CI_FILE" "CHEZMOI_VERSION:" "should define CHEZMOI_VERSION env variable"

test_start "ci_chezmoi_version_pinned"
# Verify the version is a proper semver (not 'latest')
if grep -q 'CHEZMOI_VERSION:.*"[0-9]' "$CI_FILE"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: CHEZMOI_VERSION is pinned to a semver"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: CHEZMOI_VERSION should be pinned to a semver"
fi

test_start "ci_chezmoi_not_latest"
if grep -q 'CHEZMOI_VERSION.*latest' "$CI_FILE" 2>/dev/null; then
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: CHEZMOI_VERSION should not be 'latest'"
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: CHEZMOI_VERSION is not 'latest'"
fi

test_start "ci_chezmoi_uses_tag_flag"
# get.chezmoi.io uses -t flag, not -v
if grep -q 'get.chezmoi.io.*-v ' "$CI_FILE" 2>/dev/null; then
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: get.chezmoi.io should use -t flag, not -v"
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: get.chezmoi.io does not use incorrect -v flag"
fi

test_start "ci_chezmoi_tag_format"
# Should use -t vX.Y.Z format
if grep -q '\-t v' "$CI_FILE"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: uses -t v prefix for chezmoi tag"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should use -t vX.Y.Z format"
fi

echo ""
echo "Wave 1 CI pinning tests completed."
print_summary
