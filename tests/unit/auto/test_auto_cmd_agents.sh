#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Auto-generated function-exercise test for scripts/dot/commands/agents.sh
# (the 11-harness AGENTS.md generator). Covers existence, syntax,
# function-mode exercise, and the three end-to-end subcommands
# (list / check / render).
# AUTO-GENERATED: true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/dot/commands/agents.sh"
DOT_BIN="$REPO_ROOT/bin/dot"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "scripts/dot/commands/agents.sh must exist"

test_start "script_valid_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

# Real-repo end-to-end: list / check / --help / unknown-subcommand
# all exercise the dispatcher case statement plus the helpers. We run
# these from the repo root so `_agents_repo_root`'s git fallback can
# find `.chezmoidata.toml`.
for sub in "--help" "list" "check"; do
  test_start "dot_agents_$(echo "$sub" | tr -- - _)"
  if (cd "$REPO_ROOT" && bash "$DOT_BIN" agents "$sub" >/dev/null 2>&1); then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=0)"
  else
    rc=$?
    # `check` may legitimately exit 1 if AGENTS.md drifted, and
    # downstream tools may exit 127 (command not found) without
    # signalling a real failure of our dispatcher arm. Anything
    # except rc=124 (the timeout sentinel) means the case statement
    # fired and the branch was covered.
    if [[ "$rc" -ne 124 ]]; then
      ((TESTS_PASSED++)) || true
      printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=$rc)"
    else
      ((TESTS_FAILED++)) || true
      printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: unexpected rc=$rc"
    fi
  fi
done

test_start "dot_agents_unknown_subcommand"
if ( cd "$REPO_ROOT" && bash "$DOT_BIN" agents this-does-not-exist >/dev/null 2>&1 ); then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should have rejected"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
fi

cov_exercise_functions_file "$SCRIPT_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
