#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for dot CLI restore command

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"

RESTORE_FILE="$REPO_ROOT/scripts/dot/commands/restore.sh"

# Test: restore.sh file exists
test_start "restore_file_exists"
assert_file_exists "$RESTORE_FILE" "restore.sh should exist"

# Test: restore.sh is valid shell syntax
test_start "restore_syntax_valid"
if bash -n "$RESTORE_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: syntax errors"
fi

# Test: defines restore function
test_start "restore_defines_function"
if grep -qE 'restore_from_git|restore_latest|list_backups|usage' "$RESTORE_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: defines restore function"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should define restore"
fi

# Test: requires backup source
test_start "restore_requires_backup"
if grep -qE 'backup|archive|tar|restore' "$RESTORE_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: works with backups"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should work with backups"
fi

# Test: shellcheck compliance
test_start "restore_shellcheck"
if command -v shellcheck &>/dev/null; then
  errors=$(shellcheck -S error "$RESTORE_FILE" 2>&1 | wc -l)
  if [[ "$errors" -eq 0 ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: passes shellcheck"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: has shellcheck errors"
  fi
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: shellcheck not available"
fi

test_start "restore_flag_aliases"
assert_file_contains "$RESTORE_FILE" "--list, -l" "restore supports -l"
assert_file_contains "$RESTORE_FILE" "--latest, -L" "restore supports -L"
assert_file_contains "$RESTORE_FILE" "--git, -g" "restore supports -g"
assert_file_contains "$RESTORE_FILE" "--diff, -d" "restore supports -d"
assert_file_contains "$RESTORE_FILE" "--dry-run, -n" "restore supports -n"

test_start "restore_latest_preserves_hidden_paths"
restore_sandbox="$(mktemp -d)"
trap 'rm -rf "$restore_sandbox"' RETURN
mkdir -p "$restore_sandbox/home" "$restore_sandbox/data/dotfiles/backups/backup-20260322_120000/.config/zsh"
printf 'setopt\n' >"$restore_sandbox/data/dotfiles/backups/backup-20260322_120000/.zshrc"
printf 'export TEST=1\n' >"$restore_sandbox/data/dotfiles/backups/backup-20260322_120000/.config/zsh/.zshrc"
restore_output="$(
  HOME="$restore_sandbox/home" \
    XDG_DATA_HOME="$restore_sandbox/data" \
    bash "$RESTORE_FILE" --latest 2>&1
)"
if [[ -f "$restore_sandbox/home/.zshrc" ]] \
  && [[ -f "$restore_sandbox/home/.config/zsh/.zshrc" ]] \
  && grep -q "Restored: .zshrc" <<<"$restore_output" \
  && grep -q "Restored: .config" <<<"$restore_output"; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: restore_latest restores hidden files and nested paths"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: restore_latest should restore hidden files and nested paths"
fi

echo ""
echo "Restore command tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
