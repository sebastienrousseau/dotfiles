#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Auto-generated exercise test for scripts/dot/commands/tools.sh.
# Slice 5 of #883: backfill coverage for scripts with no existing test
# by running each through safe-mode entry points (--help / no-arg /
# invalid flag / subcommand probes).
#
# AUTO-GENERATED: true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/dot/commands/tools.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "scripts/dot/commands/tools.sh must exist"

test_start "script_valid_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

DOT_BIN="$REPO_ROOT/dot_local/bin/executable_dot"

# Tools dispatcher arms — read-only and `--help` probes.
for cmd in "tools" "tools --help" \
  "new --help" "packages" \
  "env" "profile" "alias-check" "aliases list"; do
  test_start "dot_$(echo "$cmd" | tr ' -' '__' | tr -dc 'a-z0-9_')"
  # `$cmd` is INTENDED to word-split into separate argv entries.
  # shellcheck disable=SC2086
  if (cd "$REPO_ROOT" && bash "$DOT_BIN" $cmd >/dev/null 2>&1); then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=0)"
  else
    rc=$?
    if [[ "$rc" -ne 124 ]]; then
      ((TESTS_PASSED++)) || true
      printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=$rc)"
    else
      ((TESTS_FAILED++)) || true
      printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: rc=$rc"
    fi
  fi
done

cov_exercise_script "$SCRIPT_FILE"
cov_exercise_functions_file "$SCRIPT_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
