#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

CONF_FILE="$REPO_ROOT/defaults/dot_config/fish/conf.d/aliases.fish.tmpl"
CAT_FUNCTION_FILE="$REPO_ROOT/defaults/dot_config/fish/functions/cat.fish"

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

# cat.fish picks bat, then batcat, then the system cat. Each case runs the
# function in fish with a PATH holding only the stubs for that case.
CAT_TMP="$(mktemp -d)"
trap 'rm -rf "$CAT_TMP"' EXIT
printf 'hello\n' >"$CAT_TMP/file"
FISH_BIN="$(command -v fish || true)"
fish_cat() {
  local bin="$CAT_TMP/bin-$1" tool
  mkdir -p "$bin"
  # Only the real cat plus this case's stubs: /usr/bin may hold batcat.
  ln -sf "$(command -v cat)" "$bin/cat"
  shift
  for tool in "$@"; do
    printf '#!/bin/sh\necho "%s $*"\n' "$tool" >"$bin/$tool"
    chmod +x "$bin/$tool"
  done
  # shellcheck disable=SC2016
  PATH="$bin" "$FISH_BIN" --no-config -c 'source $argv[1]; cat $argv[2]' "$CAT_FUNCTION_FILE" "$CAT_TMP/file" 2>&1
}
for case in "prefers_bat:bat batcat:bat $CAT_TMP/file" "falls_back_to_batcat:batcat:batcat $CAT_TMP/file" "falls_back_to_system_cat::hello"; do
  IFS=: read -r name tools want <<<"$case"
  test_start "fish_cat_${name}"
  if [[ -n "$FISH_BIN" ]]; then
    # shellcheck disable=SC2086 # tools is a word list on purpose
    assert_equals "$want" "$(fish_cat "$name" $tools)" "cat with: ${tools:-no bat}"
  else
    assert_true "true" "fish not installed; skipped"
  fi
done

test_start "fish_alias_bridge_skips_bash_only_dot_helpers"
assert_file_contains "$CONF_FILE" "string match -rq '^dot_[a-z0-9_]+\$'" "fish alias bridge skips dot_ helper targets"

test_start "fish_alias_bridge_cleans_stale_cat_wrapper"
assert_file_contains "$CONF_FILE" "if functions -q cat; and not functions -q dot_cat" "fish aliases clean stale cat wrapper"
assert_file_contains "$CONF_FILE" "functions -e cat" "fish aliases erase stale cat wrapper"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
