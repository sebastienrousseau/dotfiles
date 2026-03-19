#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

TEST_SCRIPT="$REPO_ROOT/scripts/diagnostics/workstation-attestation.sh"
DOT_CLI="$REPO_ROOT/dot_local/bin/executable_dot"

test_start "attestation_exists"
assert_file_exists "$TEST_SCRIPT" "workstation-attestation.sh should exist"

test_start "attestation_syntax"
assert_exit_code 0 "bash -n '$TEST_SCRIPT'"

test_start "attestation_registered"
assert_file_contains "$DOT_CLI" "attest" "dot CLI should register attest command"

test_start "attestation_json_runs"
output=$(REPO_ROOT="$REPO_ROOT" bash "$TEST_SCRIPT" --json 2>/dev/null) || true
if [[ "$output" == \{* ]] && [[ "$output" == *"\"dotfiles_version\""* ]] && [[ "$output" == *"\"git_signing\""* ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: emits attestation JSON"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should emit attestation JSON"
  printf '%b\n' "    Output: $output"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
