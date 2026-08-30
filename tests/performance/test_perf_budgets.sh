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
#     * iCloud regression safety test (10 assertions, budget 600ms)
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

# Overridable so the breakage-detection path can be exercised against a
# deliberately corrupted CLI without touching the real one.
DOT_CLI="${DOT_CLI:-$REPO_ROOT/bin/dot}"
ICLOUD_TMPL="$REPO_ROOT/defaults/run_before_macos-icloud-symlinks.sh.tmpl"

# ---------------------------------------------------------------------------
# _measure — run a command N times, return median wall-clock ms.
# Uses date +%s%N for high-resolution timing (bash builtin timings
# aren't consistent across shells / macOS bash).
# ---------------------------------------------------------------------------
_measure() {
  local runs="$1"; shift
  local times=() worst_rc=0 rc=0
  local i start_ns end_ns
  for ((i=0; i<runs; i++)); do
    start_ns=$(date +%s%N)
    # F2: capture the exit status instead of discarding it. A command that
    # crashes instantly is FAST, and the old `|| true` let it sail through
    # its budget — a broken `dot` reported excellent performance.
    "$@" >/dev/null 2>&1 || rc=$?
    end_ns=$(date +%s%N)
    # Bookkeeping AFTER the clock stops, so it is not counted in the median.
    [[ "$rc" -gt "$worst_rc" ]] && worst_rc="$rc"
    rc=0
    times+=("$(( (end_ns - start_ns) / 1000000 ))")
  done
  # median
  local sorted
  IFS=$'\n' sorted=($(printf '%s\n' "${times[@]}" | sort -n))
  unset IFS
  local mid=$((runs / 2))
  printf '%s %s' "$worst_rc" "${sorted[$mid]}"
}

# Budgets can be scaled for meta-testing: PERF_BUDGET_PERCENT=0 makes every
# budget impossible, which is how tests/regression/test_gate_integrity.sh
# proves this gate actually fails rather than merely existing.
_scaled_budget() {
  printf '%s' "$(($1 * ${PERF_BUDGET_PERCENT:-100} / 100))"
}

# PERF_GATE_FILTER runs only gates whose label contains the given substring.
# Skipped gates never call test_start, so TESTS_RUN == PASSED + FAILED holds
# (the invariant tests/regression/test_test_framework_invariants.sh enforces).
_gate_selected() {
  case "$1" in
    *"${PERF_GATE_FILTER:-}"*) return 0 ;;
    *) return 1 ;;
  esac
}

# _gate <label> <budget_ms> <runs> <command...>
#   Requires exit 0. Use for anything that should simply succeed.
_gate() { _gate_max_rc 0 "$@"; }

# _gate_diag — same, but tolerates exit 1.
#   Diagnostics report findings through their exit status: `dot doctor`
#   exits 1 when it finds issues (it does so on a healthy machine too), and
#   bench.sh exits 1 when a shell breaches its own startup threshold. Both
#   still RAN, so their timing is meaningful. Anything >= 2 — not-found,
#   permission, signal, syntax error — is still a hard failure, so this is
#   far narrower than the blanket `|| true` it replaces.
_gate_diag() { _gate_max_rc 1 "$@"; }

_gate_max_rc() {
  local max_rc="$1" label="$2" budget_ms="$3" runs="$4"
  shift 4
  _gate_selected "$label" || return 0
  test_start "$label"
  budget_ms="$(_scaled_budget "$budget_ms")"
  local out failed median
  out="$(_measure "$runs" "$@")"
  failed="${out%% *}"
  median="${out##* }"
  if [[ "$failed" -gt "$max_rc" ]]; then
    ((TESTS_FAILED++)) || true
    printf '  \033[0;31m✗\033[0m %s: exited %s (max allowed %s) — timing is meaningless\n' \
      "$label" "$failed" "$max_rc"
    # Re-run once with output captured. An exit code with no context is
    # undebuggable in CI, where you cannot reproduce the environment by hand.
    local diag
    diag="$("$@" 2>&1 | tail -25)"
    if [[ -n "$diag" ]]; then
      printf '%s\n' "$diag" | sed 's/^/        | /'
    else
      printf '        | (command produced no output)\n'
    fi
  elif [[ "$median" -le "$budget_ms" ]]; then
    ((TESTS_PASSED++)) || true
    printf '  \033[0;32m✓\033[0m %s: median=%sms budget=%sms\n' \
      "$label" "$median" "$budget_ms"
  else
    ((TESTS_FAILED++)) || true
    printf '  \033[0;31m✗\033[0m %s: median=%sms EXCEEDS budget=%sms\n' \
      "$label" "$median" "$budget_ms"
  fi
}

# =============================================================================
# TIER 0: SELF-TEST — the gate must be able to fail.
# =============================================================================
# Runs on every pass. If breakage detection is ever removed from _measure,
# this fails here rather than silently green-lighting a broken CLI.
_selftest_rejects_broken() {
  _gate_selected "selftest_gate_rejects_broken_command" || return 0
  test_start "selftest_gate_rejects_broken_command"
  local out failed
  out="$(_measure 2 /nonexistent/definitely-not-a-real-binary --version)"
  failed="${out%% *}"
  # 127 = not found. Any non-zero proves the status reached the caller.
  if [[ "$failed" -ne 0 ]]; then
    ((TESTS_PASSED++)) || true
    printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '  \033[0;31m✗\033[0m %s: a broken command was measured as healthy\n' \
      "$CURRENT_TEST"
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
  # chezmoi resolves its source dir under XDG_DATA_HOME. Without this the
  # sandbox has none, so `dot status` / `diff` / `doctor` all abort with
  # "no such file or directory" — and before breakage detection existed,
  # those gates were silently timing the failure path, not the command.
  ln -s "$REPO_ROOT" "$XDG_DATA_HOME/chezmoi"
  # iCloud mock for icloud-script perf test
  mkdir -p "$sb/Library/Mobile Documents/com~apple~CloudDocs"
  export DOTFILES_NO_BANNER=1
  printf '%s\n' "$sb"
}

# =============================================================================
# TIER 1: INSTANT (≤500ms)
# =============================================================================
_sandbox >/dev/null

_selftest_rejects_broken

_gate "instant_dot_version" 500 5 bash "$DOT_CLI" version

_gate "instant_dot_help" 500 5 bash "$DOT_CLI" help

_gate "instant_dot_help_doctor" 500 5 bash "$DOT_CLI" help doctor

_gate "instant_dot_help_theme" 500 5 bash "$DOT_CLI" help theme

_gate "instant_dot_help_apply" 500 5 bash "$DOT_CLI" help apply

_gate "instant_dot_search" 500 5 bash "$DOT_CLI" search theme

# Render darwin-guarded template to a plain script
_rendered="$(mktemp)"
sed -e '/^{{- if eq \.chezmoi\.os "darwin" -}}$/d' \
    -e '/^{{- end -}}$/d' \
    "$ICLOUD_TMPL" > "$_rendered"
_gate "instant_icloud_script_single_run" 500 5 bash "$_rendered"
rm -f "$_rendered"




# =============================================================================
# TIER 2: FAST (≤2000ms)
# =============================================================================





_gate "fast_dot_status" 2000 3 bash "$DOT_CLI" status

_gate "fast_dot_diff" 2000 3 bash "$DOT_CLI" diff

# =============================================================================
# TIER 3: MEDIUM (≤5000ms)
# =============================================================================

_gate_diag "medium_dot_doctor" 5000 3 bash "$DOT_CLI" doctor

# tests/performance/bench.sh has been observed at ~2s; give it 5s headroom
if [[ -f "$REPO_ROOT/tests/performance/bench.sh" ]]; then
  _gate_diag "medium_bench_quick_mode" 5000 3 bash "$REPO_ROOT/tests/performance/bench.sh" --quick
else
  # Absent bench.sh is not a pass — skip silently rather than bump a counter
  # without a matching test_start, which would break the framework invariant
  # TESTS_RUN == TESTS_PASSED + TESTS_FAILED.
  printf '  \033[0;33m~\033[0m medium_bench_quick_mode (bench.sh absent — not measured)\n'
fi


# =============================================================================
# TIER 4: GATES — CI quality gates and test suites
# =============================================================================
# These are NOT interactive operations, so the instant/fast ceilings (which
# describe latency a human perceives at a prompt) never applied to them. They
# get individual budgets from the doc's own rule — 2x the measured median —
# taken on the SLOWEST supported platform rather than the fastest.
#
# That last part matters: the previous budgets came solely from a Ryzen Linux
# desktop, where these run 3-6x faster than on macOS (fork/exec is markedly
# more expensive here, and every gate is fork-heavy shell). CI covers Linux
# AND macOS, so a Linux-only calibration cannot hold — which is why five of
# these sat red. Medians below measured on rousseau-mbp-m1, 2026-08-30.
#
#   docs-coverage.sh          ~930ms  -> 2000
#   check-version-consistency ~ <50ms -> 500   (unchanged; genuinely fast)
#   iCloud regression test    ~475ms  -> 1000
#   iCloud unit test          ~1620ms -> 3500
#   traceability-coverage.sh  ~2390ms -> 5000
#   dot_subcommand_smoke      ~3620ms -> 7500
#   dot_help_registry_symmetry ~4420ms -> 9000
#
# The iCloud regression budget replaces an earlier ad-hoc 500->600ms nudge
# made to accommodate a newly added assertion. 1000ms comes from the same
# 2x rule as every other entry here, so it is calibrated rather than fudged.

_gate "gate_check_version_consistency" 500 5 bash "$REPO_ROOT/scripts/qa/check-version-consistency.sh"

_gate "gate_docs_coverage" 2000 3 bash "$REPO_ROOT/scripts/qa/docs-coverage.sh"

_gate "gate_icloud_regression_test" 1000 5 bash "$REPO_ROOT/tests/regression/test_macos_icloud_symlinks_safety.sh"

_gate "gate_icloud_unit_test" 3500 3 bash "$REPO_ROOT/tests/unit/misc/test_macos_icloud_symlinks.sh"

_gate "gate_traceability_coverage" 5000 3 bash "$REPO_ROOT/scripts/qa/traceability-coverage.sh"

_gate "gate_dot_subcommand_smoke" 7500 3 bash "$REPO_ROOT/tests/regression/test_dot_subcommand_smoke.sh"

_gate "gate_dot_help_registry_symmetry" 9000 3 bash "$REPO_ROOT/tests/regression/test_dot_help_registry_symmetry.sh"

# =============================================================================
# Summary
# =============================================================================
printf '\n  Tests: %d  \033[0;32mPassed: %d\033[0m  \033[0;31mFailed: %d\033[0m\n' \
  "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
printf 'RESULTS:%d:%d:%d\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
exit "$TESTS_FAILED"
