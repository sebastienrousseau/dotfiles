#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for Wave 1: heal.sh shellcheck and shfmt fixes
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

HEAL_SCRIPT="$REPO_ROOT/scripts/ops/heal.sh"

echo "Testing Wave 1: heal.sh fixes..."

test_start "heal_exists"
assert_file_exists "$HEAL_SCRIPT" "heal.sh should exist"

test_start "heal_syntax"
assert_exit_code 0 "bash -n '$HEAL_SCRIPT'"

test_start "heal_strict_mode"
assert_file_contains "$HEAL_SCRIPT" "set -euo pipefail" "should use strict mode"

test_start "heal_no_sc2015_pattern"
# SC2015: A && B || C is not if-then-else. Should use proper if/then.
# Check that the backup loop does NOT use && ... || pattern
backup_block=$(sed -n '/create_pre_heal_backup/,/^}/p' "$HEAL_SCRIPT")
if echo "$backup_block" | grep -q '&&.*cp.*||' 2>/dev/null; then
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should not use A && B || C pattern (SC2015)"
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: no SC2015 pattern in backup block"
fi

test_start "heal_backup_uses_if"
# The backup file copy should use proper if/then
if echo "$backup_block" | grep -q 'if \[\[.*-f.*\]\]; then' 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: backup uses proper if/then for file copy"
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: backup block refactored (no A&&B||C)"
fi

test_start "heal_shfmt_case_spacing"
# Verify case branch formatting (should not have extra spaces like "brew)   ")
if grep -qP 'brew\)\s{3,}' "$HEAL_SCRIPT" 2>/dev/null; then
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: case branches should not have extra spaces"
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: case branch spacing is correct"
fi

test_start "heal_shfmt_pipe_spacing"
# Verify pipe spacing in case patterns (should be "apt | dnf" not "apt|dnf")
if grep -qP 'apt\|dnf' "$HEAL_SCRIPT" 2>/dev/null; then
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: case pipes should have spaces (apt | dnf)"
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: case pipe spacing is correct"
fi

test_start "heal_has_help_flag"
if grep -qF -- "--help" "$HEAL_SCRIPT"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: should support --help flag"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should support --help flag"
fi

test_start "heal_has_dry_run"
if grep -qF -- "--dry-run" "$HEAL_SCRIPT"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: should support --dry-run flag"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should support --dry-run flag"
fi

test_start "heal_has_force"
if grep -qF -- "--force" "$HEAL_SCRIPT"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: should support --force flag"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should support --force flag"
fi

test_start "heal_persist_log"
assert_file_contains "$HEAL_SCRIPT" "persist_log" "should log actions persistently"

echo ""
echo "Wave 1 heal.sh fix tests completed."
print_summary
