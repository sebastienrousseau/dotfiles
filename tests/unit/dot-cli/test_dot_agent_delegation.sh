#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

AGENT_SCRIPT="$REPO_ROOT/scripts/dot/commands/agent.sh"
PROFILES_FILE="$REPO_ROOT/dot_config/dotfiles/agent-profiles.json"

test_start "delegation_config_exists"
if jq -e '.delegation' "$PROFILES_FILE" >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: delegation config exists"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: missing delegation config"
fi

test_start "delegation_has_allowed_delegates"
if jq -e '.delegation.allowedDelegates | keys | length > 0' "$PROFILES_FILE" >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: allowedDelegates defined"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: missing allowedDelegates"
fi

test_start "delegation_security_policy"
if jq -e '.delegation.securityPolicy.requireParentApproval' "$PROFILES_FILE" >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: securityPolicy defined"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: missing securityPolicy"
fi

test_start "delegate_subcommand_exists"
assert_file_contains "$AGENT_SCRIPT" "delegate)" "agent.sh should have delegate subcommand"

test_start "delegate_checks_enabled"
assert_file_contains "$AGENT_SCRIPT" "delegation.enabled" "delegate should check if delegation is enabled"

test_start "delegate_checks_can_delegate"
assert_file_contains "$AGENT_SCRIPT" "canDelegate" "delegate should check canDelegate"

test_start "delegate_logs_events"
assert_file_contains "$AGENT_SCRIPT" "delegate_start" "delegate should log start event"
assert_file_contains "$AGENT_SCRIPT" "delegate_finish" "delegate should log finish event"

test_start "apply_profile_can_delegate"
cd="$(jq -r '.profiles.apply.canDelegate' "$PROFILES_FILE")"
assert_equals "true" "$cd" "apply profile should have canDelegate: true"

test_start "audit_profile_can_delegate"
cd="$(jq -r '.profiles.audit.canDelegate' "$PROFILES_FILE")"
assert_equals "true" "$cd" "audit profile should have canDelegate: true"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
