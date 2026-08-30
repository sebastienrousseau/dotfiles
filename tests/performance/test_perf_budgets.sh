#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Performance budgets — one place, tiered targets, measured baselines.
#
# ── The tiers ──────────────────────────────────────────────────────
#
#   INSTANT (≤  500ms) — anything a human sees in a shell prompt
#     * dot version / dot --version
#     * dot help / dot help <cmd>
#     * dot search <keyword>
#     * The iCloud script itself (one full pass)
#     * Version-consistency gate
#     * docs-coverage gate
#     * iCloud regression safety test (9 assertions)
#
#   FAST    (≤ 2000ms) — heavier gates + sandboxed CLI reads
#     * dot status
#     * dot diff
#     * traceability-coverage gate
#     * iCloud unit test (29 assertions with fs sandbox setup)
#     * test_dot_subcommand_smoke
#     * test_dot_help_registry_symmetry
#
#   MEDIUM  (≤ 5000ms) — full diagnostics runs
#     * dot doctor
#     * tests/performance/bench.sh (quick mode)
#
#   ACCEPTED-SLOW (documented, best-effort)
#     * test_dot_help_flag_universal — invokes dot help --help on ~100
#       commands via a subshell each; ~11s is legitimate for the
#       coverage it provides. Not gated here; tracked in wall-clock
#       ratchet (tests/performance/test_help_gates_wall_clock.sh).
#
#   OUT-OF-SCOPE — multi-minute operations we do not gate per-run
#     * chezmoi apply (fresh macOS: minutes)
#     * install.sh (downloads packages)
#     * dot upgrade (mise + chezmoi + pkgmgr)
#     * Full test suite
#
# All thresholds carry ≥2× headroom over the reference-machine
# median so CI-runner variance doesn't cause flakes. When a real
# regression happens, the median jumps outside the headroom band.
#
# Baseline captured on 2026-08-30, rousseau-cachyos-geekom-a9,
# Ryzen AI 9 HX 370. CI runners are usually 1.5-2× slower.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

DOT_CLI="$REPO_ROOT/bin/dot"
ICLOUD_TMPL="$REPO_ROOT/defaults/run_once_before_macos-icloud-symlinks.sh.tmpl"

# ---------------------------------------------------------------------------
# _measure — run a command N times, return median wall-clock ms.
# Uses date +%s%N for high-resolution timing (bash builtin timings
# aren't consistent across shells / macOS bash).
# ---------------------------------------------------------------------------
_measure() {
  local runs="$1"; shift
  local times=() total=0
  local i start_ns end_ns
  for ((i=0; i<runs; i++)); do
    start_ns=$(date +%s%N)
    "$@" >/dev/null 2>&1 || true
    end_ns=$(date +%s%N)
    times+=("$(( (end_ns - start_ns) / 1000000 ))")
  done
  # median
  local sorted
  IFS=$'\n' sorted=($(printf '%s\n' "${times[@]}" | sort -n))
  unset IFS
  local mid=$((runs / 2))
  printf '%s' "${sorted[$mid]}"
}

_gate() {
  local label="$1" budget_ms="$2" runs="$3"; shift 3
  local median
  median="$(_measure "$runs" "$@")"
  if [[ "$median" -le "$budget_ms" ]]; then
    ((TESTS_PASSED++)) || true
    printf '  \033[0;32m✓\033[0m %s: median=%sms budget=%sms\n' \
      "$CURRENT_TEST" "$median" "$budget_ms"
  else
    ((TESTS_FAILED++)) || true
    printf '  \033[0;31m✗\033[0m %s: median=%sms EXCEEDS budget=%sms\n' \
      "$CURRENT_TEST" "$median" "$budget_ms"
  fi
}

# Sandbox HOME so cold reads don't hit real ~/.zsh_history etc.
_sandbox() {
  local sb
  sb="$(mktemp -d)"
  export HOME="$sb"
  export XDG_CONFIG_HOME="$sb/.config"
  export XDG_DATA_HOME="$sb/.local/share"
  export XDG_CACHE_HOME="$sb/.cache"
  export XDG_STATE_HOME="$sb/.local/state"
  mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME/dotfiles"
  export CHEZMOI_SOURCE_DIR="$REPO_ROOT"
  # iCloud mock for icloud-script perf test
  mkdir -p "$sb/Library/Mobile Documents/com~apple~CloudDocs"
  export DOTFILES_NO_BANNER=1
  printf '%s\n' "$sb"
}

# =============================================================================
# TIER 1: INSTANT (≤500ms)
# =============================================================================
_sandbox >/dev/null

test_start "instant_dot_version"
_gate "$CURRENT_TEST" 500 5 bash "$DOT_CLI" version

test_start "instant_dot_help"
_gate "$CURRENT_TEST" 500 5 bash "$DOT_CLI" help

test_start "instant_dot_help_doctor"
_gate "$CURRENT_TEST" 500 5 bash "$DOT_CLI" help doctor

test_start "instant_dot_help_theme"
_gate "$CURRENT_TEST" 500 5 bash "$DOT_CLI" help theme

test_start "instant_dot_help_apply"
_gate "$CURRENT_TEST" 500 5 bash "$DOT_CLI" help apply

test_start "instant_dot_search"
_gate "$CURRENT_TEST" 500 5 bash "$DOT_CLI" search theme

test_start "instant_icloud_script_single_run"
# Render darwin-guarded template to a plain script
_rendered="$(mktemp)"
sed -e '/^{{- if eq \.chezmoi\.os "darwin" -}}$/d' \
    -e '/^{{- end -}}$/d' \
    "$ICLOUD_TMPL" > "$_rendered"
_gate "$CURRENT_TEST" 500 5 bash "$_rendered"
rm -f "$_rendered"

test_start "instant_check_version_consistency"
_gate "$CURRENT_TEST" 500 5 bash "$REPO_ROOT/scripts/qa/check-version-consistency.sh"

test_start "instant_docs_coverage"
_gate "$CURRENT_TEST" 500 5 bash "$REPO_ROOT/scripts/qa/docs-coverage.sh"

test_start "instant_icloud_regression_test"
_gate "$CURRENT_TEST" 500 5 bash "$REPO_ROOT/tests/regression/test_macos_icloud_symlinks_safety.sh"

# =============================================================================
# TIER 2: FAST (≤2000ms)
# =============================================================================

test_start "fast_traceability_coverage"
_gate "$CURRENT_TEST" 2000 3 bash "$REPO_ROOT/scripts/qa/traceability-coverage.sh"

test_start "fast_icloud_unit_test"
_gate "$CURRENT_TEST" 2000 3 bash "$REPO_ROOT/tests/unit/misc/test_macos_icloud_symlinks.sh"

test_start "fast_dot_subcommand_smoke"
_gate "$CURRENT_TEST" 2000 3 bash "$REPO_ROOT/tests/regression/test_dot_subcommand_smoke.sh"

test_start "fast_dot_help_registry_symmetry"
_gate "$CURRENT_TEST" 2000 3 bash "$REPO_ROOT/tests/regression/test_dot_help_registry_symmetry.sh"

test_start "fast_dot_status"
_gate "$CURRENT_TEST" 2000 3 bash "$DOT_CLI" status

test_start "fast_dot_diff"
_gate "$CURRENT_TEST" 2000 3 bash "$DOT_CLI" diff

# =============================================================================
# TIER 3: MEDIUM (≤5000ms)
# =============================================================================

test_start "medium_dot_doctor"
_gate "$CURRENT_TEST" 5000 3 bash "$DOT_CLI" doctor

# tests/performance/bench.sh has been observed at ~2s; give it 5s headroom
test_start "medium_bench_quick_mode"
if [[ -f "$REPO_ROOT/tests/performance/bench.sh" ]]; then
  _gate "$CURRENT_TEST" 5000 3 bash "$REPO_ROOT/tests/performance/bench.sh" --quick
else
  ((TESTS_PASSED++)) || true
  printf '  \033[0;33m~\033[0m %s (bench.sh not executable — skipped)\n' "$CURRENT_TEST"
fi

# =============================================================================
# Summary
# =============================================================================
printf '\n  Tests: %d  \033[0;32mPassed: %d\033[0m  \033[0;31mFailed: %d\033[0m\n' \
  "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
printf 'RESULTS:%d:%d:%d\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
exit "$TESTS_FAILED"
