#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# preamble:skip
#
# This is a test-framework script, not a program: it uses the same assertion
# helpers as tests/, reports every budget it breaches rather than dying on the
# first, and measures commands whose non-zero exit is the thing being asserted.
# `set -e` would abort at the first violation and turn a full report into a
# single line. It lived under tests/ — which the preamble check skips for
# exactly this reason — until benches/ became the home for timing work.
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
#     * benches/bench.sh (quick mode)
#
#   ACCEPTED-SLOW (documented, best-effort)
#     * test_dot_help_flag_universal — invokes dot help --help on ~100
#       commands via a subshell each; ~11s is legitimate for the
#       coverage it provides. Not gated here; tracked in wall-clock
#       ratchet (benches/test_help_gates_wall_clock.sh).
#
#   OUT-OF-SCOPE — multi-minute operations we do not gate per-run
#     * chezmoi apply (fresh macOS: minutes)
#     * install.sh (downloads packages)
#     * dot upgrade (mise + chezmoi + pkgmgr)
#     * Full test suite
#
# All thresholds carry ≥2× headroom over the reference-machine
# median, and are scaled by a runner factor measured in the same run
# (see "Runner calibration" below), so a slow CI runner doesn't cause
# flakes. When a real regression happens, the median jumps outside
# the headroom band whatever the factor.
#
# Baseline captured on 2026-08-30, rousseau-cachyos-geekom-a9,
# Ryzen AI 9 HX 370. CI runners are usually 1.5-2× slower.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/.." && pwd)}"
# The assertions framework lives under tests/, not beside this file: benches/
# is a sibling of tests/, so it is addressed from the repository root rather
# than relative to SCRIPT_DIR.
source "$REPO_ROOT/tests/framework/assertions.sh"

# Overridable so the breakage-detection path can be exercised against a
# deliberately corrupted CLI without touching the real one.
DOT_CLI="${DOT_CLI:-$REPO_ROOT/bin/dot}"
ICLOUD_TMPL="$REPO_ROOT/defaults/run_before_macos-icloud-symlinks.sh.tmpl"

# ---------------------------------------------------------------------------
# _time_once <command...> — run once; print "<exit status> <ms>".
#
# Timing comes from the `time` keyword with TIMEFORMAT, not from
# `date +%s%N`. %N is a GNU extension: BSD date, which is what macOS 14 and
# earlier ship, copies the literal "N" through. Every arithmetic below then
# died on "value too great for base", _measure returned nothing, and an empty
# median compares as 0 against any budget — so on those machines this gate
# reported every budget met, including for a CLI that could not parse. It was
# the silently-passing gate this file exists to argue against, and it went
# unnoticed because the runner that exposed it, macos-14, is the only one in
# the matrix old enough to have a date without %N.
#
# The `time` keyword is a shell builtin, present and millisecond-accurate in
# bash 3.2, and needs no external clock at all. LC_ALL is pinned because
# TIMEFORMAT renders the decimal separator per locale. Prints
# "CLOCK_UNUSABLE <raw>" and returns 1 when the reading does not parse.
# ---------------------------------------------------------------------------
_time_once() {
  local elapsed secs ms rc_file rc
  local TIMEFORMAT='%3R'
  rc_file="$(mktemp)"
  # F2: capture the exit status instead of discarding it. A command that
  # crashes instantly is FAST, and the old `|| true` let it sail through
  # its budget — a broken `dot` reported excellent performance. The status
  # is written to a file because `time` needs the command inside its own
  # group, whose exit status the substitution below does not carry out.
  elapsed="$(
    LC_ALL=C
    { time {
      "$@" >/dev/null 2>&1
      printf '%s' "$?" >"$rc_file"
    }; } 2>&1
  )"
  rc="$(cat "$rc_file")"
  rm -f "$rc_file"
  # "1.234" -> 1234. Split on the decimal point rather than using floating
  # point, which the shell has none of.
  secs="${elapsed%%.*}"
  ms="${elapsed##*.}"
  if [[ ! "$secs" =~ ^[0-9]+$ ]] || [[ ! "$ms" =~ ^[0-9]{3}$ ]]; then
    printf 'CLOCK_UNUSABLE %s' "$elapsed"
    return 1
  fi
  printf '%s %s' "$rc" "$((10#$secs * 1000 + 10#$ms))"
}

# _median <n...> — read the sorted list line by line rather than
# word-splitting a command substitution: mapfile is bash 4, and macOS ships
# bash 3.2.
_median() {
  local sorted=() _t
  while IFS= read -r _t; do
    sorted+=("$_t")
  done < <(printf '%s\n' "$@" | sort -n)
  printf '%s' "${sorted[$(($# / 2))]}"
}

# ---------------------------------------------------------------------------
# Runner calibration (docs/operations/PERFORMANCE_BUDGETS.md has the detail).
#
# Every gate is fork/exec-heavy shell, so its wall clock tracks the runner's
# spawn speed as much as our code: on shared macos-latest runners unchanged
# code measured 3109-10149ms (smoke) and 3433-10293ms (help-registry
# symmetry), and five samples did not stop them failing main.
#
# So each sample of each gate is paired with a sample of a fixed workload,
# timed just before it: CALIBRATION_SPAWNS starts of the `bash` the gates
# resolve from PATH, each running one command substitution. Its median
# per-spawn cost over CALIBRATION_REF_US is the gate's runner factor, and the
# budget is multiplied by max(1, factor):
#
#   * Per sample, not once up front: the red runs had one gate over budget
#     while its neighbour passed, so the runner slowed down mid-run.
#   * Never below 1: a faster runner gets no tighter budget than the doc's,
#     and Linux, where a spawn costs a fraction of the macOS reference, runs
#     at exactly its old budgets.
#   * Past CALIBRATION_CAP_PCT the gate fails and says the runner is too slow
#     to gate on, instead of scaling the budget until nothing can fail.
#   * Every wall-clock gate uses it, not only the two that flaked: they share
#     the runner and are all spawn-heavy (docs and traceability flaked the
#     same way, see the sample counts below). The factor moves only when the
#     reference workload slows down, so a change that slows one gated command
#     past its budget's headroom still fails at any factor.
#
# Reference: median of 7 runs of PERF_GATE_FILTER=instant_dot_version on an
# Apple A18 Pro MacBook (8 GB, macOS 26.6, Homebrew bash 5.3.20 first on
# PATH), 2026-10-23. Refresh it with the same command on the machine the
# budgets are measured on, in the same PR as any budget change:
#   for i in 1 2 3 4 5 6 7; do PERF_GATE_FILTER=instant_dot_version \
#     bash benches/test_perf_budgets.sh | grep -o 'per_spawn=[0-9]*'; done
# PERF_CALIBRATION_REF_US overrides it for one run.
# ---------------------------------------------------------------------------
CALIBRATION_SPAWNS=30
CALIBRATION_REF_US="${PERF_CALIBRATION_REF_US:-5800}"
CALIBRATION_CAP_PCT=400
if [[ ! "$CALIBRATION_REF_US" =~ ^[1-9][0-9]*$ ]]; then
  printf 'PERF_CALIBRATION_REF_US must be a positive integer (got %s)\n' "$CALIBRATION_REF_US" >&2
  exit 2
fi

# The workload is a file rather than a function so that it runs in a `bash`
# resolved from PATH, exactly like the gated commands; it is written after
# _sandbox, into the sandbox HOME.
_write_calibration_workload() {
  CALIBRATION_WORKLOAD="$HOME/perf-calibration-workload.sh"
  cat >"$CALIBRATION_WORKLOAD" <<'WORKLOAD'
i=0
while [ "$i" -lt "$1" ]; do
  bash --noprofile --norc -c 'x=$(printf ok)' || exit 1
  i=$((i + 1))
done
WORKLOAD
}

# _pct_text 250 -> "2.50x"
_pct_text() { printf '%d.%02dx' "$(($1 / 100))" "$(($1 % 100))"; }

# ---------------------------------------------------------------------------
# _measure <runs> <command...> — print
# "<worst exit status> <median ms> <median calibration ms>", each run timing
# the calibration workload and then the command. Anything unmeasurable comes
# back as a non-numeric first field, which every caller treats as a failure.
# ---------------------------------------------------------------------------
_measure() {
  local runs="$1"
  shift
  local times=() cals=() worst_rc=0 i out
  for ((i = 0; i < runs; i++)); do
    out="$(_time_once bash "$CALIBRATION_WORKLOAD" "$CALIBRATION_SPAWNS")" || {
      printf '%s' "$out"
      return 0
    }
    if [[ "${out%% *}" != 0 ]]; then
      printf 'CALIBRATION_FAILED exit=%s' "${out%% *}"
      return 0
    fi
    cals+=("${out##* }")
    out="$(_time_once "$@")" || {
      printf '%s' "$out"
      return 0
    }
    [[ "${out%% *}" -gt "$worst_rc" ]] && worst_rc="${out%% *}" # mutation: ignore equivalent: -ge only adds the equal case, which assigns the same value
    times+=("${out##* }")
  done
  printf '%s %s %s' "$worst_rc" "$(_median "${times[@]}")" "$(_median "${cals[@]}")"
}

# _scaled_budget <budget_ms> <runner_pct> — budget x runner factor x
# PERF_BUDGET_PERCENT. The last is for meta-testing: PERF_BUDGET_PERCENT=0
# makes every budget impossible at any factor, which is how
# tests/regression/test_gate_integrity.sh proves this gate actually fails
# rather than merely existing.
_scaled_budget() {
  printf '%s' "$(($1 * $2 * ${PERF_BUDGET_PERCENT:-100} / 10000))"
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
  local max_rc="$1" label="$2" base_ms="$3" runs="$4" out failed median cal
  shift 4
  _gate_selected "$label" || return 0
  test_start "$label"
  out="$(_measure "$runs" "$@")"
  read -r failed median cal <<<"$out"
  # A gate that could not measure must fail, not pass. These fields go through
  # `-gt` / `-le`, and bash reads a non-numeric operand there as 0 — so
  # without this an unusable clock would have silently satisfied every budget,
  # which is exactly how the BSD-date breakage stayed invisible.
  if [[ ! "$failed" =~ ^[0-9]+$ ]] || [[ ! "$median" =~ ^[0-9]+$ ]] ||
    [[ ! "$cal" =~ ^[0-9]+$ ]]; then
    _gate_fail "$label" "could not measure (got $out) — refusing to report a pass"
  elif [[ "$failed" -gt "$max_rc" ]]; then
    _gate_fail "$label" "exited $failed (max allowed $max_rc) — timing is meaningless"
    _show_failure_output "$@"
  else
    _budget_verdict "$label" "$base_ms" "$median" "$cal"
  fi
}

_gate_fail() {
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s: %s\n' "$1" "$2"
}

# _budget_verdict <label> <budget_ms> <median_ms> <calibration_ms>
_budget_verdict() {
  local label="$1" base_ms="$2" median="$3" per_spawn_us pct budget_ms runner
  per_spawn_us=$(($4 * 1000 / CALIBRATION_SPAWNS))
  pct=$((per_spawn_us * 100 / CALIBRATION_REF_US))
  [[ "$pct" -lt 100 ]] && pct=100 # mutation: ignore equivalent: -le only adds pct=100, which it sets to 100
  runner="runner=$(_pct_text "$pct") per_spawn=${per_spawn_us}us reference=${CALIBRATION_REF_US}us"
  if [[ "$pct" -gt "$CALIBRATION_CAP_PCT" ]]; then
    _gate_fail "$label" "median=${median}ms; $runner exceeds the $(_pct_text "$CALIBRATION_CAP_PCT") cap — this runner is too slow to gate on"
    return 0
  fi
  budget_ms="$(_scaled_budget "$base_ms" "$pct")"
  if [[ "$median" -le "$budget_ms" ]]; then
    ((TESTS_PASSED++)) || true
    printf '  \033[0;32m✓\033[0m %s: median=%sms budget=%sms (%s)\n' \
      "$label" "$median" "$budget_ms" "$runner"
  else
    _gate_fail "$label" "median=${median}ms EXCEEDS budget=${budget_ms}ms ($runner)"
  fi
}

# Re-run a failed command once with output captured. An exit code with no
# context is undebuggable in CI, where you cannot reproduce the environment
# by hand.
_show_failure_output() {
  local diag
  diag="$("$@" 2>&1 | tail -25)"
  if [[ -n "$diag" ]]; then
    printf '%s\n' "$diag" | sed 's/^/        | /'
  else
    printf '        | (command produced no output)\n'
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

# Sourced (tests/unit/diagnostics/test_perf_budgets_functions.sh): stop with
# the functions defined, before any gate runs.
[[ "${BASH_SOURCE[0]}" == "$0" ]] || return 0

# =============================================================================
# TIER 1: INSTANT (≤500ms)
# =============================================================================
_sandbox >/dev/null
_write_calibration_workload

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
  "$ICLOUD_TMPL" >"$_rendered"
_gate "instant_icloud_script_single_run" 500 5 bash "$_rendered"
rm -f "$_rendered"

# =============================================================================
# TIER 2: FAST (≤2000ms)
# =============================================================================

# =============================================================================
# TIER 3: MEDIUM (≤5000ms)
# =============================================================================

# `dot status` and `dot diff` were first placed in FAST at 2000ms against
# reference medians of 1510ms and 1420ms — 1.3x and 1.4x headroom, below the
# >= 2x this file requires of every budget. The gate never actually ran until
# now (it died sourcing its framework), so nothing measured them on a hosted
# runner. The first real run did: 2290ms / 2157ms on macOS and 2329ms / 2136ms
# on Ubuntu. Two unrelated platforms agreeing within 8% is a property of the
# commands, not of one slow runner — both shell out to chezmoi, which walks the
# whole source tree, and that is disk-bound. MEDIUM is where their measured
# cost puts them: 2.1x headroom over the worst observed, so a genuine doubling
# still fails. Lowering the bar to fit a measurement would be worth objecting
# to; this is the first measurement the bar was ever set against.
_gate "medium_dot_status" 5000 3 bash "$DOT_CLI" status

_gate "medium_dot_diff" 5000 3 bash "$DOT_CLI" diff

_gate_diag "medium_dot_doctor" 5000 3 bash "$DOT_CLI" doctor

# benches/bench.sh has been observed at ~2s; give it 5s headroom
if [[ -f "$REPO_ROOT/benches/bench.sh" ]]; then
  _gate_diag "medium_bench_quick_mode" 5000 3 bash "$REPO_ROOT/benches/bench.sh" --quick
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

# Sample counts. The three gates below with 5 runs were tight on the
# macos-latest runner: across 27 CI runs (2026-09-24/25) their 3-run medians
# peaked at 1518/2000ms (docs coverage), 2610/3500ms (iCloud unit) and
# 4688/5000ms (traceability; typical ~2700ms, local 2107ms), and one run
# on a slow runner measured 6095ms and failed main with no code change.
# A median of 5 needs three slow samples rather than two; the budgets stay
# at 2x the local median, so a real regression still fails.
_gate "gate_check_version_consistency" 500 5 bash "$REPO_ROOT/scripts/qa/check-version-consistency.sh"

_gate "gate_docs_coverage" 2000 5 bash "$REPO_ROOT/scripts/qa/docs-coverage.sh"

_gate "gate_icloud_regression_test" 1000 5 bash "$REPO_ROOT/tests/regression/test_macos_icloud_symlinks_safety.sh"

# Hashes the whole sandbox tree before and after each scenario, so it costs
# more than the canary-file suite above and is measured separately. Local
# median 1575ms; 5000ms keeps >3x headroom, which the disk-bound work here
# needs on a hosted runner.
_gate "gate_icloud_manifest_test" 5000 3 bash "$REPO_ROOT/tests/regression/test_macos_icloud_symlinks_manifest.sh"

_gate "gate_icloud_unit_test" 3500 5 bash "$REPO_ROOT/tests/unit/misc/test_macos_icloud_symlinks.sh"

_gate "gate_traceability_coverage" 5000 5 bash "$REPO_ROOT/scripts/qa/traceability-coverage.sh"

# Both took 3 runs until they failed main the same way: on 2026-10-23 their
# macos-latest medians ranged 3109-10149ms (smoke) and 3433-10293ms
# (symmetry) on near-identical code, and each of three red main runs had
# one gate over budget while the other passed. Five samples did not fix it
# (smoke measured 8064ms on 2026-10-23 at 18:08): the runner itself was slow,
# which is what the calibration factor above now absorbs. The budgets stay at
# 2x the reference-machine median.
_gate "gate_dot_subcommand_smoke" 7500 5 bash "$REPO_ROOT/tests/regression/test_dot_subcommand_smoke.sh"

_gate "gate_dot_help_registry_symmetry" 9000 5 bash "$REPO_ROOT/tests/regression/test_dot_help_registry_symmetry.sh"

# =============================================================================
# Summary
# =============================================================================
printf '\n  Tests: %d  \033[0;32mPassed: %d\033[0m  \033[0;31mFailed: %d\033[0m\n' \
  "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
printf 'RESULTS:%d:%d:%d\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
exit "$TESTS_FAILED"
