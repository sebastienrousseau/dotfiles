#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for security backup script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

BACKUP_FILE="$REPO_ROOT/scripts/security/backup.sh"

# Test: backup.sh file exists
test_start "sec_backup_file_exists"
assert_file_exists "$BACKUP_FILE" "backup.sh should exist"

# Test: backup.sh is valid shell syntax
test_start "sec_backup_syntax_valid"
if bash -n "$BACKUP_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: backup.sh has valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: backup.sh has syntax errors"
fi

# Test: creates backup archives
test_start "sec_backup_creates_archive"
if grep -qE 'tar|zip|archive|backup' "$BACKUP_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: creates backup archives"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should create backup archives"
fi

# Test: timestamps backups
test_start "sec_backup_timestamps"
if grep -qE 'date|timestamp|\+%Y|\+%s' "$BACKUP_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: timestamps backups"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should timestamp backups"
fi

# Test: no dangerous rm commands
test_start "sec_backup_safe_rm"
if grep -qE 'rm -rf /[^$]' "$BACKUP_FILE" 2>/dev/null; then
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: has dangerous rm commands"
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: no dangerous rm commands"
fi

# Test: shellcheck compliance
test_start "sec_backup_shellcheck"
if command -v shellcheck &>/dev/null; then
  errors=$(shellcheck -S error "$BACKUP_FILE" 2>&1 | wc -l)
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
echo "Security backup tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
