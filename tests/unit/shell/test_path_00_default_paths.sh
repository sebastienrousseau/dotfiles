#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

# Legacy .chezmoitemplates/paths/00-default.paths.sh removed;
# PATH construction now lives in 00-core-paths.sh.tmpl.
PATH_FILE="$REPO_ROOT/defaults/dot_config/shell/00-core-paths.sh.tmpl"

test_start "core_paths_file_exists"
assert_file_exists "$PATH_FILE" "core paths file should exist"

test_start "core_paths_has_path_prepend"
if grep -q 'path_prepend' "$PATH_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
