#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

AGENT_SCRIPT="$REPO_ROOT/scripts/dot/commands/agent.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox
PROFILES_FILE="$REPO_ROOT/defaults/dot_config/dotfiles/agent-profiles.json"

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

# The delegate cases run `dot agent delegate` against a private profiles
# copy, state file and log dir, so neither the repo nor ~/.config is touched.
DOT_CLI="$REPO_ROOT/bin/dot"
DEL_TMP="$DOTFILES_COV_TMPDIR/delegate"
mkdir -p "$DEL_TMP/state"
unset DOT_AGENT_PROFILE DOT_AGENT_ROLE
export AGENT_PROFILE_CONFIG="$DEL_TMP/agent-profiles.json"
export AGENT_STATE_FILE="$DEL_TMP/agent-mode.env"
export XDG_STATE_HOME="$DEL_TMP/state"
SESSIONS="$XDG_STATE_HOME/dotfiles/agent-sessions.jsonl"

# profiles <jq filter applied to the tracked file>
profiles() { jq "$1" "$PROFILES_FILE" >"$AGENT_PROFILE_CONFIG"; }
state() { printf '%s\n' "$@" >"$AGENT_STATE_FILE"; }
delegate() {
  out=$(bash "$DOT_CLI" agent delegate "$@" 2>&1)
  rc=$?
}

profiles '.'
state DOT_AGENT_PROFILE=apply

test_start "delegate_refused_while_disabled"
delegate test-runner true || true
assert_contains "Delegation is not enabled" "$rc:$out" "the shipped config keeps delegation off"

profiles '.delegation.enabled = true'

test_start "delegate_refused_from_profile_without_canDelegate"
state DOT_AGENT_PROFILE=ask
delegate test-runner true || true
assert_true "[[ \$rc == 1 && \$out == *\"Profile 'ask' cannot delegate\"* ]]" "ask cannot delegate (rc=$rc)"

test_start "delegate_refuses_unknown_name"
state DOT_AGENT_PROFILE=apply
delegate no-such-delegate true || true
assert_contains "Unknown delegate: no-such-delegate" "$out"

test_start "delegate_runs_command_with_delegate_env"
delegate test-runner sh -c 'echo "env=$DOT_AGENT_DELEGATE:$DOT_AGENT_MAX_STEPS:$DOT_AGENT_PARENT_PROFILE:$DOT_AGENT_PROFILE"' || true
assert_contains "env=test-runner:6:apply:apply" "$out"

test_start "delegate_logs_start_and_finish"
assert_equals "delegate_start delegate_finish" \
  "$(jq -r 'select(.event? // .action? // "" | test("delegate")) | (.event // .action)' "$SESSIONS" 2>/dev/null | tail -n 2 | xargs)" \
  "one start and one finish event per delegation"

test_start "delegate_propagates_failure_exit_code"
delegate test-runner sh -c 'exit 3' || true
assert_equals "3" "$rc" "the delegated command's exit code is returned"

test_start "delegate_strict_rbac_denies_profile_outside_role"
profiles '.delegation.enabled = true | .rbac.enforcement = "strict"'
state DOT_AGENT_PROFILE=apply
delegate security-reviewer true || true
assert_contains "RBAC: role 'developer' is not allowed to use profile 'audit'" "$out"

test_start "delegate_strict_rbac_allows_admin"
state DOT_AGENT_ROLE=admin DOT_AGENT_PROFILE=apply
delegate security-reviewer true || true
assert_equals "0" "$rc" "admin may delegate to an audit-profile delegate"

test_start "apply_profile_can_delegate"
cd="$(jq -r '.profiles.apply.canDelegate' "$PROFILES_FILE")"
assert_equals "true" "$cd" "apply profile should have canDelegate: true"

test_start "audit_profile_can_delegate"
cd="$(jq -r '.profiles.audit.canDelegate' "$PROFILES_FILE")"
assert_equals "true" "$cd" "audit profile should have canDelegate: true"

# Slice 3 (#883): exercise the script under sandbox for line coverage
cov_exercise_script "$AGENT_SCRIPT"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
