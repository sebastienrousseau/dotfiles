#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Auto-generated function-exercise test for scripts/dot/commands/fleet.sh.
# These dot command files are sourced by the dispatcher; their case
# arms only execute when a specific subcommand fires. To cover the
# internal helper functions defined alongside the dispatch we source
# the file directly and invoke each name.
#
# AUTO-GENERATED: true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/dot/commands/fleet.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "scripts/dot/commands/fleet.sh must exist"

test_start "script_valid_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

cov_exercise_functions_file "$SCRIPT_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
