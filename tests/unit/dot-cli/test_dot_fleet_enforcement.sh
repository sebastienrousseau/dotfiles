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
FLEET_SCRIPT="$REPO_ROOT/scripts/dot/commands/fleet.sh"
PROFILES_FILE="$REPO_ROOT/defaults/dot_config/dotfiles/agent-profiles.json"

test_start "enforcement_field_exists"
if jq -e '.rbac.enforcement' "$PROFILES_FILE" >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: enforcement field exists"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: missing enforcement field"
fi

# Every case below runs `dot` against a private copy of the profiles and a
# private state file, so neither the repo nor ~/.config is touched.
DOT_CLI="$REPO_ROOT/bin/dot"
RBAC_TMP="$DOTFILES_COV_TMPDIR/rbac"
mkdir -p "$RBAC_TMP"
export AGENT_PROFILE_CONFIG="$RBAC_TMP/agent-profiles.json"
export AGENT_STATE_FILE="$RBAC_TMP/agent-mode.env"
cp "$PROFILES_FILE" "$AGENT_PROFILE_CONFIG"
PROFILES_BEFORE="$(cat "$PROFILES_FILE")"

dot_rc() { bash "$DOT_CLI" "$@" >/dev/null 2>&1 && echo 0 || echo $?; }
role() { printf 'DOT_AGENT_ROLE=%s\n' "$1" >"$AGENT_STATE_FILE"; }

test_start "fleet_enforce_status_reports_mode"
assert_output_contains "advisory" "bash '$DOT_CLI' fleet enforce status"

test_start "fleet_enforce_set_writes_the_override_file"
bash "$DOT_CLI" fleet enforce set strict >/dev/null 2>&1 || true
assert_equals "strict" "$(jq -r .rbac.enforcement "$AGENT_PROFILE_CONFIG")" "enforce set writes AGENT_PROFILE_CONFIG"

test_start "fleet_enforce_set_leaves_repo_file_alone"
assert_equals "$PROFILES_BEFORE" "$(cat "$PROFILES_FILE")" "the tracked profiles file is unchanged"

test_start "fleet_enforce_set_rejects_unknown_mode"
assert_equals "1" "$(dot_rc fleet enforce set lenient)" "only advisory|strict are accepted"

test_start "strict_denies_profile_outside_role"
role viewer
assert_equals "1" "$(dot_rc mode set plan)" "viewer cannot switch to plan under strict"

test_start "strict_allows_profile_inside_role"
role viewer
assert_equals "0" "$(dot_rc mode set ask)" "viewer can switch to ask under strict"

test_start "mode_set_keeps_role"
assert_equals "viewer" "$(sed -n 's/^DOT_AGENT_ROLE=//p' "$AGENT_STATE_FILE")" "switching mode keeps DOT_AGENT_ROLE"

test_start "role_survives_mode_switch_under_strict"
assert_equals "1" "$(dot_rc mode set apply)" "viewer stays denied after a permitted switch"

test_start "strict_default_role_is_developer"
rm -f "$AGENT_STATE_FILE"
assert_equals "1" "$(dot_rc mode set audit)" "with no role set, developer cannot use audit"

test_start "advisory_warns_but_allows"
bash "$DOT_CLI" fleet enforce set advisory >/dev/null 2>&1 || true
role viewer
assert_output_contains "not recommended for profile 'plan'" "bash '$DOT_CLI' mode set plan 2>&1"

# Slice 3 (#883): exercise the script under sandbox for line coverage
cov_exercise_script "$AGENT_SCRIPT"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
