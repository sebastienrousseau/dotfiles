#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

AGENT_SCRIPT="$REPO_ROOT/scripts/dot/commands/agent.sh"
FLEET_SCRIPT="$REPO_ROOT/scripts/dot/commands/fleet.sh"
PROFILES_FILE="$REPO_ROOT/dot_config/dotfiles/agent-profiles.json"

test_start "enforcement_field_exists"
if jq -e '.rbac.enforcement' "$PROFILES_FILE" >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: enforcement field exists"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: missing enforcement field"
fi

test_start "enforcement_rbac_function"
assert_file_contains "$AGENT_SCRIPT" "_agent_rbac_enforcement" "agent.sh should have _agent_rbac_enforcement"

test_start "enforcement_current_role_function"
assert_file_contains "$AGENT_SCRIPT" "_agent_current_role" "agent.sh should have _agent_current_role"

test_start "enforcement_role_allows_profile_function"
assert_file_contains "$AGENT_SCRIPT" "_agent_role_allows_profile" "agent.sh should have _agent_role_allows_profile"

test_start "enforcement_enforce_rbac_function"
assert_file_contains "$AGENT_SCRIPT" "_agent_enforce_rbac" "agent.sh should have _agent_enforce_rbac"

test_start "enforcement_called_in_mode_set"
assert_file_contains "$AGENT_SCRIPT" '_agent_enforce_rbac "$name"' "mode set should call _agent_enforce_rbac"

test_start "fleet_enforce_subcommand"
assert_file_contains "$FLEET_SCRIPT" "cmd_fleet_enforce" "fleet.sh should have enforce subcommand"

test_start "fleet_enforce_status_subcommand"
assert_file_contains "$FLEET_SCRIPT" "enforce)" "fleet dispatch should include enforce"

test_start "fleet_enforce_set_subcommand"
assert_file_contains "$FLEET_SCRIPT" "advisory | strict" "fleet enforce set should accept advisory or strict"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
