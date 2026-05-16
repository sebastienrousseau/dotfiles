#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Auto-generated function-exercise test for scripts/dot/commands/ai.sh.
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

SCRIPT_FILE="$REPO_ROOT/scripts/dot/commands/ai.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "scripts/dot/commands/ai.sh must exist"

test_start "script_valid_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

# Dispatcher arms — exercise the read-only AI subcommands plus every
# bridge `--help` so the per-CLI case branches in run_ai_with_context
# get traced. None of these reach the actual AI CLI; they all hit the
# "not installed / show help" path which is the most common branch
# users encounter.
DOT_BIN="$REPO_ROOT/dot_local/bin/executable_dot"

for cmd in "ai" "ai-setup --help" "ai-query --help" \
  "cl --help" "claude --help" "codex --help" "copilot --help" \
  "gemini --help" "goose --help" "kiro --help" "sgpt --help" \
  "ollama --help" "opencode --help" "aider --help"; do
  test_start "dot_$(echo "$cmd" | tr ' -' '__' | tr -dc 'a-z0-9_')"
  # `$cmd` is INTENDED to word-split into separate argv entries
  # (e.g. `ai-setup --help` → `ai-setup`, `--help`). Quoting would
  # pass the whole string as one positional arg.
  # shellcheck disable=SC2086
  if (cd "$REPO_ROOT" && bash "$DOT_BIN" $cmd >/dev/null 2>&1); then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=0)"
  else
    rc=$?
    if [[ "$rc" -lt 125 ]]; then
      ((TESTS_PASSED++)) || true
      printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=$rc)"
    else
      ((TESTS_FAILED++)) || true
      printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: rc=$rc"
    fi
  fi
done

cov_exercise_functions_file "$SCRIPT_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
