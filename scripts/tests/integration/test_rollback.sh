#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2030,SC2031
# Integration tests for scripts/ops/rollback.sh
# Tests backup creation, restore, cleanup, and path traversal protection
# SC2030/SC2031: subshell env overrides (HOME, XDG_*) are intentional

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../framework/assertions.sh"

ROLLBACK_SCRIPT="$REPO_ROOT/scripts/ops/rollback.sh"

# ── Script existence and structure ──────────────────────────────

test_start "rollback_script_exists"
assert_file_exists "$ROLLBACK_SCRIPT" "rollback.sh should exist"

test_start "rollback_script_executable"
if [[ -x "$ROLLBACK_SCRIPT" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: rollback.sh is executable"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: rollback.sh should be executable"
fi

test_start "rollback_script_shebang"
first_line=$(head -n 1 "$ROLLBACK_SCRIPT")
assert_equals "#!/usr/bin/env bash" "$first_line" "rollback.sh should have bash shebang"

test_start "rollback_script_strict_mode"
if grep -q 'set -euo pipefail' "$ROLLBACK_SCRIPT"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: rollback.sh uses strict mode"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: rollback.sh should use set -euo pipefail"
fi

# ── Help and usage ──────────────────────────────────────────────

test_start "rollback_help_output"
help_output=$(bash "$ROLLBACK_SCRIPT" help 2>&1) || true
if echo "$help_output" | grep -q "Dotfiles Rollback"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: help shows Dotfiles Rollback header"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: help should show Dotfiles Rollback header"
  echo -e "    Got: '$help_output'"
fi

test_start "rollback_help_lists_commands"
for cmd in status backup rollback restore clean; do
  if ! echo "$help_output" | grep -q "$cmd"; then
    ((TESTS_FAILED++))
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: help should list '$cmd' command"
    break
  fi
done
if echo "$help_output" | grep -q "clean"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: help lists all expected commands"
fi

# ── Functional: backup & restore in temp sandbox ────────────────

SANDBOX_HOME=$(mktemp -d)
SANDBOX_BACKUP_DIR="$SANDBOX_HOME/.local/share/dotfiles/backups"
trap 'rm -rf "$SANDBOX_HOME"' EXIT

# Create fake dotfiles in the sandbox HOME
mkdir -p "$SANDBOX_HOME/.config/shell"
echo "# test bashrc" >"$SANDBOX_HOME/.bashrc"
echo "# test zshrc" >"$SANDBOX_HOME/.zshrc"
echo "# test shell config" >"$SANDBOX_HOME/.config/shell/test.sh"

test_start "rollback_backup_creates_directory"
# Run backup with sandbox HOME — we need to override HOME and backup dir
(
  export HOME="$SANDBOX_HOME"
  export XDG_DATA_HOME="$SANDBOX_HOME/.local/share"
  export XDG_STATE_HOME="$SANDBOX_HOME/.local/state"
  # Source just the functions we need by running backup with --force
  bash "$ROLLBACK_SCRIPT" backup --force 2>&1
) >/dev/null 2>&1 || true

if [[ -d "$SANDBOX_BACKUP_DIR" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: backup command creates backup directory"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: backup should create backup directory at $SANDBOX_BACKUP_DIR"
fi

test_start "rollback_backup_contains_files"
backup_count=$(find "$SANDBOX_BACKUP_DIR" -name "backup_*" -type d 2>/dev/null | wc -l | tr -d ' ')
if [[ "$backup_count" -ge 1 ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: at least one backup was created"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should have at least one backup directory"
fi

test_start "rollback_backup_has_metadata"
meta_count=$(find "$SANDBOX_BACKUP_DIR" -name ".backup_meta" 2>/dev/null | wc -l | tr -d ' ')
if [[ "$meta_count" -ge 1 ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: backup includes metadata file"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: backup should include .backup_meta"
fi

# ── Dry-run mode ────────────────────────────────────────────────

test_start "rollback_dryrun_no_changes"
original_bashrc=$(cat "$SANDBOX_HOME/.bashrc")
(
  export HOME="$SANDBOX_HOME"
  export XDG_DATA_HOME="$SANDBOX_HOME/.local/share"
  export XDG_STATE_HOME="$SANDBOX_HOME/.local/state"
  bash "$ROLLBACK_SCRIPT" rollback --force --dry-run 2>&1
) >/dev/null 2>&1 || true
current_bashrc=$(cat "$SANDBOX_HOME/.bashrc")
assert_equals "$original_bashrc" "$current_bashrc" "dry-run should not modify files"

# ── Path traversal protection ───────────────────────────────────

test_start "rollback_path_traversal_rejected"
restore_output=$(
  export HOME="$SANDBOX_HOME"
  export XDG_DATA_HOME="$SANDBOX_HOME/.local/share"
  export XDG_STATE_HOME="$SANDBOX_HOME/.local/state"
  bash "$ROLLBACK_SCRIPT" restore "../../etc/passwd" --force 2>&1
) || true
if echo "$restore_output" | grep -qi "traversal\|error\|not found"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: path traversal attempt is rejected"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: path traversal should be rejected"
  echo -e "    Got: '$restore_output'"
fi

# ── Unknown command handling ────────────────────────────────────

test_start "rollback_unknown_command"
unknown_output=$(bash "$ROLLBACK_SCRIPT" nonexistent-command 2>&1) || true
exit_code=$?
if echo "$unknown_output" | grep -qi "unknown"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: unknown command is rejected"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should reject unknown commands"
  echo -e "    Exit code: $exit_code, Output: '$unknown_output'"
fi

# ── Status command ──────────────────────────────────────────────

test_start "rollback_status_runs"
status_output=$(
  export HOME="$SANDBOX_HOME"
  export XDG_DATA_HOME="$SANDBOX_HOME/.local/share"
  export XDG_STATE_HOME="$SANDBOX_HOME/.local/state"
  bash "$ROLLBACK_SCRIPT" status 2>&1
) || true
if echo "$status_output" | grep -qi "rollback\|status\|backup"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: status command produces output"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: status should produce readable output"
fi

# ── Summary ─────────────────────────────────────────────────────
echo ""
echo "Integration tests (rollback): $TESTS_PASSED passed, $TESTS_FAILED failed (of $TESTS_RUN)"
[[ $TESTS_FAILED -eq 0 ]] || exit 1
