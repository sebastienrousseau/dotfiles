#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural coverage for scripts/diagnostics/perf.sh: the per-tool timing
# reader (--by-tool / --reset), the measurement + scoring path (kept to a
# single shell and a single run so the suite stays fast), the JSON report,
# and baseline write / compare / regression reporting.
#
# Everything runs against the sandbox HOME, so the baseline and timing files
# written here live in the sandbox and never touch the real cache.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

PERF="$REPO_ROOT/scripts/diagnostics/perf.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

OUTF="$DOTFILES_COV_TMPDIR/perf-out.txt"
TIMINGS="$XDG_STATE_HOME/dotfiles/eval-timings.jsonl"
BASELINE="$XDG_CACHE_HOME/dotfiles/perf-baseline.json"
mkdir -p "$(dirname "$TIMINGS")" "$(dirname "$BASELINE")"

# perf <args…> — run perf.sh, report to $OUTF, status in RC. stderr stays
# attached so the child's xtrace still reaches the coverage trace.
perf() {
  bash "$PERF" "$@" >"$OUTF" </dev/null
  RC=$?
  return 0
}
out_has() { assert_file_contains "$OUTF" "$1" "${2:-output contains $1}"; }

test_start "script_exists_and_parses"
assert_file_exists "$PERF" "perf.sh must exist"
assert_true "bash -n '$PERF'" "valid bash syntax"

# ── --by-tool / --reset ─────────────────────────────────────────────────
test_start "by_tool_without_data_warns_and_exits_0"
: >"$TIMINGS"
perf --by-tool
assert_equals 0 "$RC" "rc"
out_has "no data at" "warning names the file"

test_start "by_tool_aggregates_recorded_timings"
cat >"$TIMINGS" <<'JSONL'
{"label":"mise","ms":120,"shell":"zsh"}
{"label":"mise","ms":80,"shell":"bash"}
{"label":"starship","ms":40,"shell":"zsh"}
{"label":"starship","ms":10,"shell":"zsh"}
{"label":"broken","ms":"not-a-number","shell":"zsh"}
not json at all

JSONL
perf --by-tool
assert_equals 0 "$RC" "rc"
out_has "Per-tool timing breakdown" "header"
out_has "mise" "slowest tool listed first"
out_has "starship" "second tool listed"
assert_true "grep -qE 'mise +2 +200ms' '$OUTF'" "count and total aggregated"

test_start "reset_clears_the_timing_log"
perf --reset
assert_equals 0 "$RC" "rc"
out_has "cleared" "confirmation"
assert_equals "0" "$(wc -c <"$TIMINGS" | tr -d ' ')" "log truncated"

test_start "reset_then_by_tool_reports_the_now_empty_log"
printf '{"label":"x","ms":1,"shell":"zsh"}\n' >"$TIMINGS"
perf --reset --by-tool
assert_equals 0 "$RC" "rc"
out_has "cleared" "reset ran"
out_has "no data at" "and then found nothing to report"

# ── measurement + report ────────────────────────────────────────────────
test_start "unknown_shell_filter_has_nothing_to_measure"
perf --shell definitely-not-a-shell
assert_equals 1 "$RC" "rc"
out_has "no measurable shells found" "error"
out_has "filter: definitely-not-a-shell" "filter echoed"

test_start "json_report_has_the_documented_shape"
# Per-shell targets come from DOTFILES_PERF_TARGET_<SHELL>_MS (bash defaults
# to 60ms); pin it high so a loaded machine cannot make the verdict flaky.
export DOTFILES_PERF_TARGET_BASH_MS=100000
perf --json --shell bash --runs 1 --target 100000
assert_equals 0 "$RC" "rc"
assert_equals "1" "$(jq -r .runs <"$OUTF")" "runs"
assert_equals "100" "$(jq -r .score <"$OUTF")" "score is 100 under a huge target"
assert_equals "true" "$(jq -r '.shells.bash.pass' <"$OUTF")" "bash passes"
assert_equals "0" "$(jq -r .regression_count <"$OUTF")" "no regressions yet"
assert_true "[[ \$(jq -r '.shells.bash.mean_ms' <'$OUTF') -ge 0 ]]" "mean recorded"

test_start "an_impossible_target_scores_zero"
# TARGET 0 with MAX 1ms puts any real measurement past the zero-score floor,
# and a per-shell bash target of 0 makes the pass/fail column fail too.
export DOTFILES_PERF_MAX_MS=1 DOTFILES_PERF_TARGET_BASH_MS=0
perf --json --shell bash --runs 1 --target 0
assert_equals 0 "$RC" "rc"
assert_equals "0" "$(jq -r .score <"$OUTF")" "score floors at 0"
assert_equals "false" "$(jq -r '.shells.bash.pass' <"$OUTF")" "bash fails its target"

test_start "human_report_renders_the_per_shell_table"
perf --shell bash --runs 1 --target 100000 --no-baseline-check
assert_equals 0 "$RC" "rc"
out_has "Shell Performance" "header"
out_has "Per-shell startup" "section"
out_has "bash" "shell row"
out_has "Excellent" "verdict for a passing score"

test_start "a_missed_target_is_reported_with_the_overshoot"
perf --shell bash --runs 1 --target 0 --no-baseline-check
assert_equals 0 "$RC" "rc"
out_has "over by" "overshoot detail"
out_has "Needs attention" "verdict for a zero score"
unset DOTFILES_PERF_MAX_MS
export DOTFILES_PERF_TARGET_BASH_MS=100000

test_start "a_score_between_the_floors_follows_the_documented_formula"
# Between the two floors the score is interpolated. The measured mean is
# whatever the machine gives us, so the oracle recomputes the documented
# formula from the report's own numbers instead of guessing a band.
export DOTFILES_PERF_MAX_MS=100000 DOTFILES_PERF_TARGET_BASH_MS=100000
perf --json --shell bash --runs 1 --target 1
assert_equals 0 "$RC" "rc"
mean="$(jq -r .mean_ms <"$OUTF")"
target="$(jq -r .target_ms <"$OUTF")"
max="$(jq -r .max_ms_target <"$OUTF")"
score="$(jq -r .score <"$OUTF")"
if [[ "$mean" -le "$target" ]]; then
  expected=100
elif [[ "$mean" -ge "$max" ]]; then
  expected=0
else
  expected=$((100 - (mean - target) * 100 / (max - target)))
fi
assert_equals "$expected" "$score" "score interpolates between target and max"
assert_true "[[ $mean -gt $target && $mean -lt $max ]]" "the measurement sits in the interpolated band"

test_start "a_score_below_100_is_reported_as_good_or_needs_attention"
# A 200ms ceiling puts any real shell startup below a perfect score.
export DOTFILES_PERF_MAX_MS=200
perf --shell bash --runs 1 --target 1 --no-baseline-check
assert_equals 0 "$RC" "rc"
# Which of the two non-perfect verdicts applies depends on how loaded the
# machine is, so accept the pair and reject the perfect one.
assert_true "grep -qE 'Good \(tune to reach 100\)|Needs attention' '$OUTF'" "non-perfect verdict"
assert_true "! grep -q 'Excellent' '$OUTF'" "not reported as excellent"
unset DOTFILES_PERF_MAX_MS
export DOTFILES_PERF_TARGET_BASH_MS=100000

test_start "zsh_is_measured_with_its_own_target"
# zsh is the reference shell for the headline score, and has its own
# per-shell target arm in shell_target_for.
perf --json --shell zsh --runs 1 --target 100000
assert_equals 0 "$RC" "rc"
assert_true "[[ \$(jq -r '.shells.zsh.mean_ms' <'$OUTF') -ge 0 ]]" "zsh measured"
assert_equals "$(jq -r .mean_ms <"$OUTF")" "$(jq -r '.shells.zsh.mean_ms' <"$OUTF")" "headline mean comes from zsh"

test_start "profile_flag_adds_the_zprof_section"
perf --shell bash --runs 1 --target 100000 --no-baseline-check --profile
assert_equals 0 "$RC" "rc"
out_has "Top contributors (zprof)" "section"

# ── baseline ────────────────────────────────────────────────────────────
test_start "baseline_flag_writes_the_measured_means"
rm -f "$BASELINE"
perf --shell bash --runs 1 --target 100000 --baseline --no-baseline-check
assert_equals 0 "$RC" "rc"
assert_file_exists "$BASELINE" "baseline written"
assert_true "[[ \$(jq -r '.shells.bash' <'$BASELINE') -ge 0 ]]" "bash mean recorded"
assert_equals "10" "$(jq -r .regression_pct <"$BASELINE")" "default threshold recorded"
out_has "wrote baseline to" "confirmation"

test_start "a_matching_baseline_reports_no_regression"
printf '{"recorded_at":"2026-01-01T00:00:00Z","regression_pct":10,"shells":{"bash":100000}}\n' >"$BASELINE"
perf --shell bash --runs 1 --target 100000
assert_equals 0 "$RC" "rc"
out_has "within" "all shells within the threshold"

test_start "a_regressed_baseline_is_reported_with_the_delta"
printf '{"recorded_at":"2026-01-01T00:00:00Z","regression_pct":10,"shells":{"bash":1}}\n' >"$BASELINE"
perf --shell bash --runs 1 --target 100000
assert_equals 0 "$RC" "rc"
out_has "Baseline regressions" "section"
out_has "vs baseline 1 ms" "delta line"
out_has "threshold: >10%" "threshold echoed"

test_start "regressions_are_listed_in_the_json_report"
perf --json --shell bash --runs 1 --target 100000
assert_equals 0 "$RC" "rc"
assert_equals "1" "$(jq -r .regression_count <"$OUTF")" "regression counted"
assert_true "jq -e '.regressions[0] | test(\"^bash: \")' <'$OUTF' >/dev/null" "regression text"

test_start "no_baseline_check_skips_the_comparison"
perf --shell bash --runs 1 --target 100000 --no-baseline-check
assert_equals 0 "$RC" "rc"
assert_true "! grep -q 'Baseline regressions' '$OUTF'" "comparison skipped"

test_start "an_unreadable_baseline_is_ignored"
printf 'not json\n' >"$BASELINE"
perf --shell bash --runs 1 --target 100000
assert_equals 0 "$RC" "rc"
assert_true "! grep -q 'Baseline regressions' '$OUTF'" "no regressions from a broken file"

test_start "unknown_flags_are_ignored"
rm -f "$BASELINE"
perf --definitely-not-a-flag --shell bash --runs 1 --target 100000
assert_equals 0 "$RC" "rc"
out_has "Shell Performance" "still ran"

test_start "perf_requires_python3"
NOPY="$DOTFILES_COV_TMPDIR/nopy"
mkdir -p "$NOPY"
IFS=: read -ra _dirs <<<"$PATH"
_link_dirs() {
  local _d
  for _d in "$@"; do
    [[ -d "$_d" ]] && ln -s "$_d"/* "$NOPY"/ 2>/dev/null
  done
  return 0
}
# Building the farm expands to `ln -s` calls with ~900 arguments each; under
# the coverage runner each is an xtrace record tens of KB long, and records
# that big come back truncated, corrupting the trace around them. Trace-off
# for the farm only.
_xtrace_was_on=0
case "$-" in *x*) _xtrace_was_on=1 ;; esac
set +x
# System dirs first: a PATH entry may hold a *directory* whose name shadows a
# real command (PowerShell ships a `tr` locale dir); the prune pass then drops
# any link that did not resolve to a file.
_link_dirs /usr/bin /bin /usr/sbin /sbin
_link_dirs "${_dirs[@]}"
for _l in "$NOPY"/*; do [[ -f "$_l" ]] || rm -f "$_l"; done
_link_dirs /usr/bin /bin /usr/sbin /sbin
rm -f "$NOPY/python3"
# Keep the *current* bash: on macOS the farm would otherwise resolve `bash`
# to /bin/bash 3.2, whose xtrace truncates the PS4 expansion at 100 chars —
# every coverage record from the child would be malformed and dropped.
ln -sf "$(command -v bash)" "$NOPY/bash"
[[ "$_xtrace_was_on" == "1" ]] && set -x
PATH="$NOPY" perf --json
assert_equals 1 "$RC" "rc"
assert_true "! grep -q runs '$OUTF'" "no report produced"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
