#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

TEST_SCRIPT="$REPO_ROOT/scripts/diagnostics/a2a-conformance.sh"
DOT_CLI="$REPO_ROOT/dot_local/bin/executable_dot"

test_start "a2a_conformance_exists"
assert_file_exists "$TEST_SCRIPT" "a2a-conformance.sh should exist"

test_start "a2a_conformance_syntax"
assert_exit_code 0 "bash -n '$TEST_SCRIPT'"

test_start "a2a_conformance_json_runs"
output=$(REPO_ROOT="$REPO_ROOT" bash "$TEST_SCRIPT" --strict --json 2>/dev/null) || true
if [[ "$output" == \{* ]] && [[ "$(printf '%s' "$output" | jq -r '.status')" == "healthy" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: strict JSON conformance is healthy"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: expected healthy strict JSON output"
  printf '%b\n' "    Output: $output"
fi

test_start "dot_agent_conformance_runs"
output=$(REPO_ROOT="$REPO_ROOT" bash "$DOT_CLI" agent conformance --strict --json 2>/dev/null) || true
if [[ "$output" == \{* ]] && [[ "$(printf '%s' "$output" | jq -r '.status')" == "healthy" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dot agent conformance returns healthy JSON"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: expected healthy dot agent conformance output"
  printf '%b\n' "    Output: $output"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
