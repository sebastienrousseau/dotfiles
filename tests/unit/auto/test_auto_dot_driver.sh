#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Driver test that invokes the top-level `dot` dispatcher against
# every read-only subcommand. The point is line coverage for
# scripts/dot/commands/*.sh + scripts/dot/lib/*.sh which are sourced
# by `dot` but never executed standalone (they only define functions).
#
# Slice 5 of #883: dispatcher-driver coverage. Strictly read-only —
# every command listed here either prints state or returns rc!=0
# without touching the host.
#
# AUTO-GENERATED: true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

DOT="$REPO_ROOT/dot_local/bin/executable_dot"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "dot_exists"
assert_file_exists "$DOT" "dot dispatcher must exist"

# Resolve a portable timeout binary (matches cov_exercise_script).
TIMEOUT_BIN=""
if command -v timeout >/dev/null 2>&1; then
  TIMEOUT_BIN="timeout"
elif command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_BIN="gtimeout"
fi
TC=()
if [[ -n "$TIMEOUT_BIN" ]]; then
  TC=("$TIMEOUT_BIN" --kill-after=2 15)
fi

# Pre-seed minimal state so commands that read config find sensible
# defaults instead of erroring out.
mkdir -p "$HOME/.config/dotfiles"
printf '{}\n' >"$HOME/.config/dotfiles/agent-profiles.json" || true

# Subcommand probe list: each entry is a label + the dot invocation
# (positional args, space-separated). We deliberately use read-only
# and `--help` variants so the sandbox can't be perturbed.
declare -a PROBES=(
  "help            help"
  "help_all        help all"
  "help_doctor     help doctor"
  "version         version"
  "version_flag    --version"
  "search          search ai"
  "agent_help      agent --help"
  "agent_list      agent list"
  "agent_card      agent card"
  "mode_list       mode list"
  "mode_show       mode show ask"
  "mode_help       mode --help"
  "ai_help         ai --help"
  "ai_status       ai"
  "secrets_list    secrets list"
  "secrets_help    secrets --help"
  "tools_help      tools --help"
  "tools_list      tools list"
  "fleet_help      fleet --help"
  "fleet_status    fleet status --json"
  "meta_help       meta --help"
  "diagnostics_help diagnostics --help"
  "doctor_help     doctor --help"
  "verify_help     verify --help"
  "snapshot_help   snapshot --help"
  "perf_help       perf --help"
  "restore_help    restore --help"
  "restore_list    restore -l"
  "rollback_help   rollback --help"
  "security_help   security --help"
  "appearance_help appearance --help"
  "appearance_list appearance list"
  "core_help       core --help"
  "core_status     status"
  "core_diff       diff"
  "core_env        env"
  "core_profile    profile"
  "core_learn      learn"
  "aliases_help    aliases --help"
  # Additional read-only probes to broaden coverage of sub-dispatchers.
  "rollback_list   rollback list"
  "rollback_show   rollback show 0"
  "security_score  security-score --help"
  "security_q      security-score -q"
  "agent_run_help  agent run --help"
  "agent_doctor    agent doctor"
  "agent_card_json agent card --json"
  "agent_a2acard   agent a2a-card"
  "agent_show_ask  agent show ask"
  "agent_log       agent log"
  "agent_ckpt      agent checkpoint list"
  "agent_conf      agent conformance"
  "mode_show_plan  mode show plan"
  "mode_show_apl   mode show apply"
  "mode_show_aud   mode show audit"
  "ai_query_help   ai-query --help"
  "ai_setup_help   ai-setup --help"
  "tools_status    tools status"
  "tools_doctor    tools doctor"
  "fleet_drift     fleet drift --json"
  "fleet_help2     fleet --json"
  "doctor_score    doctor --score"
  "doctor_json     doctor --json"
  "doctor_h        doctor -H"
  "perf_json       perf -j -r 1"
  "snapshot_b      snapshot -b"
  # `verify -s` calls into security-score which under high parallelism
  # hits `fork: Resource temporarily unavailable` on macOS hosts and
  # times out. The dot driver is exercised in macOS-local runs as
  # well as CI — drop the probe so the test stays deterministic.
  # "verify_s        verify -s"
  "attest_json     attest --json"
  "fleet_status_j  fleet status --json"
  "restore_help2   restore -L"
)

set +e
for entry in "${PROBES[@]}"; do
  label="${entry%% *}"
  cmd="${entry#* }"
  cmd="${cmd# }"
  test_start "dot_${label}"
  # `$cmd` is INTENDED to word-split into separate argv entries
  # (e.g. `agent list` → `agent`, `list`). Quoting it would pass
  # the whole string as a single positional arg.
  # Keep stderr connected so bash xtrace from sub-shells is captured
  # by the parent test runner; `2>&1 >/dev/null` would suppress it.
  # shellcheck disable=SC2086
  "${TC[@]}" bash "$DOT" $cmd </dev/null >/dev/null
  rc=$?
  # rc 124 = timeout (hung subcommand). Anything else = ran to exit.
  if [[ "$rc" -ne 124 ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=$rc)"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: timeout"
  fi
done

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
