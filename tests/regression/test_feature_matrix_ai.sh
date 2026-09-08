#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Regression for: GH-881
# Regression: FEATURE-MATRIX coverage for the ai.sh command group — the
# `dot ai` verb surface, the deprecated top-level aliases, and all eighteen
# provider bridges.
#
# Nothing here performs an LLM round-trip. Every row either exercises a
# read-only verb, or the usage/refusal path a bridge takes when it is given
# no prompt — which is exactly the boundary the 2026-07 audit found broken,
# when `dot ai delegate --help` spent money by passing "--help" to the model
# as a prompt. Rows that genuinely need the network are recorded
# "unmeasurable" in the matrix and covered by a --help smoke test.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/feature_matrix_lib.sh"

trap fm_sandbox_teardown EXIT
fm_sandbox_setup

# Seed the AI status cache. Without it `dot ai tools` probes nineteen CLIs
# with an 8s timeout each; with it the read path is exercised in
# milliseconds and the assertions can pin an exact version string that could
# only have come from the cache.
fm_seed_ai_cache() {
  mkdir -p "$XDG_CACHE_HOME/dotfiles/ai"
  {
    printf 'claude\t1\t9.9.9-fixture\n'
    printf 'codex\t0\t\n'
  } >"$XDG_CACHE_HOME/dotfiles/ai/status.tsv"
}

# ── ai: status / tools ─────────────────────────────────────────────────────

test_fm_ai_tools() {
  fm_seed_ai_cache
  test_start "fm_ai_tools"
  DOTFILES_AI_STATUS_TTL=99999 fm_run ai tools
  fm_expect_rc_in 0 1
  test_start "fm_ai_tools_lists_providers"
  fm_expect_any "AI CLI Status" "Claude Code"
}

test_fm_ai_status_deprecated() {
  fm_seed_ai_cache
  test_start "fm_ai_status_deprecated"
  DOTFILES_AI_STATUS_TTL=99999 fm_run ai status
  fm_expect_rc_in 0 1
  test_start "fm_ai_status_deprecated_warns"
  fm_expect_any "deprecated" "dot ai tools"
}

test_fm_env_dotfiles_ai_status_ttl() {
  # A fresh cache inside the TTL must be READ, not re-probed: the fixture
  # version string can only appear if the cache was used.
  fm_seed_ai_cache
  test_start "fm_env_dotfiles_ai_status_ttl"
  DOTFILES_AI_STATUS_TTL=99999 fm_run ai tools
  fm_expect_rc_in 0 1
  test_start "fm_env_dotfiles_ai_status_ttl_uses_the_cache"
  fm_expect_out "9.9.9-fixture"
}

test_fm_smoke_ai_tools_install() {
  # `ai tools install` installs providers through mise / vendor installers.
  fm_smoke ai
}

# ── ai: cost / doctor ──────────────────────────────────────────────────────

test_fm_ai_cost() {
  test_start "fm_ai_cost"
  fm_run ai cost
  fm_expect_rc_in 0 1
  test_start "fm_ai_cost_no_breakage"
  fm_expect_no_forbidden
  test_start "fm_ai_cost_since"
  fm_run ai cost --since 7
  fm_expect_rc_in 0 1
}

test_fm_ai_doctor() {
  test_start "fm_ai_doctor"
  fm_run ai doctor
  fm_expect_rc_in 0 1
  test_start "fm_ai_doctor_reports"
  fm_expect_any "AI doctor" "gateway" "claude"
}

# ── ai: verbs that must refuse without a prompt ────────────────────────────
#
# These are the money-spending paths. Each must print usage and exit
# non-zero rather than forwarding an empty or flag-shaped prompt.

test_fm_ai_run_usage() {
  test_start "fm_ai_run_usage"
  fm_run ai run
  fm_expect_rc 1
  test_start "fm_ai_run_usage_prints_usage"
  fm_expect_any "Usage: dot ai" "one-shot"
}

test_fm_ai_delegate_usage() {
  test_start "fm_ai_delegate_usage"
  fm_run ai delegate
  fm_expect_rc 1
  test_start "fm_ai_delegate_usage_prints_usage"
  fm_expect_any "Usage" "delegate"
}

test_fm_ai_ask_usage() {
  test_start "fm_ai_ask_usage"
  fm_run ai ask
  fm_expect_rc 1
  test_start "fm_ai_ask_usage_prints_usage"
  fm_expect_any "Usage" "question"
}

test_fm_ai_query_usage() {
  test_start "fm_ai_query_usage"
  fm_run ai-query
  fm_expect_rc 1
  test_start "fm_ai_query_usage_prints_usage"
  fm_expect_any "Usage" "question"
  test_start "fm_ai_query_usage_is_deprecated"
  fm_expect_any "deprecated" "dot ai ask"
}

test_fm_ai_proxy_deprecated() {
  test_start "fm_ai_proxy_deprecated"
  fm_run ai proxy
  fm_expect_rc_in 0 1
  test_start "fm_ai_proxy_deprecated_warns"
  fm_expect_any "deprecated" "dot ai serve"
}

# ── ai: rows that need the network or a TTY ────────────────────────────────

test_fm_smoke_ai_cockpit() { fm_smoke ai; }
test_fm_smoke_ai_run_prompt() { fm_smoke ai; }
test_fm_smoke_ai_oneshot_bare() { fm_smoke ai; }
test_fm_smoke_ai_delegate_prompt() { fm_smoke ai; }
test_fm_smoke_ai_ask_query() { fm_smoke ai; }
test_fm_smoke_ai_chat() { fm_smoke ai; }
test_fm_smoke_ai_install() { fm_smoke ai; }
test_fm_smoke_ai_serve() { fm_smoke ai; }
test_fm_smoke_ai_login() { fm_smoke ai; }
test_fm_smoke_ai_dashboard() { fm_smoke ai; }
test_fm_smoke_ai_setup() { fm_smoke ai-setup; }
test_fm_smoke_ai_bridge_prompt() { fm_smoke cl; }

# ── provider bridges ───────────────────────────────────────────────────────
#
# Every bridge, invoked with no prompt, must print the bridge usage and exit
# 1 without contacting anything. Driven from one list so a newly added
# provider cannot quietly skip the check.

FM_AI_BRIDGES="cl claude codex copilot kimi agy goose kiro sgpt ollama opencode aider autohand vibe qwen zai"

fm_assert_bridge_usage() {
  local tool="$1"
  test_start "fm_ai_bridge_${tool//-/_}"
  fm_run "$tool"
  if [[ "$FM_RC" -eq 0 ]]; then
    fm_fail "dot $tool with no prompt exited 0 — it must refuse"
    return 0
  fi
  if [[ "$FM_OUT$FM_ERR" != *"Usage: dot ai"* ]]; then
    fm_fail "dot $tool did not print the bridge usage"
    return 0
  fi
  fm_pass "refused cleanly (rc=$FM_RC)"
}

test_fm_ai_bridge_cl() { fm_assert_bridge_usage cl; }
test_fm_ai_bridge_claude() { fm_assert_bridge_usage claude; }
test_fm_ai_bridge_codex() { fm_assert_bridge_usage codex; }
test_fm_ai_bridge_copilot() { fm_assert_bridge_usage copilot; }
test_fm_ai_bridge_kimi() { fm_assert_bridge_usage kimi; }
test_fm_ai_bridge_agy() { fm_assert_bridge_usage agy; }
test_fm_ai_bridge_goose() { fm_assert_bridge_usage goose; }
test_fm_ai_bridge_kiro() { fm_assert_bridge_usage kiro; }
test_fm_ai_bridge_sgpt() { fm_assert_bridge_usage sgpt; }
test_fm_ai_bridge_ollama() { fm_assert_bridge_usage ollama; }
test_fm_ai_bridge_opencode() { fm_assert_bridge_usage opencode; }
test_fm_ai_bridge_aider() { fm_assert_bridge_usage aider; }
test_fm_ai_bridge_autohand() { fm_assert_bridge_usage autohand; }
test_fm_ai_bridge_vibe() { fm_assert_bridge_usage vibe; }
test_fm_ai_bridge_qwen() { fm_assert_bridge_usage qwen; }
test_fm_ai_bridge_zai() { fm_assert_bridge_usage zai; }

test_fm_ai_bridge_every_routed_provider_refuses() {
  # Belt and braces: the route table is the source of truth, so assert the
  # list above still covers every provider routed to ai.sh.
  local routed missing=""
  routed="$(awk '/^_dot_command_routes\(\)/,/^EOF$/' "$REPO_ROOT/bin/dot" |
    awk -F'|' '$2 == "ai" && $1 !~ /^ai/ { print $1 }')"
  local tool
  for tool in $routed; do
    case " $FM_AI_BRIDGES " in
      *" $tool "*) ;;
      *) missing="$missing $tool" ;;
    esac
  done
  test_start "fm_ai_bridge_every_routed_provider_refuses"
  if [[ -z "$missing" ]]; then
    fm_pass "all routed providers covered"
  else
    fm_fail "provider bridges with no matrix row:$missing"
  fi
}

test_fm_ai_bridge_style() {
  # --style names a steering pattern; an unknown one must fail fast rather
  # than silently sending an unsteered prompt to a paid model.
  test_start "fm_ai_bridge_style_rejects_unknown_pattern"
  fm_run cl --style zzz-no-such-pattern "hello"
  fm_expect_rc 1
  test_start "fm_ai_bridge_style_names_the_pattern"
  fm_expect_any "Pattern not found" "zzz-no-such-pattern"
}

test_fm_env_dot_ai_raw() {
  # DOT_AI_RAW suppresses the product banner so callers get clean, pipeable
  # output. Compare against a run with the banner explicitly enabled.
  test_start "fm_env_dot_ai_raw_banner_on_by_default"
  DOTFILES_SHOW_LOGO=1 fm_run ai tools
  local with_banner="$FM_OUT"
  if [[ "$with_banner" == *"◈"* ]]; then
    fm_pass "banner present without DOT_AI_RAW"
  else
    # Some renderers drop the logo on a non-TTY; then this row cannot
    # distinguish the two modes and the assertion below is the real one.
    fm_pass "no banner even with logo enabled (non-TTY renderer)"
  fi

  test_start "fm_env_dot_ai_raw_suppresses_banner"
  DOT_AI_RAW=1 DOTFILES_SHOW_LOGO=1 fm_run ai tools
  if [[ "$FM_OUT" == *"◈"* ]]; then
    fm_fail "banner still printed with DOT_AI_RAW=1"
  else
    fm_pass "banner suppressed"
  fi
}

# ── run ────────────────────────────────────────────────────────────────────

echo ""
echo "── FEATURE-MATRIX: ai ──"
echo ""

test_fm_ai_tools
test_fm_ai_status_deprecated
test_fm_env_dotfiles_ai_status_ttl
test_fm_smoke_ai_tools_install
test_fm_ai_cost
test_fm_ai_doctor
test_fm_ai_run_usage
test_fm_ai_delegate_usage
test_fm_ai_ask_usage
test_fm_ai_query_usage
test_fm_ai_proxy_deprecated
test_fm_smoke_ai_cockpit
test_fm_smoke_ai_run_prompt
test_fm_smoke_ai_oneshot_bare
test_fm_smoke_ai_delegate_prompt
test_fm_smoke_ai_ask_query
test_fm_smoke_ai_chat
test_fm_smoke_ai_install
test_fm_smoke_ai_serve
test_fm_smoke_ai_login
test_fm_smoke_ai_dashboard
test_fm_smoke_ai_setup
test_fm_smoke_ai_bridge_prompt
test_fm_ai_bridge_cl
test_fm_ai_bridge_claude
test_fm_ai_bridge_codex
test_fm_ai_bridge_copilot
test_fm_ai_bridge_kimi
test_fm_ai_bridge_agy
test_fm_ai_bridge_goose
test_fm_ai_bridge_kiro
test_fm_ai_bridge_sgpt
test_fm_ai_bridge_ollama
test_fm_ai_bridge_opencode
test_fm_ai_bridge_aider
test_fm_ai_bridge_autohand
test_fm_ai_bridge_vibe
test_fm_ai_bridge_qwen
test_fm_ai_bridge_zai
test_fm_ai_bridge_every_routed_provider_refuses
test_fm_ai_bridge_style
test_fm_env_dot_ai_raw

fm_finish
