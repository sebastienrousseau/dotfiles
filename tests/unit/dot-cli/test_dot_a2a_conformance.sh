#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

CONFORMANCE_SCRIPT="$REPO_ROOT/scripts/diagnostics/a2a-conformance.sh"
AGENT_SCRIPT="$REPO_ROOT/scripts/dot/commands/agent.sh"

test_start "conformance_script_exists"
assert_file_exists "$CONFORMANCE_SCRIPT" "a2a-conformance.sh should exist"

test_start "conformance_script_syntax"
assert_exit_code 0 "bash -n '$CONFORMANCE_SCRIPT'"

test_start "conformance_validates_a2a_card"
assert_file_contains "$CONFORMANCE_SCRIPT" "agent-card.json" "should validate .well-known/agent-card.json"

test_start "conformance_validates_legacy_doc"
assert_file_contains "$CONFORMANCE_SCRIPT" "agent.json" "should validate .well-known/agent.json"

test_start "conformance_checks_spec_version"
assert_file_contains "$CONFORMANCE_SCRIPT" "specVersion" "should check specVersion"

test_start "conformance_checks_skills"
assert_file_contains "$CONFORMANCE_SCRIPT" "skills" "should check skills array"

test_start "conformance_checks_signing"
assert_file_contains "$CONFORMANCE_SCRIPT" "signing" "should check signing block"

test_start "conformance_rejects_a2a_ready"
assert_file_contains "$CONFORMANCE_SCRIPT" "a2a-ready" "should detect deprecated a2a-ready"

test_start "agent_has_a2a_card_subcommand"
assert_file_contains "$AGENT_SCRIPT" "a2a-card)" "agent.sh should have a2a-card subcommand"

test_start "conformance_json_output"
output=$(REPO_ROOT="$REPO_ROOT" bash "$CONFORMANCE_SCRIPT" --json 2>/dev/null) || true
if [[ "$output" == \{* ]] && [[ "$(printf '%s' "$output" | jq -r '.specVersion')" == "0.3" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: JSON output includes specVersion 0.3"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: JSON output should include specVersion 0.3"
  printf '%b\n' "    Output: $output"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
