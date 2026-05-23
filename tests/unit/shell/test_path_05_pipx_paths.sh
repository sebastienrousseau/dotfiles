#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

# Legacy .chezmoitemplates/paths/05-pipx.paths.sh removed;
# PIPX config now lives in 00-core-paths.sh.tmpl.
PATH_FILE="$REPO_ROOT/defaults/dot_config/shell/00-core-paths.sh.tmpl"

test_start "core_paths_has_pipx"
if grep -q 'PIPX' "$PATH_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: PIPX configured in core paths"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: PIPX should be configured"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
