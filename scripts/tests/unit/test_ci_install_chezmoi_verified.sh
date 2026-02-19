#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for ci/install-chezmoi-verified.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/ci/install-chezmoi-verified.sh"

test_start "ci_install_chezmoi_verified_exists"
assert_file_exists "$SCRIPT_FILE" "install-chezmoi-verified.sh should exist"

test_start "ci_install_chezmoi_verified_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: syntax errors"
fi

test_start "ci_install_chezmoi_verified_checksums"
if grep -qE 'checksums\.txt|sha256sum|shasum' "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: verifies checksums"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: checksum verification missing"
fi

test_start "ci_install_chezmoi_verified_installs_binary"
if grep -qE 'install -m 755|tar -xzf' "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: installs binary"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: binary install step missing"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
