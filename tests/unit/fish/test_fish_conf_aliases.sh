#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

CONF_FILE="$REPO_ROOT/dot_config/fish/conf.d/aliases.fish.tmpl"
CAT_FUNCTION_FILE="$REPO_ROOT/dot_config/fish/functions/cat.fish"

test_start "fish_conf_aliases_exists"
assert_file_exists "$CONF_FILE" "aliases.fish.tmpl should exist"

test_start "fish_conf_aliases_not_empty"
if [[ -s "$CONF_FILE" ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: not empty"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should not be empty"
fi

test_start "fish_conf_aliases_has_fish_syntax"
if grep -qE '^\s*(function |end$|set |if .*; and)' "$CONF_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: contains fish syntax"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should contain fish syntax"
fi

test_start "fish_cat_function_exists"
assert_file_exists "$CAT_FUNCTION_FILE" "cat.fish should exist"

test_start "fish_cat_function_uses_bat_fallback"
assert_file_contains "$CAT_FUNCTION_FILE" "function cat" "cat.fish defines cat function"
assert_file_contains "$CAT_FUNCTION_FILE" "command -v bat" "cat.fish checks for bat"
assert_file_contains "$CAT_FUNCTION_FILE" "command cat" "cat.fish falls back to system cat"

test_start "fish_alias_bridge_skips_bash_only_dot_helpers"
assert_file_contains "$CONF_FILE" "string match -rq '^dot_[a-z0-9_]+\$'" "fish alias bridge skips dot_ helper targets"

test_start "fish_alias_bridge_cleans_stale_cat_wrapper"
assert_file_contains "$CONF_FILE" "if functions -q cat; and not functions -q dot_cat" "fish aliases clean stale cat wrapper"
assert_file_contains "$CONF_FILE" "functions -e cat" "fish aliases erase stale cat wrapper"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
