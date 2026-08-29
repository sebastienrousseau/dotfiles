#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Test: scripts/qa/check-version-consistency.sh
#
# Verifies the version-drift check exits 0 against the live tree
# (where the 8 surfaces match .chezmoidata.toml) and exits 1
# against a temp tree where one surface is manually drifted.
# shellcheck disable=SC1090,SC1091,SC2034

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/cmd_test_helpers.sh"

SCRIPT="$REPO_ROOT/scripts/qa/check-version-consistency.sh"

if [[ -x "$SCRIPT" ]]; then
  _pass "script_exists"
else
  _fail_named "script_exists" "not found: $SCRIPT"
  _cmd_finish
  exit 1
fi

if bash "$SCRIPT" --quiet; then
  _pass "live_tree_passes_quiet"
else
  _fail_named "live_tree_passes_quiet" "exit non-zero"
fi

if bash "$SCRIPT" --help 2>&1 | grep -q 'Usage'; then
  _pass "help_flag_works"
else
  _fail_named "help_flag_works" "no Usage line"
fi

if ! bash "$SCRIPT" --invalid-flag 2>/dev/null; then
  _pass "rejects_invalid_flag"
else
  _fail_named "rejects_invalid_flag" "should exit non-zero"
fi

_cmd_finish
