#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural coverage for the `checkpoint` and `delegate` arms of
# scripts/dot/commands/agent.sh (`cmd_mode`), driven through the real
# dispatcher (`meta.sh agent …`) inside the coverage sandbox. Split from
# test_dot_agent_dispatch.sh to stay inside the coverage runner's 60s
# per-file budget.
#
# Child stderr is captured to a file and replayed to our own stderr so the
# xtrace records the coverage runner relies on are not swallowed.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

META="$REPO_ROOT/scripts/dot/commands/meta.sh"
AGENT_MODULE="$REPO_ROOT/scripts/dot/commands/agent.sh"
REAL_PROFILES="$REPO_ROOT/defaults/dot_config/dotfiles/agent-profiles.json"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

STATE_DIR="$XDG_STATE_HOME/dotfiles"
CHECKPOINT_DIR="$STATE_DIR/checkpoints"
SESSIONS="$STATE_DIR/agent-sessions.jsonl"

# `timeout` (used by `agent delegate`) is coreutils-only on macOS; shim it so
# the delegate arm is deterministic on every platform.
cat >"$DOTFILES_COV_TMPDIR/bin/timeout" <<'EOF'
#!/usr/bin/env bash
shift
exec "$@"
EOF
chmod +x "$DOTFILES_COV_TMPDIR/bin/timeout"

# run_cmd <cmd…> — sets OUT / ERR / RC. stderr is replayed (xtrace-safe).
run_cmd() {
  local errf="$DOTFILES_COV_TMPDIR/stderr.$$"
  OUT="$("$@" 2>"$errf" </dev/null)"
  RC=$?
  ERR="$(grep -v '^+*@COV@' "$errf" 2>/dev/null || true)"
  [[ "${DOTFILES_COV_ECHO_STDERR:-0}" == "1" ]] && cat "$errf" >&2
  rm -f "$errf"
  return 0
}

meta() { run_cmd bash "$META" "$@"; }

STRICT_PROFILES="$DOTFILES_COV_TMPDIR/strict-profiles.json"
jq '.rbac.enforcement = "strict" | .delegation.enabled = true | .profiles.ask.canDelegate = true' \
  "$REAL_PROFILES" >"$STRICT_PROFILES"

# ── checkpoint ──────────────────────────────────────────────────────────
test_start "checkpoint_save_requires_command"
meta agent checkpoint save
assert_equals 1 "$RC" "rc"
assert_contains "Usage: dot agent checkpoint save" "$ERR" "usage"

test_start "checkpoint_save_writes_file"
DOT_AGENT_CHECKPOINT_ID=cp-one meta agent checkpoint save plan echo hello world
assert_equals 0 "$RC" "rc"
assert_file_exists "$CHECKPOINT_DIR/cp-one.json" "checkpoint file"
assert_contains "cp-one" "$OUT" "id printed"
assert_equals "plan" "$(jq -r .profile "$CHECKPOINT_DIR/cp-one.json")" "profile recorded"

test_start "checkpoint_save_defaults_to_current_profile"
DOT_AGENT_CHECKPOINT_ID=cp-two meta agent checkpoint save bash -c 'exit 7'
assert_equals 0 "$RC" "rc"
assert_equals "ask" "$(jq -r .profile "$CHECKPOINT_DIR/cp-two.json")" "current profile"

test_start "checkpoint_list_shows_saved"
meta agent checkpoint list
assert_equals 0 "$RC" "rc"
assert_contains "cp-one" "$OUT" "listed"
assert_contains "Agent Checkpoints" "$OUT" "header"

test_start "checkpoint_default_action_is_list"
meta agent checkpoint
assert_equals 0 "$RC" "rc"
assert_contains "cp-two" "$OUT" "listed"

test_start "checkpoint_show_requires_id"
meta agent checkpoint show
assert_equals 1 "$RC" "rc"
assert_contains "Usage: dot agent checkpoint show" "$ERR" "usage"

test_start "checkpoint_show_unknown_id"
meta agent checkpoint show nope
assert_equals 1 "$RC" "rc"
assert_contains "Checkpoint not found" "$ERR" "error"

test_start "checkpoint_show_renders"
meta agent checkpoint show cp-one
assert_equals 0 "$RC" "rc"
assert_contains "hello world" "$OUT" "argv rendered"

test_start "checkpoint_show_json"
meta agent checkpoint show cp-one --json
assert_equals 0 "$RC" "rc"
assert_equals "cp-one" "$(printf '%s' "$OUT" | jq -r .id)" "raw json"

test_start "checkpoint_replay_requires_id"
meta agent checkpoint replay
assert_equals 1 "$RC" "rc"
assert_contains "Usage: dot agent checkpoint replay" "$ERR" "usage"

test_start "checkpoint_replay_unknown_id"
meta agent checkpoint replay nope
assert_equals 1 "$RC" "rc"
assert_contains "Checkpoint not found" "$ERR" "error"

test_start "checkpoint_replay_runs_saved_command"
meta agent checkpoint replay cp-one
assert_equals 0 "$RC" "rc"
assert_contains "hello world" "$OUT" "replayed command output"
assert_file_contains "$SESSIONS" '"event":"checkpoint_replay_finish"' "logged"

test_start "checkpoint_replay_propagates_failure"
meta agent checkpoint replay cp-two
assert_equals 7 "$RC" "rc from replayed command"

test_start "checkpoint_replay_refuses_empty_argv"
jq '.argv = []' "$CHECKPOINT_DIR/cp-one.json" >"$CHECKPOINT_DIR/cp-empty.json"
meta agent checkpoint replay cp-empty
assert_equals 1 "$RC" "rc"
assert_contains "no replayable command" "$ERR" "error"

test_start "checkpoint_unknown_action"
meta agent checkpoint bogus
assert_equals 1 "$RC" "rc"
assert_contains "Usage: dot agent checkpoint" "$ERR" "usage"

# ── delegate ────────────────────────────────────────────────────────────
test_start "delegate_requires_name"
meta agent delegate
assert_equals 1 "$RC" "rc"
assert_contains "Usage: dot agent delegate" "$ERR" "usage"

test_start "delegate_requires_command"
meta agent delegate lint-checker
assert_equals 1 "$RC" "rc"
assert_contains "Usage: dot agent delegate" "$ERR" "usage"

test_start "delegate_disabled_in_shipped_config"
meta agent delegate lint-checker true
assert_equals 1 "$RC" "rc"
assert_contains "Delegation is not enabled" "$ERR" "error"

test_start "delegate_refused_when_profile_cannot_delegate"
NODELEG="$DOTFILES_COV_TMPDIR/nodeleg.json"
jq '.delegation.enabled = true' "$REAL_PROFILES" >"$NODELEG"
AGENT_PROFILE_CONFIG="$NODELEG" meta agent delegate lint-checker true
assert_equals 1 "$RC" "rc"
assert_contains "cannot delegate" "$ERR" "error"

test_start "delegate_unknown_delegate"
AGENT_PROFILE_CONFIG="$STRICT_PROFILES" meta agent delegate nobody true
assert_equals 1 "$RC" "rc"
assert_contains "Unknown delegate: nobody" "$ERR" "error"

test_start "delegate_runs_command_with_delegate_env"
AGENT_PROFILE_CONFIG="$STRICT_PROFILES" meta agent delegate lint-checker \
  bash -c 'echo "d=$DOT_AGENT_DELEGATE parent=$DOT_AGENT_PARENT_PROFILE steps=$DOT_AGENT_MAX_STEPS"'
assert_equals 0 "$RC" "rc"
assert_contains "d=lint-checker parent=ask steps=2" "$OUT" "delegate env"
assert_contains "completed" "$OUT" "success line"

test_start "delegate_reports_failure"
AGENT_PROFILE_CONFIG="$STRICT_PROFILES" meta agent delegate lint-checker bash -c 'exit 4'
assert_equals 4 "$RC" "rc"
assert_contains "failed (exit 4)" "$OUT" "failure line"

# ── delegate without GNU timeout ────────────────────────────────────────
# Regression: the arm was `if timeout "$delegate_timeout" "$@"`. `timeout` is
# GNU coreutils; stock macOS ships neither it nor `gtimeout` (that arrives
# only with `brew install coreutils`), so on a clean Mac the delegated command
# never ran at all — `dot agent delegate` is unusable on the platform this
# repo primarily targets. $NOTIME is a curated bin dir with everything the
# command needs and no timeout binary of either name.
NOTIME="$DOTFILES_COV_TMPDIR/no-timeout-bin"
mkdir -p "$NOTIME"
for _t in bash sh env jq sed awk grep cat date mkdir rm mv cp mktemp dirname \
  basename head tail tr cut sort uniq wc uname tput stty ls find chmod touch \
  comm realpath readlink id hostname sleep perl; do
  _p="$(command -v "$_t" 2>/dev/null || true)"
  [[ -n "$_p" ]] && ln -sf "$_p" "$NOTIME/$_t"
done
test_start "delegate_bin_dir_has_no_timeout"
assert_file_not_exists "$NOTIME/timeout" "the curated PATH must not contain timeout"
assert_file_not_exists "$NOTIME/gtimeout" "the curated PATH must not contain gtimeout"

test_start "delegate_runs_the_command_without_a_timeout_binary"
PATH="$NOTIME" AGENT_PROFILE_CONFIG="$STRICT_PROFILES" \
  meta agent delegate lint-checker bash -c 'printf "delegated-ran\n"'
assert_equals 0 "$RC" "rc"
assert_contains "delegated-ran" "$OUT" "the delegated command ran"
assert_contains "completed" "$OUT" "success line"

test_start "delegate_propagates_failure_without_a_timeout_binary"
PATH="$NOTIME" AGENT_PROFILE_CONFIG="$STRICT_PROFILES" \
  meta agent delegate lint-checker bash -c 'exit 4'
assert_equals 4 "$RC" "rc"
assert_contains "failed (exit 4)" "$OUT" "the command's own status survives the fallback"

test_start "delegate_enforces_the_limit_without_a_timeout_binary"
# The fallback must still bound the command, not merely run it. 124 is GNU
# timeout's expiry status, which the perl fallback reproduces.
FAST="$DOTFILES_COV_TMPDIR/fast-profiles.json"
jq '.rbac.enforcement = "strict" | .delegation.enabled = true
    | .profiles.ask.canDelegate = true
    | .delegation.allowedDelegates["lint-checker"].timeout = 1' \
  "$REAL_PROFILES" >"$FAST"
PATH="$NOTIME" AGENT_PROFILE_CONFIG="$FAST" \
  meta agent delegate lint-checker bash -c 'sleep 20'
assert_equals 124 "$RC" "an over-running delegate is killed and reported as 124"

test_start "delegate_runs_unbounded_only_as_a_last_resort"
# No timeout binary AND no perl: the command must still run, and the lost
# guarantee must be announced rather than assumed.
NOPERL="$DOTFILES_COV_TMPDIR/no-perl-bin"
mkdir -p "$NOPERL"
for _f in "$NOTIME"/*; do
  [[ "$(basename "$_f")" == "perl" ]] && continue
  ln -sf "$(readlink "$_f")" "$NOPERL/$(basename "$_f")"
done
PATH="$NOPERL" AGENT_PROFILE_CONFIG="$STRICT_PROFILES" \
  meta agent delegate lint-checker bash -c 'printf "unbounded-ran\n"'
assert_equals 0 "$RC" "rc"
assert_contains "unbounded-ran" "$OUT" "the delegated command still ran"
assert_contains "without a time limit" "$OUT$ERR" "the missing bound is announced"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
