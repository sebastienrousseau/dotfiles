#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Behavioural coverage for scripts/diagnostics/benchmark.sh. Every mode
# (--help, bad flag, basic timing, hyperfine timing with each performance
# rating, --detailed, --waterfall, --profile, --compare) runs against a
# sandboxed HOME with PATH-shadowing shims for zsh, hyperfine, the tool
# initialisers and python3 (a deterministic millisecond clock), so no
# real shell start-up is ever measured and every run is reproducible.
# The gum/TTY branches are driven through a pseudo-terminal so the
# `UI_ENABLED=1` and `UI_COLOR=1` arms execute without a real terminal.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# Keep bash xtrace flowing to the coverage runner's trace stream even
# when a probe below captures `2>&1`.
exec 21>&2
export BASH_XTRACEFD=21

BENCH="$REPO_ROOT/scripts/diagnostics/benchmark.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

MB="$DOTFILES_COV_TMPDIR/bin"
REAL_PY="$(command -v python3)"
REAL_BASH="$(command -v bash)"
REAL_JQ="$(command -v jq || true)"

# ── Shims ────────────────────────────────────────────────────────────
# zsh: returns instantly; under --profile it prints a fake zprof table.
cat >"$MB/zsh" <<'SHIM'
#!/usr/bin/env bash
case "$*" in
  *zprof*) printf 'num  calls  time  self  name\n 1)  1  0.10  0.10  compinit\n' ;;
  *) : ;;
esac
exit 0
SHIM
# Tool initialisers probed by benchmark_components / render_waterfall.
for t in starship atuin zoxide fzf direnv; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"$MB/$t"
done
# python3: deterministic monotonic clock. Each call advances by
# BENCH_PY_STEP ms (default 7) so every time_command() measures a
# stable, non-zero duration; BENCH_PY_STEP=0 yields all-zero timings.
cat >"$MB/python3" <<'SHIM'
#!/usr/bin/env bash
clock="${BENCH_PY_CLOCK:?}"
n=$(cat "$clock" 2>/dev/null || echo 0)
n=$((n + 1))
printf '%s\n' "$n" >"$clock"
printf '%s\n' "$((n * ${BENCH_PY_STEP:-7}))"
SHIM
# hyperfine: writes the --export-json file with a mean taken from
# BENCH_MEAN_S so every performance rating can be selected by the test.
cat >"$MB/hyperfine" <<'SHIM'
#!/usr/bin/env bash
out=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --export-json) out="$2"; shift 2 ;;
    *) shift ;;
  esac
done
mean="${BENCH_MEAN_S:-0.05}"
printf '{"results":[{"mean":%s,"min":%s,"max":%s}]}\n' "$mean" "$mean" "$mean" >"$out"
echo "hyperfine-shim ran"
exit 0
SHIM
# gum: only reached when stdout is a TTY (pty runs below).
cat >"$MB/gum" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  style | format | join) shift; printf '%s\n' "$*" ;;
  *) : ;;
esac
exit 0
SHIM
chmod +x "$MB"/zsh "$MB"/starship "$MB"/atuin "$MB"/zoxide "$MB"/fzf "$MB"/direnv "$MB"/python3 "$MB"/hyperfine "$MB"/gum
ln -sf "$REAL_BASH" "$MB/bash"
[[ -n "$REAL_JQ" ]] && ln -sf "$REAL_JQ" "$MB/jq"

export BENCH_PY_CLOCK="$DOTFILES_COV_TMPDIR/pyclock"
BENCH_DIR="$XDG_DATA_HOME/dotfiles/benchmarks"

# PATH without hyperfine (and without the host's real tools).
PATH_NO_HF="$MB:/usr/bin:/bin"
# PATH with a hyperfine shim.
HF_DIR="$DOTFILES_COV_TMPDIR/hfbin"
mkdir -p "$HF_DIR"
mv "$MB/hyperfine" "$HF_DIR/hyperfine"
PATH_HF="$HF_DIR:$PATH_NO_HF"

reset_clock() { rm -f "$BENCH_PY_CLOCK"; }

# run_bench <PATH> <args…> — sets OUT / RC.
run_bench() {
  local p="$1"
  shift
  reset_clock
  set +e
  OUT="$(PATH="$p" bash "$BENCH" "$@" 2>&1)"
  RC=$?
  set -e
}

# run_bench_pty <PATH> <args…> — same, but stdout is a pseudo-terminal
# so ui_init detects gum + colour (UI_ENABLED=1 / UI_COLOR=1).
run_bench_pty() {
  local p="$1"
  shift
  reset_clock
  set +e
  OUT="$(PATH="$p" TERM=xterm "$REAL_PY" -c '
import os, pty, sys
sys.exit(os.waitstatus_to_exitcode(pty.spawn(sys.argv[1:])))
' bash "$BENCH" "$@" 2>&1 </dev/null)"
  RC=$?
  set -e
}

# ── --help / bad flag ───────────────────────────────────────────────
test_start "benchmark_help"
run_bench "$PATH_NO_HF" --help
assert_equals 0 "$RC" "--help exits 0"
assert_contains "Usage: dot benchmark" "$OUT" "--help prints usage"

test_start "benchmark_short_help"
run_bench "$PATH_NO_HF" -h
assert_equals 0 "$RC" "-h exits 0"

test_start "benchmark_unknown_option"
run_bench "$PATH_NO_HF" --bogus
assert_equals 2 "$RC" "unknown option exits 2"
assert_contains "Unknown option: --bogus" "$OUT" "unknown option is reported"

# ── Basic timing (no hyperfine) ─────────────────────────────────────
test_start "benchmark_basic_timing_without_hyperfine"
run_bench "$PATH_NO_HF"
assert_equals 0 "$RC" "basic timing exits 0"
assert_contains "hyperfine not installed" "$OUT" "falls back to basic timing"
# 5 runs × 7ms step → average 7ms.
assert_contains "Average startup time: 7ms" "$OUT" "average from deterministic clock"
assert_contains "dot benchmark --compare" "$OUT" "prints history tip"

# ── hyperfine timing + every performance rating ─────────────────────
test_start "benchmark_hyperfine_excellent"
run_bench "$PATH_HF"
assert_equals 0 "$RC" "hyperfine path exits 0"
assert_contains "hyperfine-shim ran" "$OUT" "hyperfine is invoked"
assert_contains "Mean: 50ms" "$OUT" "mean parsed from export json"
assert_contains "Excellent (<100ms)" "$OUT" "rating excellent"
assert_file_exists "$BENCH_DIR/latest.json" "latest.json written"
# A timestamped history copy sits alongside latest.json.
hist_count=$(find "$BENCH_DIR" -name '[0-9]*_[0-9]*.json' | wc -l | tr -d ' ')
assert_equals 1 "$hist_count" "one timestamped history file saved"

test_start "benchmark_hyperfine_good"
BENCH_MEAN_S=0.15 run_bench "$PATH_HF"
assert_contains "Good (<200ms)" "$OUT" "rating good"

test_start "benchmark_hyperfine_acceptable"
BENCH_MEAN_S=0.3 run_bench "$PATH_HF"
assert_contains "Acceptable (<500ms)" "$OUT" "rating acceptable"

test_start "benchmark_hyperfine_slow"
BENCH_MEAN_S=0.7 run_bench "$PATH_HF"
assert_contains "Slow (>500ms)" "$OUT" "rating slow"

# ── --detailed ──────────────────────────────────────────────────────
test_start "benchmark_detailed"
run_bench "$PATH_NO_HF" --detailed
assert_equals 0 "$RC" "--detailed exits 0"
assert_contains "Per-Component Timing" "$OUT" "component header"
assert_contains "zshenv (bootloader)" "$OUT" "zshenv row"
for t in starship atuin zoxide fzf direnv; do
  assert_contains "$t init" "$OUT" "$t init row"
done
assert_contains "Average startup time" "$OUT" "detailed still runs the benchmark"

# ── --waterfall ─────────────────────────────────────────────────────
test_start "benchmark_waterfall"
run_bench "$PATH_NO_HF" -w
assert_equals 0 "$RC" "--waterfall exits 0"
assert_contains "Startup Waterfall" "$OUT" "waterfall header"
assert_contains "rc.d/20-zinit (plugins)" "$OUT" "zinit bar"
# 8 components × 7ms.
assert_contains "Total" "$OUT" "total row"
assert_contains "56ms" "$OUT" "total is the sum of component timings"

test_start "benchmark_waterfall_no_timing_data"
BENCH_PY_STEP=0 run_bench "$PATH_NO_HF" --waterfall
assert_equals 0 "$RC" "zero timings exit 0"
assert_contains "No timing data" "$OUT" "warns when nothing was measured"

# ── --profile ───────────────────────────────────────────────────────
test_start "benchmark_profile"
run_bench "$PATH_NO_HF" -p
assert_equals 0 "$RC" "--profile exits 0"
assert_contains "Zsh profiler (zprof)" "$OUT" "zprof header"
assert_contains "compinit" "$OUT" "zprof table is shown"

# ── --compare ───────────────────────────────────────────────────────
test_start "benchmark_compare_empty_history"
rm -rf "$BENCH_DIR"
run_bench "$PATH_NO_HF" -c
assert_equals 0 "$RC" "--compare exits 0 without history"
assert_contains "No benchmark history found." "$OUT" "empty history message"

test_start "benchmark_compare_with_history"
mkdir -p "$BENCH_DIR"
printf '{"results":[{"mean":0.123,"min":0.1,"max":0.2}]}\n' >"$BENCH_DIR/20260101_120000.json"
printf '{"results":[{"mean":0.123,"min":0.1,"max":0.2}]}\n' >"$BENCH_DIR/latest.json"
run_bench "$PATH_NO_HF" --compare
assert_equals 0 "$RC" "--compare exits 0 with history"
assert_contains "20260101_120000" "$OUT" "history row printed"
assert_contains "123ms" "$OUT" "mean converted to ms"
if [[ "$OUT" == *"latest "*"ms"* ]]; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: latest.json must be skipped in history"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: latest.json skipped in history"
fi

# ── TTY / gum branches (UI_ENABLED=1, UI_COLOR=1) ────────────────────
if "$REAL_PY" -c 'import pty, os; os.waitstatus_to_exitcode' 2>/dev/null; then
  test_start "benchmark_tty_basic_timing"
  run_bench_pty "$PATH_NO_HF"
  assert_equals 0 "$RC" "tty basic timing exits 0"
  assert_contains "Average startup time" "$OUT" "ui_ok average line"
  assert_contains "dot benchmark --waterfall" "$OUT" "ui_info tips"

  test_start "benchmark_tty_hyperfine_ratings"
  run_bench_pty "$PATH_HF"
  assert_contains "Excellent (<100ms)" "$OUT" "tty rating excellent"
  assert_contains "Mean:" "$OUT" "ui_kv mean"
  BENCH_MEAN_S=0.15 run_bench_pty "$PATH_HF"
  assert_contains "Good (<200ms)" "$OUT" "tty rating good"
  BENCH_MEAN_S=0.3 run_bench_pty "$PATH_HF"
  assert_contains "Acceptable (<500ms)" "$OUT" "tty rating acceptable"
  BENCH_MEAN_S=0.7 run_bench_pty "$PATH_HF"
  assert_contains "Slow (>500ms)" "$OUT" "tty rating slow"

  test_start "benchmark_tty_waterfall_colour"
  run_bench_pty "$PATH_NO_HF" --waterfall
  assert_equals 0 "$RC" "tty waterfall exits 0"
  assert_contains "Startup Waterfall" "$OUT" "waterfall header on tty"
  assert_contains "Total" "$OUT" "total row on tty"
else
  test_start "benchmark_tty_branches_skipped"
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${YELLOW}⚠${NC} $CURRENT_TEST: python pty unavailable, skipped"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
