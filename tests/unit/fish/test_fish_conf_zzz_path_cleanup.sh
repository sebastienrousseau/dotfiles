#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

CONF_FILE="$REPO_ROOT/defaults/dot_config/fish/conf.d/zzz-path-cleanup.fish"

test_start "fish_conf_zzz_path_cleanup_exists"
assert_file_exists "$CONF_FILE" "zzz-path-cleanup.fish should exist"

test_start "fish_conf_zzz_path_cleanup_not_empty"
if [[ -s "$CONF_FILE" ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: not empty"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should not be empty"
fi

test_start "fish_conf_zzz_path_cleanup_no_bash_syntax"
if ! grep -qE '^\s*(if \[\[|then$|fi$|esac$|done$)' "$CONF_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no bash syntax"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: contains bash syntax"
fi

# Duplicates collapse to their first position and missing directories go;
# the result must still be exported to child processes.
test_start "fish_conf_zzz_path_cleanup_dedup_logic"
if FISH_BIN="$(command -v fish)"; then
  PC_TMP="$(mktemp -d)"
  mkdir -p "$PC_TMP/a" "$PC_TMP/b"
  # shellcheck disable=SC2016
  got="$("$FISH_BIN" --no-config -c '
    set -gx PATH $argv[1]/a $argv[1]/gone $argv[1]/b $argv[1]/a /usr/bin $argv[1]/b /bin
    source $argv[2]
    /usr/bin/env | string match -r "^PATH=.*" | string replace "PATH=" ""' "$PC_TMP" "$CONF_FILE" 2>&1)"
  assert_equals "$PC_TMP/a:$PC_TMP/b:/usr/bin:/bin" "$got" "exported PATH is deduplicated, pruned and ordered"
  rm -rf "$PC_TMP"
else
  assert_true "true" "fish not installed; skipped"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
