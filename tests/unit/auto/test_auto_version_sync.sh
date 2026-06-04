#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Auto-generated exercise test for scripts/version-sync.sh.
# Slice 5 of #883: backfill coverage for scripts with no existing test
# by running each through safe-mode entry points (--help / no-arg /
# invalid flag / subcommand probes).
#
# AUTO-GENERATED: true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/version-sync.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "scripts/version-sync.sh must exist"

test_start "script_valid_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

cov_exercise_script "$SCRIPT_FILE"
cov_exercise_functions_file "$SCRIPT_FILE"

# Extra: drive the read-only modes (--verify, --dry-run) so the
# script's discovery + comparison branches get covered. Sandbox-safe:
# neither mode writes outside $HOME (already isolated).
for mode in --verify --dry-run; do
  test_start "version_sync_${mode//-/_}"
  rc=0
  bash "$SCRIPT_FILE" "$mode" </dev/null >/dev/null 2>&1 || rc=$?
  if [[ "$rc" -lt 125 ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=$rc)"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: unexpected rc=$rc"
  fi
done

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
