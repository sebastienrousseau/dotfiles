#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Tests for global standards synchronization utility (standards-sync) and defaults/Code

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

SYNC_BIN="$REPO_ROOT/defaults/dot_local/bin/executable_standards-sync"
SENTINEL_ZSH="$REPO_ROOT/defaults/dot_config/zsh/rc.d/45-standards.zsh"

if [[ -x /usr/bin/python3 ]]; then
  PYTHON_BIN="/usr/bin/python3"
elif command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="$(command -v python3)"
else
  PYTHON_BIN="python3"
fi

STANDARD_FILES=(
  "AGENTS.md"
  "GEMINI.md"
  "PR-TEMPLATE.md"
  "README-TEMPLATE.md"
  "REPO-STANDARD.md"
)

# 1. Verify standard files present and non-empty in defaults/Code
for file in "${STANDARD_FILES[@]}"; do
  test_start "standards_${file//./_}_present"
  target="$REPO_ROOT/defaults/Code/$file"
  if [[ -f "$target" && -s "$target" ]]; then
    ((TESTS_PASSED++))
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: defaults/Code/$file exists and is non-empty"
  else
    ((TESTS_FAILED++))
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: defaults/Code/$file is missing or empty"
  fi
done

# 2. Verify executable_standards-sync binary exists and is executable
test_start "bin_standards_sync_executable"
if [[ -f "$SYNC_BIN" && -x "$SYNC_BIN" ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: standards-sync executable exists and has +x permission"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: standards-sync binary is missing or not executable"
fi

# 3. Verify standards-sync --help
test_start "standards_sync_help"
help_out="$("$PYTHON_BIN" "$SYNC_BIN" --help 2>&1)" || true
assert_contains "Standards synchronization and integrity verification utility" "$help_out" "help describes utility"
assert_contains "--check" "$help_out" "help lists --check flag"

# 4. Verify standards-sync behavior in an isolated sandbox
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/standards-sync-test.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT

SRC_DIR="$SANDBOX/src"
TARGET_DIR="$SANDBOX/target"
mkdir -p "$SRC_DIR" "$TARGET_DIR"

for f in "${STANDARD_FILES[@]}"; do
  printf 'content of %s\n' "$f" >"$SRC_DIR/$f"
  cp "$SRC_DIR/$f" "$TARGET_DIR/$f"
done

test_start "standards_sync_check_clean"
check_clean_out="$(STANDARDS_REPO="$SRC_DIR" STANDARDS_TARGETS="$TARGET_DIR" "$PYTHON_BIN" "$SYNC_BIN" --check 2>&1)"
clean_status=$?
assert_equals "0" "$clean_status" "check returns 0 when clean"
assert_contains "All standards are synchronized" "$check_clean_out" "reports clean sync"

test_start "standards_sync_drift_detected"
# Induce drift in a target file
printf 'drifted content\n' >"$TARGET_DIR/AGENTS.md"
drift_status=0
drift_out="$(STANDARDS_REPO="$SRC_DIR" STANDARDS_TARGETS="$TARGET_DIR" "$PYTHON_BIN" "$SYNC_BIN" --check 2>&1)" || drift_status=$?
assert_equals "1" "$drift_status" "check returns 1 when drifted"
assert_contains "DRIFTED" "$drift_out" "reports drifted file"

test_start "standards_sync_quiet_drift"
quiet_status=0
quiet_out="$(STANDARDS_REPO="$SRC_DIR" STANDARDS_TARGETS="$TARGET_DIR" "$PYTHON_BIN" "$SYNC_BIN" --check --quiet 2>&1)" || quiet_status=$?
assert_equals "1" "$quiet_status" "quiet check returns 1 when drifted"
assert_contains "Drift detected" "$quiet_out" "quiet mode outputs drift warning"

test_start "standards_sync_push_repair"
push_out="$(STANDARDS_REPO="$SRC_DIR" STANDARDS_TARGETS="$TARGET_DIR" "$PYTHON_BIN" "$SYNC_BIN" --push 2>&1)"
push_status=$?
assert_equals "0" "$push_status" "push sync returns 0"
assert_contains "Push synchronization complete" "$push_out" "push completes"

# Verify target AGENTS.md is restored
restored_diff="$(diff -u "$SRC_DIR/AGENTS.md" "$TARGET_DIR/AGENTS.md" 2>&1 || true)"
assert_equals "" "$restored_diff" "target AGENTS.md matches source after push"

# 5. Verify 45-standards.zsh sentinel exists and is valid shell syntax
test_start "standards_sentinel_syntax"
if [[ -f "$SENTINEL_ZSH" ]]; then
  if ! command -v zsh >/dev/null 2>&1 || zsh -n "$SENTINEL_ZSH" 2>/dev/null; then
    ((TESTS_PASSED++))
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: 45-standards.zsh exists and has valid shell syntax"
  else
    ((TESTS_FAILED++))
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: 45-standards.zsh syntax error"
  fi
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: 45-standards.zsh is missing"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
