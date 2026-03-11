#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

CONF_FILE="$REPO_ROOT/dot_config/fish/conf.d/env.fish.tmpl"

test_start "fish_conf_env_has_fzf_exists"
assert_file_exists "$CONF_FILE" "env.fish.tmpl should exist"

test_start "fish_conf_env_has_fzf_not_empty"
if [[ -s "$CONF_FILE" ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: not empty"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should not be empty"
fi

test_start "fish_conf_env_has_fzf_default_command"
if grep -q 'FZF_DEFAULT_COMMAND' "$CONF_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: contains FZF_DEFAULT_COMMAND"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should contain FZF_DEFAULT_COMMAND"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
