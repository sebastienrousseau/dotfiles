#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
# Unit tests for security fixes

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

echo "Testing security fixes..."

# Test: mount_read_only.sh validates input
test_start "mount_read_only_validates_input"
FUNC_FILE="$REPO_ROOT/.chezmoitemplates/functions/mount_read_only.sh"
assert_file_exists "$FUNC_FILE" "mount_read_only.sh should exist"

# Test: mount_read_only requires argument
test_start "mount_read_only_requires_arg"
result=$(bash -c '
  source "'"$FUNC_FILE"'"
  mount_read_only 2>&1
')
if [[ "$result" == *"No disk image specified"* ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: rejects empty argument"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should reject empty argument"
  echo -e "    Actual: $result"
fi

# Test: mount_read_only rejects missing file
test_start "mount_read_only_rejects_missing"
result=$(bash -c '
  source "'"$FUNC_FILE"'"
  mount_read_only "/nonexistent/file.dmg" 2>&1
')
if [[ "$result" == *"Disk image not found"* ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: rejects missing file"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should reject missing file"
  echo -e "    Actual: $result"
fi

# Test: genpass validates numeric input
test_start "genpass_validates_numeric"
GENPASS_FILE="$REPO_ROOT/.chezmoitemplates/functions/genpass.sh"
result=$(bash -c '
  source "'"$GENPASS_FILE"'"
  genpass "abc" 2>&1
' 2>&1)
if [[ "$result" == *"must be a number"* ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: rejects non-numeric input"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should reject non-numeric input"
  echo -e "    Actual: $result"
fi

# Test: genpass rejects out-of-range values
test_start "genpass_rejects_out_of_range"
result=$(bash -c '
  source "'"$GENPASS_FILE"'"
  genpass 101 2>&1
' 2>&1)
if [[ "$result" == *"must be a number between 1 and 100"* ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: rejects out of range input"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should reject out of range input"
  echo -e "    Actual: $result"
fi

# Test: genpass accepts valid input
test_start "genpass_accepts_valid"
result=$(bash -c '
  source "'"$GENPASS_FILE"'"
  genpass 2 2>&1
' 2>&1)
if [[ "$result" == *"Generated password"* ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: accepts valid numeric input"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should accept valid numeric input"
  echo -e "    Actual: $result"
fi

# Test: chezmoi-apply.sh uses read for safe parsing
test_start "chezmoi_apply_safe_parsing"
APPLY_FILE="$REPO_ROOT/scripts/ops/chezmoi-apply.sh"
assert_file_contains "$APPLY_FILE" 'read -ra flag_array' "should use read for safe parsing"

# Test: chezmoi-update.sh uses read for safe parsing
test_start "chezmoi_update_safe_parsing"
UPDATE_FILE="$REPO_ROOT/scripts/ops/chezmoi-update.sh"
assert_file_contains "$UPDATE_FILE" 'read -ra flag_array' "should use read for safe parsing"

# Test: tmux-sessionizer sanitizes session names
test_start "tmux_sessionizer_sanitizes"
SESSION_FILE="$REPO_ROOT/dot_local/bin/executable_tmux-sessionizer"
assert_file_contains "$SESSION_FILE" "tr -cd '[:alnum:]._-'" "should sanitize session names"

# Test: install.sh uses printf instead of sed for config generation
test_start "install_uses_printf_config"
INSTALL_FILE="$REPO_ROOT/install.sh"
assert_file_contains "$INSTALL_FILE" "printf" "should use printf for safe config generation"

# Test: permission aliases warn about dangerous modes
test_start "permission_warns_666"
PERM_FILE="$REPO_ROOT/.chezmoitemplates/aliases/permission/permission.aliases.sh"
assert_file_contains "$PERM_FILE" "WARNING: 666" "should warn about 666 permissions"

test_start "permission_warns_777"
assert_file_contains "$PERM_FILE" "WARNING: 777" "should warn about 777 permissions"

# Test: backup.sh has error handling
test_start "backup_error_handling"
BACKUP_FILE="$REPO_ROOT/scripts/security/backup.sh"
assert_file_contains "$BACKUP_FILE" "Backup failed" "should have error handling"

# Test: age-init.sh uses json.dumps for escaping
test_start "age_init_json_escaping"
AGE_FILE="$REPO_ROOT/scripts/secrets/age-init.sh"
assert_file_contains "$AGE_FILE" "json.dumps" "should use json.dumps for escaping"

print_summary
