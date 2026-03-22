#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioral tests for dot_confirm_destructive from dot_config/shell/05-core-safety.sh.
#
# Behaviors under test:
#   - Returns 0 immediately when strict mode is off (default).
#   - Blocks (returns 1) in strict mode with non-interactive (no TTY) stdin.
#   - Allows (returns 0) in strict mode when DOTFILES_FORCE_DESTRUCTIVE=1 (no TTY).
#   - Logs to the destruction log when force-proceeding.
#   - Custom action description appears in output.
#   - Blocks when stdin is /dev/null (non-interactive piped context).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"

FUNC_FILE="$REPO_ROOT/dot_config/shell/05-core-safety.sh"
if [[ ! -f "$FUNC_FILE" ]]; then
  echo "SKIP: 05-core-safety.sh not found at $FUNC_FILE"
  echo "RESULTS:0:0:0"
  exit 0
fi
source "$FUNC_FILE" 2>/dev/null || {
  echo "SKIP: could not source 05-core-safety.sh"
  echo "RESULTS:0:0:0"
  exit 0
}

mock_init
TMP_LOG=$(mktemp)

# ──────────────────────────────────────────────────────────────────────────────
# 1. Strict mode OFF → always returns 0 regardless of TTY
# ──────────────────────────────────────────────────────────────────────────────
test_start "confirm_destructive_strict_mode_off_returns_0"
DOTFILES_ALIAS_STRICT_MODE=0
dot_confirm_destructive "test action" </dev/null 2>/dev/null
assert_equals "0" "$?" "strict mode off should always return 0"

# ──────────────────────────────────────────────────────────────────────────────
# 2. Default (no strict mode var set) → returns 0
# ──────────────────────────────────────────────────────────────────────────────
test_start "confirm_destructive_default_no_strict_mode"
unset DOTFILES_ALIAS_STRICT_MODE
dot_confirm_destructive "default test" </dev/null 2>/dev/null
assert_equals "0" "$?" "without DOTFILES_ALIAS_STRICT_MODE, should return 0"

# ──────────────────────────────────────────────────────────────────────────────
# 3. Strict mode ON + no TTY (stdin=/dev/null) → returns 1 (blocked)
# ──────────────────────────────────────────────────────────────────────────────
test_start "confirm_destructive_strict_blocks_without_tty"
DOTFILES_ALIAS_STRICT_MODE=1
DOTFILES_FORCE_DESTRUCTIVE=0
DOTFILES_DESTRUCTIVE_LOG="$TMP_LOG"
dot_confirm_destructive "rm -rf /tmp/test" </dev/null 2>/dev/null
assert_equals "1" "$?" "strict mode + no TTY should return 1 (blocked)"

# ──────────────────────────────────────────────────────────────────────────────
# 4. Strict mode ON + no TTY → prints STRICT message to stderr
# ──────────────────────────────────────────────────────────────────────────────
test_start "confirm_destructive_strict_prints_message"
DOTFILES_ALIAS_STRICT_MODE=1
DOTFILES_FORCE_DESTRUCTIVE=0
DOTFILES_DESTRUCTIVE_LOG="$TMP_LOG"
err_output=$(dot_confirm_destructive "dangerous rm" </dev/null 2>&1)
assert_contains "STRICT" "$err_output" "blocked action should print [STRICT] message"

# ──────────────────────────────────────────────────────────────────────────────
# 5. Strict mode ON + no TTY → error message includes the action description
# ──────────────────────────────────────────────────────────────────────────────
test_start "confirm_destructive_strict_message_includes_action"
DOTFILES_ALIAS_STRICT_MODE=1
DOTFILES_FORCE_DESTRUCTIVE=0
DOTFILES_DESTRUCTIVE_LOG="$TMP_LOG"
err_output=$(dot_confirm_destructive "my custom action" </dev/null 2>&1)
assert_contains "my custom action" "$err_output" "error message should include the action description"

# ──────────────────────────────────────────────────────────────────────────────
# 6. DOTFILES_FORCE_DESTRUCTIVE=1 + no TTY → returns 0 (force override)
# ──────────────────────────────────────────────────────────────────────────────
test_start "confirm_destructive_force_flag_bypasses_block"
DOTFILES_ALIAS_STRICT_MODE=1
DOTFILES_FORCE_DESTRUCTIVE=1
DOTFILES_DESTRUCTIVE_LOG="$TMP_LOG"
dot_confirm_destructive "forced action" </dev/null 2>/dev/null
assert_equals "0" "$?" "DOTFILES_FORCE_DESTRUCTIVE=1 should bypass block and return 0"

# ──────────────────────────────────────────────────────────────────────────────
# 7. Force override logs the action to the destruction log
# ──────────────────────────────────────────────────────────────────────────────
test_start "confirm_destructive_force_writes_log"
> "$TMP_LOG"   # truncate log
DOTFILES_ALIAS_STRICT_MODE=1
DOTFILES_FORCE_DESTRUCTIVE=1
DOTFILES_DESTRUCTIVE_LOG="$TMP_LOG"
dot_confirm_destructive "logged action" </dev/null 2>/dev/null
assert_file_contains "$TMP_LOG" "logged action" "force-proceeded action should be written to log"

# ──────────────────────────────────────────────────────────────────────────────
# 8. Force override log entry includes "forced" mode marker
# ──────────────────────────────────────────────────────────────────────────────
test_start "confirm_destructive_force_log_has_forced_marker"
> "$TMP_LOG"
DOTFILES_ALIAS_STRICT_MODE=1
DOTFILES_FORCE_DESTRUCTIVE=1
DOTFILES_DESTRUCTIVE_LOG="$TMP_LOG"
dot_confirm_destructive "marker test" </dev/null 2>/dev/null
assert_file_contains "$TMP_LOG" "forced" "log entry should contain 'forced' mode marker"

# ──────────────────────────────────────────────────────────────────────────────
# 9. Default action description used when no argument provided
# ──────────────────────────────────────────────────────────────────────────────
test_start "confirm_destructive_default_action_description"
DOTFILES_ALIAS_STRICT_MODE=1
DOTFILES_FORCE_DESTRUCTIVE=0
DOTFILES_DESTRUCTIVE_LOG="$TMP_LOG"
err_output=$(dot_confirm_destructive </dev/null 2>&1)
# The function defaults action to "destructive operation"
assert_contains "destructive operation" "$err_output" "default action description should be 'destructive operation'"

# ──────────────────────────────────────────────────────────────────────────────
# 10. Strict mode is re-checked at call time (not cached)
# ──────────────────────────────────────────────────────────────────────────────
test_start "confirm_destructive_strict_mode_dynamic"
DOTFILES_ALIAS_STRICT_MODE=1
DOTFILES_FORCE_DESTRUCTIVE=0
DOTFILES_DESTRUCTIVE_LOG="$TMP_LOG"
# First call: blocked
dot_confirm_destructive "action A" </dev/null 2>/dev/null
first_rc=$?
# Disable strict mode
DOTFILES_ALIAS_STRICT_MODE=0
# Second call: should now be allowed
dot_confirm_destructive "action B" </dev/null 2>/dev/null
second_rc=$?
assert_equals "1" "$first_rc" "first call (strict on) should return 1"
assert_equals "0" "$second_rc" "second call (strict off) should return 0"

# Cleanup
rm -f "$TMP_LOG"
mock_cleanup

echo ""
echo "dot_confirm_destructive behavioral tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
