#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Driver test that invokes the top-level `dot` dispatcher against
# every read-only subcommand. The point is line coverage for
# scripts/dot/commands/*.sh + lib/dot/*.sh which are sourced
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

DOT="$REPO_ROOT/bin/dot"

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
  # 60s rather than 15s. `dot doctor` runs a system audit (mise list,
  # brew list, package introspection, etc.) which routinely brushes
  # past 15s when 8 test files are running in parallel and share the
  # same CPU + filesystem cache. 60s aligns with cov_exercise_script
  # and absorbs the worst observed `dot doctor --json` wall-time.
  TC=("$TIMEOUT_BIN" --kill-after=2 60)
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
  # `verify --help` routes through diagnostics.sh which sources
  # security-score; under high parallelism that trips fork limits
  # on macOS. Same family as the verify_s probe disabled earlier.
  # "verify_help     verify --help"
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
  # ── Agent subcommand sweep (closes #883 coverage roadmap incrementally) ──
  "agent_current   agent current"
  "agent_show_plan agent show plan"
  "agent_show_apl  agent show apply"
  "agent_show_aud  agent show audit"
  "agent_log_help  agent log --help"
  "agent_ckpt_save agent checkpoint save --help"
  "agent_ckpt_show agent checkpoint show --help"
  "agent_conf_h    agent conformance --help"
  "agent_conf_json agent conformance --json"
  "agent_delegate  agent delegate --help"
  # ── Tools subcommand sweep ──
  "tools_help_all  tools help"
  "tools_aliases   tools alias-check"
  "tools_env       tools env"
  "tools_profile   tools profile"
  "tools_packages  tools packages"
  "tools_log_rot   tools log-rotate --help"
  "tools_setup_h   tools setup --help"
  "tools_new_h     tools new --help"
  "tools_install_h tools install --help"
  "tools_use_h     tools use --help"
  "tools_show_h    tools show --help"
  "tools_set_h     tools set --help"
  # ── Rollback read-only paths (status / list are safe; rollback writes are skipped) ──
  "rollback_stat   rollback status"
  "rollback_h_long rollback help"
  # ── AI bridge dispatch — the bridges resolve their patterns and exit
  #    cleanly when no prompt is given. Each one exercises a different
  #    arm of run_ai_with_context. Stderr noise is fine; we only care
  #    that the branch line was traced.
  "ai_bridge_help  cl --help"
  "ai_bridge_codex codex --help"
  "ai_bridge_cop   copilot --help"
  "ai_bridge_agy   agy --help"
  "ai_bridge_goose goose --help"
  "ai_bridge_kiro  kiro --help"
  "ai_bridge_sgpt  sgpt --help"
  "ai_bridge_oll   ollama --help"
  "ai_bridge_opc   opencode --help"
  "ai_bridge_aide  aider --help"
  "ai_bridge_auto  autohand --help"
  "ai_bridge_vibe  vibe --help"
  "ai_bridge_qwen  qwen --help"
  "ai_bridge_zai   zai --help"
  # ── Fleet drift + namespace ──
  "fleet_namesp    fleet namespace"
  "fleet_drift     fleet drift"
  # ── Meta subcommands ──
  "meta_h          meta help"
  # ── Search variants ──
  "search_doctor   search doctor"
  "search_theme    search theme"
  "search_secrets  search secrets"
  # ── Core read-only ──
  "core_managed    managed"
  "core_doctor_q   doctor -q"
  "core_health_h   health --help"
  "core_health_j   health -j"
  # ── Help individual commands ──
  "help_ai         help ai"
  "help_mode       help mode"
  "help_agent      help agent"
  "help_theme      help theme"
  "help_perf       help perf"
  "help_fleet      help fleet"
  "help_tools      help tools"
  "help_security   help security"
  "help_secrets    help secrets"
  # ── MCP diagnostics flags ──
  "mcp_help        mcp --help"
  "mcp_json        mcp --json"
  "mcp_strict      mcp --strict"
  "mcp_sj          mcp -s -j"
  "mcp_registry    mcp registry"
  # ── doctor flags ──
  "doctor_ai       doctor --ai"
  # ── fleet drift / namespace variants ──
  "fleet_drift_h   fleet drift history"
  "fleet_drift_p   fleet drift predict"
  "fleet_drift_c   fleet drift check"
  "fleet_ns_set    fleet namespace set engineering"
  # ── manual subcommand probes ──
  "manual_help     manual --help"
  "manual_open     manual open"
  "manual_dl_help  manual download --help"
  # ── env probes ──
  "env_help        env --help"
  # ── profile probes ──
  "profile_help    profile --help"
  "profile_show    profile show"
  # ── secrets probes ──
  "secrets_get_h   secrets get --help"
  "secrets_set_h   secrets set --help"
  "secrets_load_h  secrets load --help"
  "secrets_prov_h  secrets provider --help"
  # ── attest variants ──
  "attest_help     attest --help"
  "attest_default  attest"
  # ── learn ──
  "learn_help      learn --help"
  # ── Agent state-change probes (sandbox HOME isolates writes) ──
  "agent_set_ask     agent set ask"
  "agent_set_plan    agent set plan"
  "agent_set_apply   agent set apply"
  "agent_set_audit   agent set audit"
  "agent_set_bad     agent set nonexistent-profile"
  "agent_run_echo    agent run ask echo hello"
  "agent_ckpt_save_l agent checkpoint save --label drive-test"
  "agent_card_strict agent card --strict"
  "agent_conf_strict agent conformance --strict --json"
  "agent_a2a_val     agent a2a-card --validate"
  # ── Theme read-only ──
  "theme_help        theme --help"
  "theme_list        theme list"
  # ── Help via search ──
  "search_help       search help"
  "search_dark       search dark"
  # ── §3 strategic commands (agents/init/registry/fleet apply) ──
  "agents_help       agents --help"
  "agents_list       agents list"
  "agents_check      agents check"
  "init_help         init --help"
  "init_dry_alice    init alice --dry-run"
  "init_dry_owner    init alice/cfg --dry-run"
  "init_dry_https    init https://example.com/r.git --dry-run"
  "init_rejects_http init http://example.com/r.git --dry-run"
  "registry_help     registry --help"
  "registry_url      registry url"
  "registry_install_stub registry install some-module"
  "fleet_apply_help  fleet apply --help"
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
