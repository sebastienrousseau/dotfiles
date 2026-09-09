#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Regression for: GH-881
# Regression: FEATURE-MATRIX coverage for the meta.sh, agent.sh and agents.sh
# command groups — upgrade, cache-refresh, docs, learn, keys, sandbox, mcp,
# mode, agent and agents — plus the config files and environment overrides
# that drive the agent surface.
#
# The agent rows matter disproportionately: `dot mode set` and
# `dot agent delegate` are the enforcement points for the bounded-autonomy
# policy, so RBAC refusal, delegation refusal and checkpoint replay each get
# an explicit row rather than riding on a happy-path smoke test. Those rows
# drive a copy of agent-profiles.json inside the sandbox through
# AGENT_PROFILE_CONFIG, so enforcement can be flipped to strict without
# touching the checkout.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/feature_matrix_lib.sh"

trap fm_sandbox_teardown EXIT
fm_sandbox_setup

FM_PROFILES_SRC="$REPO_ROOT/defaults/dot_config/dotfiles/agent-profiles.json"
export AGENT_STATE_FILE="$FM_SANDBOX/.config/dotfiles/agent-mode.env"

fm_have_jq() { command -v jq >/dev/null 2>&1; }

# A sandbox copy of the profile registry, optionally transformed by a jq
# program, exported through AGENT_PROFILE_CONFIG.
fm_profiles_copy() {
  local program="${1:-.}"
  local dest="$FM_SANDBOX/agent-profiles.json"
  if [[ "$program" == "." ]]; then
    cp "$FM_PROFILES_SRC" "$dest"
  else
    jq "$program" "$FM_PROFILES_SRC" >"$dest"
  fi
  printf '%s\n' "$dest"
}

# ── meta: upgrade / cache-refresh / docs / learn ───────────────────────────

test_fm_smoke_upgrade() { fm_smoke upgrade; }
test_fm_smoke_env_dotfiles_fonts() { fm_smoke upgrade; }

test_fm_cache_refresh() {
  test_start "fm_cache_refresh"
  fm_run cache-refresh
  fm_expect_rc_in 0 1
  test_start "fm_cache_refresh_reports_regeneration"
  fm_expect_any "Cache" "Pre-warming" "Cached"
}

test_fm_prewarm() {
  test_start "fm_prewarm"
  fm_run prewarm
  fm_expect_rc_in 0 1
  test_start "fm_prewarm_is_alias_of_cache_refresh"
  fm_expect_any "Cache" "Pre-warming" "Cached"
}

test_fm_env_xdg_cache_home() {
  # The regenerated shell caches must land under XDG_CACHE_HOME.
  rm -rf "$XDG_CACHE_HOME/zsh" "$XDG_CACHE_HOME/bash"
  test_start "fm_env_xdg_cache_home"
  fm_run cache-refresh
  fm_expect_rc_in 0 1
  test_start "fm_env_xdg_cache_home_receives_the_caches"
  if find "$XDG_CACHE_HOME" -name '*-init.*' 2>/dev/null | grep -q .; then
    fm_pass "init caches written under XDG_CACHE_HOME"
  else
    # Nothing to cache when none of the backing tools are installed; the
    # command still must not have written outside the sandbox.
    fm_pass "no caches generated (backing tools absent)"
  fi
}

test_fm_docs() {
  test_start "fm_docs"
  fm_run docs
  fm_expect_rc_in 0 1
  test_start "fm_docs_renders_the_readme"
  fm_expect_any "dotfiles" "Dotfiles"
}

test_fm_learn() {
  # The tour is gum-driven and must refuse without a TTY rather than hanging.
  test_start "fm_learn"
  fm_run learn
  fm_expect_rc_in 0 1
  test_start "fm_learn_refuses_without_a_tty"
  fm_expect_any "requires a TTY" "gum" "tour"
}

test_fm_smoke_sandbox() { fm_smoke sandbox; }

# ── meta: keys ─────────────────────────────────────────────────────────────

test_fm_keys() {
  # cmd_keys used to probe only docs/KEYS.md and then fall back to
  # scripts/diagnostics/keys.sh; neither is in the tree, so a bare `dot keys`
  # could only report "Keys script not found". It reads docs/security/KEYS.md.
  test_start "fm_keys"
  fm_run keys
  fm_expect_rc 0
  test_start "fm_keys_is_routed"
  fm_expect_out "Keybindings"
}

test_fm_keys_sign_check() {
  test_start "fm_keys_sign_check"
  fm_run keys sign-check
  fm_expect_rc 0
  test_start "fm_keys_sign_check_reports_status"
  fm_expect_any "Git Signing Status" "signing key"
}

test_fm_keys_sign_check_ssh() {
  # With an ssh signing key configured the report must name the key and its
  # format rather than claiming nothing is configured.
  local keyfile="$FM_SANDBOX/work/fm-signing-key"
  printf 'not-a-real-key\n' >"$keyfile"
  git config --global user.signingkey "$keyfile"
  git config --global gpg.format ssh
  test_start "fm_keys_sign_check_ssh"
  fm_run keys sign-check
  fm_expect_rc 0
  test_start "fm_keys_sign_check_ssh_names_the_key"
  fm_expect_out "$keyfile"
  test_start "fm_keys_sign_check_ssh_reports_the_format"
  fm_expect_any "ssh" "SSH key file exists"
  git config --global --unset user.signingkey || true
  git config --global --unset gpg.format || true
}

# ── mcp ────────────────────────────────────────────────────────────────────

test_fm_mcp() {
  test_start "fm_mcp"
  fm_run mcp
  fm_expect_rc_in 0 1
  test_start "fm_mcp_defaults_to_doctor"
  fm_expect_any "MCP Doctor" "Policy"
}

test_fm_mcp_doctor() {
  test_start "fm_mcp_doctor"
  fm_run mcp doctor
  fm_expect_rc_in 0 1
  test_start "fm_mcp_doctor_audits_policy_and_config"
  fm_expect_any "MCP Doctor" "Policy" "Config"
}

test_fm_mcp_doctor_json() {
  test_start "fm_mcp_doctor_json"
  fm_run mcp doctor --json
  fm_expect_rc_in 0 1
  test_start "fm_mcp_doctor_json_is_json"
  fm_expect_json
  test_start "fm_mcp_doctor_json_reports_status"
  fm_expect_out '"status"'
  test_start "fm_mcp_doctor_json_strict"
  fm_run mcp -s -j
  fm_expect_rc_in 0 1
  test_start "fm_mcp_doctor_json_strict_flag_is_reflected"
  fm_expect_out '"strict": true'
}

test_fm_mcp_registry() {
  test_start "fm_mcp_registry"
  fm_run mcp registry
  fm_expect_rc_in 0 1
  test_start "fm_mcp_registry_lists_servers"
  fm_expect_nonempty
}

test_fm_mcp_registry_json() {
  test_start "fm_mcp_registry_json"
  fm_run mcp registry --json
  fm_expect_rc_in 0 1
  test_start "fm_mcp_registry_json_is_json"
  fm_expect_json
  test_start "fm_mcp_registry_json_has_servers"
  fm_expect_out '"servers"'
}

test_fm_env_mcp_registry_config() {
  # MCP_REGISTRY_CONFIG must select the file that is read…
  local reg="$FM_SANDBOX/work/mcp-registry.json"
  printf '{"servers":{"fm-demo":{"transport":"stdio","launcher":"npx","package":"fm@1"}}}\n' \
    >"$reg"
  test_start "fm_env_mcp_registry_config"
  MCP_REGISTRY_CONFIG="$reg" fm_run mcp registry
  fm_expect_rc_in 0 1
  test_start "fm_env_mcp_registry_config_reads_that_file"
  fm_expect_out "fm-demo"

  # …and a missing file must be a clear error, not an empty table.
  test_start "fm_env_mcp_registry_config_missing_file"
  MCP_REGISTRY_CONFIG="$FM_SANDBOX/work/no-such-registry.json" fm_run mcp registry
  fm_expect_rc 1
  test_start "fm_env_mcp_registry_config_missing_message"
  fm_expect_any "MCP registry not found" "not found"
}

test_fm_config_mcp_registry_json() {
  # The shipped registry must parse and every server must declare a
  # transport — the contract `dot mcp registry` renders.
  test_start "fm_config_mcp_registry_json"
  if ! fm_have_jq; then
    fm_pass "skipped — jq not installed"
    return 0
  fi
  local reg="$REPO_ROOT/defaults/dot_config/dotfiles/mcp-registry.json"
  if [[ ! -f "$reg" ]]; then
    fm_pass "skipped — no shipped mcp-registry.json"
    return 0
  fi
  if jq -e '.servers | to_entries | all(.value.transport != null)' "$reg" >/dev/null 2>&1; then
    fm_pass "every server declares a transport"
  else
    fm_fail "a server in mcp-registry.json has no transport"
  fi
}

test_fm_mcp_unknown() {
  test_start "fm_mcp_unknown"
  fm_run mcp zzz-not-a-subcommand
  fm_expect_rc 1
  test_start "fm_mcp_unknown_prints_usage"
  fm_expect_any "Usage: dot mcp" "doctor|registry"
}

# ── mode ───────────────────────────────────────────────────────────────────

test_fm_mode() {
  test_start "fm_mode"
  fm_run mode
  fm_expect_rc_in 0 1
  test_start "fm_mode_defaults_to_current"
  fm_expect_any "Agent Mode" "Profile"
}

test_fm_mode_list() {
  test_start "fm_mode_list"
  fm_run mode list
  fm_expect_rc_in 0 1
  test_start "fm_mode_list_names_every_profile"
  local missing="" p
  for p in ask plan apply audit; do
    [[ "$FM_OUT" == *"$p"* ]] || missing="$missing $p"
  done
  if [[ -z "$missing" ]]; then
    fm_pass "ask/plan/apply/audit all listed"
  else
    fm_fail "profiles missing from the listing:$missing"
  fi
}

test_fm_mode_current() {
  test_start "fm_mode_current"
  fm_run mode current
  fm_expect_rc_in 0 1
  test_start "fm_mode_current_reports_the_policy"
  fm_expect_any "Approval" "Filesystem" "Network"
}

test_fm_mode_show() {
  test_start "fm_mode_show"
  fm_run mode show audit
  fm_expect_rc_in 0 1
  test_start "fm_mode_show_describes_that_profile"
  fm_expect_any "audit" "Max steps" "Description"
}

test_fm_mode_show_unknown() {
  test_start "fm_mode_show_unknown"
  fm_run mode show zzz-not-a-profile
  fm_expect_rc 1
  test_start "fm_mode_show_unknown_message"
  fm_expect_any "Unknown agent profile" "zzz-not-a-profile"
  test_start "fm_mode_show_missing_name"
  fm_run mode show
  fm_expect_rc 1
  test_start "fm_mode_show_missing_name_message"
  fm_expect_any "Usage: dot mode show" "mode show"
}

test_fm_mode_set() {
  if ! fm_have_jq; then
    test_start "fm_mode_set"
    fm_pass "skipped — jq not installed (dot mode requires it)"
    return 0
  fi
  local profiles
  profiles="$(fm_profiles_copy)"
  test_start "fm_mode_set"
  AGENT_PROFILE_CONFIG="$profiles" fm_run mode set plan
  fm_expect_rc 0
  test_start "fm_mode_set_persists_the_state_file"
  fm_expect_file "$AGENT_STATE_FILE"
  test_start "fm_mode_set_state_file_records_the_profile"
  if grep -q '^DOT_AGENT_PROFILE=plan$' "$AGENT_STATE_FILE"; then
    fm_pass "DOT_AGENT_PROFILE=plan"
  else
    fm_fail "state file does not record the new profile"
  fi
  test_start "fm_mode_set_is_visible_to_current"
  AGENT_PROFILE_CONFIG="$profiles" fm_run mode current
  fm_expect_out "plan"
  # Leave the sandbox on the default profile for the rows that follow.
  AGENT_PROFILE_CONFIG="$profiles" fm_run mode set ask
}

test_fm_mode_set_unknown() {
  test_start "fm_mode_set_unknown"
  fm_run mode set zzz-not-a-profile
  fm_expect_rc 1
  test_start "fm_mode_set_unknown_message"
  fm_expect_any "Unknown agent profile" "zzz-not-a-profile"
}

test_fm_mode_set_rbac_strict() {
  if ! fm_have_jq; then
    test_start "fm_mode_set_rbac_strict"
    fm_pass "skipped — jq not installed"
    return 0
  fi
  # Under strict enforcement the default role must be refused a profile it
  # is not granted. This is the bounded-autonomy gate; a silent pass here
  # would mean RBAC is decorative.
  local profiles
  profiles="$(fm_profiles_copy '.rbac.enforcement = "strict"')"
  test_start "fm_mode_set_rbac_strict"
  AGENT_PROFILE_CONFIG="$profiles" fm_run mode set audit
  fm_expect_rc 1
  test_start "fm_mode_set_rbac_strict_explains_the_refusal"
  fm_expect_any "RBAC" "not allowed" "strict"

  # Advisory enforcement warns but allows.
  local advisory
  advisory="$(fm_profiles_copy '.rbac.enforcement = "advisory"')"
  test_start "fm_mode_set_rbac_advisory_allows"
  AGENT_PROFILE_CONFIG="$advisory" fm_run mode set audit
  fm_expect_rc 0
  AGENT_PROFILE_CONFIG="$advisory" fm_run mode set ask
}

test_fm_mode_run() {
  if ! fm_have_jq; then
    test_start "fm_mode_run"
    fm_pass "skipped — jq not installed"
    return 0
  fi
  test_start "fm_mode_run"
  fm_run mode run plan echo fm-mode-run-ok
  fm_expect_rc 0
  test_start "fm_mode_run_executes_the_command"
  fm_expect_out "fm-mode-run-ok"
}

test_fm_mode_run_usage() {
  test_start "fm_mode_run_usage"
  fm_run mode run
  fm_expect_rc 1
  test_start "fm_mode_run_usage_message"
  fm_expect_any "Usage: dot mode run" "mode run"
}

test_fm_mode_run_exit_code() {
  if ! fm_have_jq; then
    test_start "fm_mode_run_exit_code"
    fm_pass "skipped — jq not installed"
    return 0
  fi
  # The wrapped command's exit code SHOULD reach the caller, or `dot mode run`
  # cannot be used as a CI wrapper at all.
  #
  # This row was written while all three wrappers used
  #
  #     if ! "$@"; then exit_code=$?
  #
  # where `$?` is the status of the NEGATED pipeline and so always 0 — the
  # failure code was lost. They now run the command as the `if` condition and
  # read `$?` in the else branch, so the real status reaches the caller.
  test_start "fm_mode_run_exit_code"
  fm_run mode run plan sh -c "exit 42"
  fm_expect_rc 42
  test_start "fm_mode_run_exit_code_command_was_executed"
  fm_run mode run plan sh -c "printf fm-exit-marker; exit 42"
  fm_expect_out "fm-exit-marker"
}

test_fm_mode_doctor() {
  test_start "fm_mode_doctor"
  fm_run mode doctor
  fm_expect_rc_in 0 1
  test_start "fm_mode_doctor_validates_the_config"
  fm_expect_any "Agent Mode Doctor" "Profile config" "Default profile"
}

test_fm_mode_unknown() {
  test_start "fm_mode_unknown"
  fm_run mode zzz-not-a-subcommand
  fm_expect_rc 1
  test_start "fm_mode_unknown_prints_usage"
  fm_expect_any "Usage: dot mode" "list|current"
}

test_fm_env_agent_profile_config() {
  if ! fm_have_jq; then
    test_start "fm_env_agent_profile_config"
    fm_pass "skipped — jq not installed"
    return 0
  fi
  # A profile that exists only in the override file proves the override is
  # what was read.
  local profiles
  profiles="$(fm_profiles_copy '.profiles["fm-only"] = {description:"fixture",approval:"manual",filesystem:"read-only",network:"off",mcpProfile:"strict-local",maxSteps:1}')"
  test_start "fm_env_agent_profile_config"
  AGENT_PROFILE_CONFIG="$profiles" fm_run mode show fm-only
  fm_expect_rc 0
  test_start "fm_env_agent_profile_config_reads_the_override"
  fm_expect_out "fixture"
  test_start "fm_env_agent_state_file_is_honoured"
  AGENT_PROFILE_CONFIG="$profiles" AGENT_STATE_FILE="$FM_SANDBOX/alt-state.env" \
    fm_run mode set plan
  fm_expect_file "$FM_SANDBOX/alt-state.env"
}

test_fm_config_agent_profiles_json() {
  test_start "fm_config_agent_profiles_json"
  if ! fm_have_jq; then
    fm_pass "skipped — jq not installed"
    return 0
  fi
  # The shipped registry must declare a default profile that exists, and an
  # rbac block — `dot mode doctor` and `dot fleet enforce` both depend on it.
  if jq -e '.profiles[.defaultProfile] != null and .rbac != null' \
    "$FM_PROFILES_SRC" >/dev/null 2>&1; then
    fm_pass "defaultProfile resolves and rbac is present"
  else
    fm_fail "agent-profiles.json has no resolvable defaultProfile or no rbac block"
  fi
}

test_fm_config_agent_mode_env() {
  if ! fm_have_jq; then
    test_start "fm_config_agent_mode_env"
    fm_pass "skipped — jq not installed"
    return 0
  fi
  local profiles
  profiles="$(fm_profiles_copy)"
  AGENT_PROFILE_CONFIG="$profiles" fm_run mode set plan
  test_start "fm_config_agent_mode_env"
  fm_expect_file "$AGENT_STATE_FILE"
  test_start "fm_config_agent_mode_env_records_the_whole_policy"
  local missing="" k
  for k in DOT_AGENT_PROFILE DOT_AGENT_APPROVAL DOT_AGENT_FILESYSTEM \
    DOT_AGENT_NETWORK DOT_AGENT_MCP_PROFILE DOT_AGENT_MAX_STEPS; do
    grep -q "^$k=" "$AGENT_STATE_FILE" || missing="$missing $k"
  done
  if [[ -z "$missing" ]]; then
    fm_pass "all six policy fields recorded"
  else
    fm_fail "state file missing:$missing"
  fi
  AGENT_PROFILE_CONFIG="$profiles" fm_run mode set ask
}

# ── agent ──────────────────────────────────────────────────────────────────

test_fm_agent() {
  test_start "fm_agent"
  fm_run agent
  fm_expect_rc_in 0 1
  test_start "fm_agent_defaults_to_current"
  fm_expect_any "Agent Mode" "Profile"
}

test_fm_agent_card() {
  test_start "fm_agent_card"
  fm_run agent card
  fm_expect_rc_in 0 1
  test_start "fm_agent_card_reports_metadata"
  fm_expect_any "Agent Card" "Protocols" "Name"
}

test_fm_agent_card_json() {
  test_start "fm_agent_card_json"
  fm_run agent card --json
  fm_expect_rc_in 0 1
  test_start "fm_agent_card_json_is_json"
  fm_expect_json
}

test_fm_env_agent_card_config() {
  local card="$FM_SANDBOX/work/agent-card.json"
  printf '{"name":"fm-fixture-card","version":"9.9.9","protocols":["mcp"],"defaultProfile":"ask","platforms":["Linux"]}\n' \
    >"$card"
  test_start "fm_env_agent_card_config"
  AGENT_CARD_CONFIG="$card" fm_run agent card
  fm_expect_rc_in 0 1
  test_start "fm_env_agent_card_config_reads_the_override"
  fm_expect_out "fm-fixture-card"
}

test_fm_config_agent_card_json() {
  test_start "fm_config_agent_card_json"
  if ! fm_have_jq; then
    fm_pass "skipped — jq not installed"
    return 0
  fi
  local card="$REPO_ROOT/defaults/dot_config/dotfiles/agent-card.json"
  if [[ ! -f "$card" ]]; then
    fm_fail "shipped agent-card.json is missing"
    return 0
  fi
  if jq -e '.name and .version and (.protocols | type == "array") and (.platforms | type == "array")' \
    "$card" >/dev/null 2>&1; then
    fm_pass "card declares name, version, protocols and platforms"
  else
    fm_fail "agent-card.json is missing a required field"
  fi
}

test_fm_agent_log() {
  # Generate an event, then require the tail to show it.
  fm_run mode current
  test_start "fm_agent_log"
  fm_run agent log
  fm_expect_rc_in 0 1
  test_start "fm_agent_log_tails_the_session_log"
  fm_expect_any "event" "profile" "current"
  test_start "fm_agent_log_count_argument"
  fm_run agent log 5
  fm_expect_rc_in 0 1
}

test_fm_agent_checkpoint_save() {
  if ! fm_have_jq; then
    test_start "fm_agent_checkpoint_save"
    fm_pass "skipped — jq not installed"
    return 0
  fi
  test_start "fm_agent_checkpoint_save"
  fm_run agent checkpoint save plan echo fm-checkpoint
  fm_expect_rc 0
  test_start "fm_agent_checkpoint_save_reports_an_id"
  fm_expect_any "Agent Checkpoint" "ID"
  test_start "fm_agent_checkpoint_save_writes_the_json"
  if find "$XDG_STATE_HOME/dotfiles/checkpoints" -name '*.json' 2>/dev/null | grep -q .; then
    fm_pass "checkpoint written"
  else
    fm_fail "no checkpoint JSON under XDG_STATE_HOME"
  fi
}

test_fm_agent_checkpoint_save_usage() {
  test_start "fm_agent_checkpoint_save_usage"
  fm_run agent checkpoint save
  fm_expect_rc 1
  test_start "fm_agent_checkpoint_save_usage_message"
  fm_expect_any "Usage: dot agent checkpoint save" "checkpoint save"
}

test_fm_agent_checkpoint_list() {
  test_start "fm_agent_checkpoint_list"
  fm_run agent checkpoint list
  fm_expect_rc_in 0 1
  test_start "fm_agent_checkpoint_list_no_breakage"
  fm_expect_no_forbidden
  test_start "fm_agent_checkpoint_defaults_to_list"
  fm_run agent checkpoint
  fm_expect_rc_in 0 1
}

fm_latest_checkpoint_id() {
  local f
  f="$(find "$XDG_STATE_HOME/dotfiles/checkpoints" -name '*.json' 2>/dev/null |
    sort | tail -1)"
  [[ -n "$f" ]] || return 1
  basename "$f" .json
}

test_fm_agent_checkpoint_show() {
  if ! fm_have_jq; then
    test_start "fm_agent_checkpoint_show"
    fm_pass "skipped — jq not installed"
    return 0
  fi
  fm_run agent checkpoint save plan echo fm-show
  local id
  if ! id="$(fm_latest_checkpoint_id)"; then
    test_start "fm_agent_checkpoint_show"
    fm_fail "no checkpoint to show"
    return 0
  fi
  test_start "fm_agent_checkpoint_show"
  fm_run agent checkpoint show "$id"
  fm_expect_rc 0
  test_start "fm_agent_checkpoint_show_names_the_checkpoint"
  fm_expect_out "$id"
  test_start "fm_agent_checkpoint_show_json"
  fm_run agent checkpoint show "$id" --json
  fm_expect_json
}

test_fm_agent_checkpoint_show_unknown() {
  test_start "fm_agent_checkpoint_show_unknown"
  fm_run agent checkpoint show zzz-no-such-checkpoint
  fm_expect_rc 1
  test_start "fm_agent_checkpoint_show_unknown_message"
  fm_expect_any "Checkpoint not found" "zzz-no-such-checkpoint"
  test_start "fm_agent_checkpoint_show_missing_id"
  fm_run agent checkpoint show
  fm_expect_rc 1
}

test_fm_agent_checkpoint_replay() {
  if ! fm_have_jq; then
    test_start "fm_agent_checkpoint_replay"
    fm_pass "skipped — jq not installed"
    return 0
  fi
  fm_run agent checkpoint save plan echo fm-replay-marker
  local id
  if ! id="$(fm_latest_checkpoint_id)"; then
    test_start "fm_agent_checkpoint_replay"
    fm_fail "no checkpoint to replay"
    return 0
  fi
  test_start "fm_agent_checkpoint_replay"
  fm_run agent checkpoint replay "$id"
  fm_expect_rc 0
  test_start "fm_agent_checkpoint_replay_reruns_the_command"
  fm_expect_out "fm-replay-marker"
}

test_fm_agent_checkpoint_replay_usage() {
  test_start "fm_agent_checkpoint_replay_usage"
  fm_run agent checkpoint replay
  fm_expect_rc 1
  test_start "fm_agent_checkpoint_replay_usage_message"
  fm_expect_any "Usage: dot agent checkpoint replay" "checkpoint replay"
  test_start "fm_agent_checkpoint_unknown_action"
  fm_run agent checkpoint zzz-not-an-action
  fm_expect_rc 1
  test_start "fm_agent_checkpoint_unknown_action_message"
  fm_expect_any "save|list|show|replay" "Usage"
}

test_fm_agent_delegate() {
  if ! fm_have_jq; then
    test_start "fm_agent_delegate"
    fm_pass "skipped — jq not installed"
    return 0
  fi
  # Delegation enabled + the current profile permitted to delegate.
  local profiles
  profiles="$(fm_profiles_copy '.delegation.enabled = true
    | .delegation.allowedDelegates["fm-reviewer"] = {profile:"plan",timeout:30,maxSteps:2}
    | .profiles.ask.canDelegate = true')"
  test_start "fm_agent_delegate"
  AGENT_PROFILE_CONFIG="$profiles" fm_run agent delegate fm-reviewer echo fm-delegated
  fm_expect_rc 0

  # This row used to be conditional on a GNU `timeout` existing: the delegate
  # path wrapped the command as `timeout "$delegate_timeout" "$@"`, and stock
  # macOS ships neither `timeout` nor `gtimeout`, so the delegated command
  # never ran there at all. _agent_run_bounded now falls back to perl's
  # fork+alarm (the same answer tests/framework/assertions.sh gives), so the
  # command runs — and stays bounded — on every host we support. The unit
  # file pins the fallbacks with a PATH that has no timeout binary.
  test_start "fm_agent_delegate_runs_under_the_delegate_profile"
  fm_expect_out "fm-delegated"
  test_start "fm_agent_delegate_rejects_an_unknown_delegate"
  AGENT_PROFILE_CONFIG="$profiles" fm_run agent delegate zzz-nobody echo x
  fm_expect_rc 1
  test_start "fm_agent_delegate_unknown_message"
  fm_expect_any "Unknown delegate" "zzz-nobody"
}

test_fm_agent_delegate_disabled() {
  if ! fm_have_jq; then
    test_start "fm_agent_delegate_disabled"
    fm_pass "skipped — jq not installed"
    return 0
  fi
  # With delegation switched off the command must refuse — this is a policy
  # boundary, not a convenience check.
  local profiles
  profiles="$(fm_profiles_copy '.delegation.enabled = false')"
  test_start "fm_agent_delegate_disabled"
  AGENT_PROFILE_CONFIG="$profiles" fm_run agent delegate fm-reviewer echo nope
  fm_expect_rc 1
  test_start "fm_agent_delegate_disabled_explains"
  fm_expect_any "Delegation is not enabled" "cannot delegate"
}

test_fm_agent_delegate_usage() {
  test_start "fm_agent_delegate_usage"
  fm_run agent delegate
  fm_expect_rc 1
  test_start "fm_agent_delegate_usage_message"
  fm_expect_any "Usage: dot agent delegate" "delegate"
  test_start "fm_agent_delegate_missing_command"
  fm_run agent delegate fm-reviewer
  fm_expect_rc 1
}

test_fm_agent_a2a_card() {
  test_start "fm_agent_a2a_card"
  fm_run agent a2a-card
  fm_expect_rc_in 0 1
  test_start "fm_agent_a2a_card_reports_the_spec"
  fm_expect_any "A2A" "Spec" "specVersion"
}

test_fm_agent_a2a_card_json() {
  test_start "fm_agent_a2a_card_json"
  fm_run agent a2a-card --json
  fm_expect_rc_in 0 1
  test_start "fm_agent_a2a_card_json_is_json"
  fm_expect_json
}

test_fm_agent_a2a_card_validate() {
  test_start "fm_agent_a2a_card_validate"
  fm_run agent a2a-card --validate
  fm_expect_rc_in 0 1
  test_start "fm_agent_a2a_card_validate_checks_each_field"
  fm_expect_any "specVersion" "skills" "authentication" "signing"
  # --strict must turn any validation issue into a non-zero exit; on a
  # healthy card it still passes.
  test_start "fm_agent_a2a_card_validate_strict"
  fm_run agent a2a-card --strict
  fm_expect_rc_in 0 1
}

test_fm_agent_conformance() {
  test_start "fm_agent_conformance"
  fm_run agent conformance
  fm_expect_rc_in 0 1
  test_start "fm_agent_conformance_reports_status"
  fm_expect_any "Conformance" "conformance" "status"
}

test_fm_agent_conformance_json() {
  test_start "fm_agent_conformance_json"
  fm_run agent conformance --json
  fm_expect_rc_in 0 1
  test_start "fm_agent_conformance_json_is_json"
  fm_expect_json
  test_start "fm_agent_conformance_strict"
  fm_run agent conformance --strict
  fm_expect_rc_in 0 1
}

test_fm_agent_unknown() {
  test_start "fm_agent_unknown"
  fm_run agent zzz-not-a-subcommand
  fm_expect_rc 1
  test_start "fm_agent_unknown_prints_usage"
  fm_expect_any "Usage: dot mode" "card|log|checkpoint" "list|current"
}

# ── agents (multi-harness context) ─────────────────────────────────────────
#
# `agents render` writes AGENTS.md and ten harness files into the repo root,
# and refuses to run outside a checkout carrying .chezmoidata.toml. Drive a
# git-initialised sandbox copy so the rows exercise render + check for real.

fm_agents_repo() {
  local repo="$FM_SANDBOX/agents-repo"
  if [[ ! -d "$repo" ]]; then
    fm_repo_copy "$repo" >/dev/null
    git -C "$repo" init -q 2>/dev/null || true
  fi
  printf '%s\n' "$repo"
}

test_fm_agents_list() {
  local repo
  repo="$(fm_agents_repo)"
  local prev="$PWD"
  cd "$repo" || return 0
  test_start "fm_agents_list"
  fm_run_bin "$repo/bin/dot" agents list
  fm_expect_rc_in 0 1
  test_start "fm_agents_list_names_the_harnesses"
  fm_expect_any "Harness" "AGENTS.md" "cursor"
  cd "$prev" || return 0
}

test_fm_agents_check_drift() {
  local repo
  repo="$(fm_agents_repo)"
  local prev="$PWD"
  cd "$repo" || return 0
  rm -f "$repo/AGENTS.md"
  test_start "fm_agents_check_drift"
  fm_run_bin "$repo/bin/dot" agents check
  fm_expect_rc 1
  test_start "fm_agents_check_drift_points_at_render"
  fm_expect_any "missing" "drifted" "dot agents render"
  cd "$prev" || return 0
}

test_fm_agents_render() {
  local repo
  repo="$(fm_agents_repo)"
  local prev="$PWD"
  cd "$repo" || return 0
  test_start "fm_agents_render"
  fm_run_bin "$repo/bin/dot" agents render
  fm_expect_rc 0
  test_start "fm_agents_render_writes_agents_md"
  fm_expect_file "$repo/AGENTS.md"
  test_start "fm_agents_render_writes_the_harness_stubs"
  local missing="" f
  for f in .cursor/rules/dotfiles.mdc .codex/config.toml .windsurf/rules.md \
    .zed/agent-config.toml .roo/rules.md .clinerules .aider.conf.yml \
    .continuerc.json .jules/system.md .agy/AGY.md; do
    [[ -e "$repo/$f" ]] || missing="$missing $f"
  done
  if [[ -z "$missing" ]]; then
    fm_pass "all eleven harness targets rendered"
  else
    fm_fail "harness files not rendered:$missing"
  fi
  test_start "fm_agents_render_did_not_touch_the_checkout"
  if [[ -n "$(git -C "$REPO_ROOT" status --porcelain -- AGENTS.md .cursor .codex 2>/dev/null)" ]]; then
    fm_fail "render modified the real checkout"
  else
    fm_pass "checkout untouched"
  fi
  cd "$prev" || return 0
}

test_fm_agents_check() {
  local repo
  repo="$(fm_agents_repo)"
  local prev="$PWD"
  cd "$repo" || return 0
  # Rendered above, so check must now report in-sync.
  fm_run_bin "$repo/bin/dot" agents render
  test_start "fm_agents_check"
  fm_run_bin "$repo/bin/dot" agents check
  fm_expect_rc 0
  test_start "fm_agents_check_reports_in_sync"
  fm_expect_any "in sync" "AGENTS.md"
  cd "$prev" || return 0
}

test_fm_agents_help() {
  test_start "fm_agents_help"
  fm_run agents --help
  fm_expect_rc 0
  test_start "fm_agents_help_lists_subcommands"
  fm_expect_any "list" "check" "render"
}

test_fm_agents_unknown() {
  local repo
  repo="$(fm_agents_repo)"
  test_start "fm_agents_unknown"
  fm_run_bin "$repo/bin/dot" agents zzz-not-a-subcommand
  fm_expect_rc 1
  test_start "fm_agents_unknown_message"
  fm_expect_any "Unknown subcommand" "zzz-not-a-subcommand"
}

# ── run ────────────────────────────────────────────────────────────────────

echo ""
echo "── FEATURE-MATRIX: meta, mode, agent, agents ──"
echo ""

test_fm_smoke_upgrade
test_fm_smoke_env_dotfiles_fonts
test_fm_cache_refresh
test_fm_prewarm
test_fm_env_xdg_cache_home
test_fm_docs
test_fm_learn
test_fm_smoke_sandbox
test_fm_keys
test_fm_keys_sign_check
test_fm_keys_sign_check_ssh
test_fm_mcp
test_fm_mcp_doctor
test_fm_mcp_doctor_json
test_fm_mcp_registry
test_fm_mcp_registry_json
test_fm_env_mcp_registry_config
test_fm_config_mcp_registry_json
test_fm_mcp_unknown
test_fm_mode
test_fm_mode_list
test_fm_mode_current
test_fm_mode_show
test_fm_mode_show_unknown
test_fm_mode_set
test_fm_mode_set_unknown
test_fm_mode_set_rbac_strict
test_fm_mode_run
test_fm_mode_run_usage
test_fm_mode_run_exit_code
test_fm_mode_doctor
test_fm_mode_unknown
test_fm_env_agent_profile_config
test_fm_config_agent_profiles_json
test_fm_config_agent_mode_env
test_fm_agent
test_fm_agent_card
test_fm_agent_card_json
test_fm_env_agent_card_config
test_fm_config_agent_card_json
test_fm_agent_log
test_fm_agent_checkpoint_save
test_fm_agent_checkpoint_save_usage
test_fm_agent_checkpoint_list
test_fm_agent_checkpoint_show
test_fm_agent_checkpoint_show_unknown
test_fm_agent_checkpoint_replay
test_fm_agent_checkpoint_replay_usage
test_fm_agent_delegate
test_fm_agent_delegate_disabled
test_fm_agent_delegate_usage
test_fm_agent_a2a_card
test_fm_agent_a2a_card_json
test_fm_agent_a2a_card_validate
test_fm_agent_conformance
test_fm_agent_conformance_json
test_fm_agent_unknown
test_fm_agents_list
test_fm_agents_check_drift
test_fm_agents_render
test_fm_agents_check
test_fm_agents_help
test_fm_agents_unknown

fm_finish
