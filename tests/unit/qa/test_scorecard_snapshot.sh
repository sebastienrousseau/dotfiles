#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Test: scripts/qa/scorecard-snapshot.sh
#
# Verifies the snapshot script is syntactically valid, accepts
# the documented flags, and refuses unknown ones.
#
# Network-dependent assertions are SKIPPED — the script fetches
# api.scorecard.dev which CI runners may not reach.
# shellcheck disable=SC1090,SC1091,SC2034

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/cmd_test_helpers.sh"

SCRIPT="$REPO_ROOT/scripts/qa/scorecard-snapshot.sh"

if [[ -x "$SCRIPT" ]]; then
  _pass "script_exists"
else
  _fail_named "script_exists" "not found"
  _cmd_finish
  exit 1
fi

if bash -n "$SCRIPT" 2>/dev/null; then
  _pass "syntax_valid"
else
  _fail_named "syntax_valid" "bash -n failed"
fi

if bash "$SCRIPT" --help 2>&1 | grep -q 'Fetch'; then
  _pass "help_flag_works"
else
  _fail_named "help_flag_works" "no Fetch line in help"
fi

if ! bash "$SCRIPT" --invalid-flag 2>/dev/null; then
  _pass "rejects_invalid_flag"
else
  _fail_named "rejects_invalid_flag" "should exit non-zero"
fi

_cmd_finish
