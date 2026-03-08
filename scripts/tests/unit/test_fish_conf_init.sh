#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

CONF_FILE="$REPO_ROOT/dot_config/fish/conf.d/init.fish.tmpl"

test_start "fish_conf_init_exists"
assert_file_exists "$CONF_FILE" "init.fish.tmpl should exist"

test_start "fish_conf_init_not_empty"
if [[ -s "$CONF_FILE" ]]; then
  ((TESTS_PASSED++)); printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: not empty"
else
  ((TESTS_FAILED++)); printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should not be empty"
fi

test_start "fish_conf_init_no_bash_syntax"
if ! grep -qE '^\s*(if \[\[|then$|fi$|esac$|done$)' "$CONF_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)); printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no bash syntax"
else
  ((TESTS_FAILED++)); printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: contains bash syntax"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
