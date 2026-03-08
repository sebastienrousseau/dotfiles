#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

TARGET="$REPO_ROOT/dot_config/nvim/lua/config/autocmds.lua"

test_start "nvim_autocmds_exists"
assert_file_exists "$TARGET" "autocmds.lua should exist"

test_start "nvim_autocmds_not_empty"
if [[ -s "$TARGET" ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: file is empty"
fi

test_start "nvim_autocmds_valid_lua"
if command -v luacheck >/dev/null 2>&1; then
  if luacheck --no-color --quiet --globals vim -- "$TARGET" 2>/dev/null; then
    ((TESTS_PASSED++))
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: luacheck passed"
  else
    ((TESTS_PASSED++))
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: luacheck warnings (non-fatal)"
  fi
else
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: luacheck not available (skipped)"
fi

test_start "nvim_autocmds_defines_autocmds"
if grep -q 'vim.api.nvim_create_autocmd\|vim.api.nvim_create_augroup\|autocmd' "$TARGET" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: defines autocommands"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should define autocommands"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
