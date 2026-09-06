#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural coverage for the profile arms of scripts/dot/commands/agent.sh
# (`cmd_mode`: current/list/show/set/run/doctor/card/log) driven through the
# real dispatcher (`meta.sh mode|agent …`) inside the coverage sandbox. Each
# arm gets a success path and each `die` guard a failure path; results are
# asserted on exit code, stdout, stderr and files written under $HOME.
#
# Split across three files (…_dispatch / …_checkpoint / …_a2a) so each stays
# well inside the coverage runner's 60s per-file budget.
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

test_start "module_defines_cmd_mode"
assert_file_contains "$AGENT_MODULE" "cmd_mode()" "agent.sh defines cmd_mode"

# ── current / list / show ───────────────────────────────────────────────
test_start "mode_no_args_reports_current_profile_from_state_file"
meta mode
assert_equals 0 "$RC" "rc"
assert_contains "Agent Mode" "$OUT" "header"
assert_contains "ask" "$OUT" "sandbox state file says ask"

test_start "mode_flag_only_falls_back_to_current"
meta mode --verbose
assert_equals 0 "$RC" "rc"
assert_contains "Profile" "$OUT" "current arm ran"

test_start "mode_current_without_state_file_uses_default_profile"
AGENT_STATE_FILE="$HOME/.config/dotfiles/does-not-exist.env" meta mode current
assert_equals 0 "$RC" "rc"
assert_contains "ask" "$OUT" "defaultProfile is ask"

test_start "mode_list_marks_current"
meta mode list
assert_equals 0 "$RC" "rc"
assert_contains "Agent Modes" "$OUT" "header"
assert_contains "[current]" "$OUT" "current marker"
assert_contains "plan" "$OUT" "other profiles listed"

test_start "agent_alias_dispatches_to_cmd_mode"
meta agent list
assert_equals 0 "$RC" "rc"
assert_contains "Agent Modes" "$OUT" "alias works"

test_start "mode_show_requires_name"
meta mode show
assert_equals 1 "$RC" "rc"
assert_contains "Usage: dot mode show" "$ERR" "usage on stderr"

test_start "mode_show_rejects_unknown_profile"
meta mode show nope
assert_equals 1 "$RC" "rc"
assert_contains "Unknown agent profile: nope" "$ERR" "error"

test_start "mode_show_prints_profile_fields"
meta mode show plan
assert_equals 0 "$RC" "rc"
assert_contains "Max steps" "$OUT" "maxSteps row"
assert_contains "Description" "$OUT" "description row"

# ── set (+ RBAC) ────────────────────────────────────────────────────────
test_start "mode_set_requires_name"
meta mode set
assert_equals 1 "$RC" "rc"
assert_contains "Usage: dot mode set" "$ERR" "usage"

test_start "mode_set_rejects_unknown_profile"
meta mode set nope
assert_equals 1 "$RC" "rc"
assert_contains "Unknown agent profile" "$ERR" "error"

test_start "mode_set_writes_state_file"
STATE="$HOME/.config/dotfiles/agent-mode.env"
meta mode set plan
assert_equals 0 "$RC" "rc"
assert_file_contains "$STATE" "DOT_AGENT_PROFILE=plan" "profile persisted"
assert_file_contains "$STATE" "DOT_AGENT_MAX_STEPS=" "policy fields persisted"
assert_file_contains "$SESSIONS" '"event":"set"' "session log appended"

test_start "mode_set_advisory_rbac_warns_but_proceeds"
printf 'DOT_AGENT_PROFILE=ask\nDOT_AGENT_ROLE=viewer\n' >"$STATE"
meta mode set apply
assert_equals 0 "$RC" "rc (advisory)"
assert_contains "RBAC" "$OUT" "advisory warning printed"
assert_file_contains "$STATE" "DOT_AGENT_PROFILE=apply" "still applied"

STRICT_PROFILES="$DOTFILES_COV_TMPDIR/strict-profiles.json"
jq '.rbac.enforcement = "strict" | .delegation.enabled = true | .profiles.ask.canDelegate = true' \
  "$REAL_PROFILES" >"$STRICT_PROFILES"

test_start "mode_set_strict_rbac_refuses"
printf 'DOT_AGENT_PROFILE=ask\nDOT_AGENT_ROLE=viewer\n' >"$STATE"
AGENT_PROFILE_CONFIG="$STRICT_PROFILES" meta mode set apply
assert_equals 1 "$RC" "rc"
assert_contains "enforcement: strict" "$ERR" "strict refusal"
assert_file_contains "$STATE" "DOT_AGENT_PROFILE=ask" "state untouched"
printf 'DOT_AGENT_PROFILE=ask\n' >"$STATE"

# ── run ─────────────────────────────────────────────────────────────────
test_start "mode_run_requires_command"
meta mode run
assert_equals 1 "$RC" "rc"
assert_contains "Usage: dot mode run" "$ERR" "usage"

test_start "mode_run_uses_current_profile_and_exports_env"
meta mode run bash -c 'echo "p=$DOT_AGENT_PROFILE fs=$DOT_AGENT_FILESYSTEM"'
assert_equals 0 "$RC" "rc"
assert_contains "p=ask fs=read-only" "$OUT" "profile env exported to child"
assert_file_contains "$SESSIONS" '"event":"run_finish"' "run logged"

test_start "mode_run_with_explicit_profile"
meta mode run plan bash -c 'echo "p=$DOT_AGENT_PROFILE"'
assert_equals 0 "$RC" "rc"
assert_contains "p=plan" "$OUT" "explicit profile"

test_start "mode_run_propagates_failure_exit_code"
meta mode run bash -c 'exit 3'
assert_equals 3 "$RC" "child rc propagated"
assert_file_contains "$SESSIONS" '"status":"failed"' "failure logged"

# ── doctor ──────────────────────────────────────────────────────────────
test_start "mode_doctor_ok"
meta mode doctor
assert_equals 0 "$RC" "rc"
assert_contains "Default profile" "$OUT" "default profile reported"

test_start "mode_doctor_invalid_json"
printf '{not json' >"$DOTFILES_COV_TMPDIR/bad.json"
AGENT_PROFILE_CONFIG="$DOTFILES_COV_TMPDIR/bad.json" meta mode doctor
assert_equals 1 "$RC" "rc"
assert_contains "Invalid JSON" "$ERR" "error"

test_start "mode_doctor_missing_default_profile"
jq 'del(.defaultProfile)' "$REAL_PROFILES" >"$DOTFILES_COV_TMPDIR/nodefault.json"
AGENT_PROFILE_CONFIG="$DOTFILES_COV_TMPDIR/nodefault.json" meta mode doctor
assert_equals 1 "$RC" "rc"
assert_contains "Default profile missing" "$ERR" "error"

test_start "mode_dies_when_profile_config_missing"
AGENT_PROFILE_CONFIG="$DOTFILES_COV_TMPDIR/absent.json" meta mode list
assert_equals 1 "$RC" "rc"
assert_contains "Agent profile config not found" "$ERR" "error"

test_start "mode_dies_without_jq"
NOJQ="$DOTFILES_COV_TMPDIR/nojq"
mkdir -p "$NOJQ"
# Link every PATH entry into one farm, minus jq, so `command -v jq` fails
# while the rest of the environment still works. System dirs are linked
# first because a PATH entry may hold a *directory* whose name shadows a
# real command (PowerShell ships a `tr` locale dir); the pruning pass then
# drops any link that did not resolve to a file.
IFS=: read -ra _dirs <<<"$PATH"
_link_dirs() {
  local _d
  for _d in "$@"; do
    [[ -d "$_d" ]] && ln -s "$_d"/* "$NOJQ"/ 2>/dev/null
  done
  return 0
}
_link_dirs /usr/bin /bin /usr/sbin /sbin
_link_dirs "${_dirs[@]}"
for _l in "$NOJQ"/*; do [[ -f "$_l" ]] || rm -f "$_l"; done
_link_dirs /usr/bin /bin /usr/sbin /sbin
rm -f "$NOJQ/jq"
PATH="$NOJQ" meta mode list
assert_equals 1 "$RC" "rc"
assert_contains "jq is required" "$ERR" "error"

# ── card / log ──────────────────────────────────────────────────────────
test_start "mode_card_renders_table"
meta mode card
assert_equals 0 "$RC" "rc"
assert_contains "Agent Card" "$OUT" "header"
assert_contains "Protocols" "$OUT" "protocol row"

test_start "mode_card_json_cats_file"
meta mode card --json
assert_equals 0 "$RC" "rc"
assert_true "printf '%s' \"\$OUT\" | jq -e .name >/dev/null" "raw JSON emitted"

test_start "mode_card_missing_file"
AGENT_CARD_CONFIG="$DOTFILES_COV_TMPDIR/no-card.json" meta mode card
assert_equals 1 "$RC" "rc"
assert_contains "Agent card not found" "$ERR" "error"

test_start "mode_log_tails_sessions"
meta mode log 2
assert_equals 0 "$RC" "rc"
assert_contains '"event":"log"' "$OUT" "tail contains the log event itself"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
