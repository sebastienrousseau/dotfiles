#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Shell Performance Profiling
# Usage: dot perf [--json|-j] [--profile|-p] [--runs|-r N] [--target|-t MS]

set -euo pipefail

_cleanup_files=()
trap 'set +u; rm -f "${_cleanup_files[@]}" 2>/dev/null; set -u' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/dot/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../lib/dot/ui.sh"
# shellcheck source=../../lib/dot/log.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../lib/dot/log.sh"
export DOT_COMMAND="perf"

ui_init

if ! command -v python3 >/dev/null 2>&1; then
  ui_err "python3" "required for perf timing"
  exit 1
fi

JSON_OUTPUT=false
PROFILE=false
RUNS=3
TARGET_MS="${DOTFILES_PERF_TARGET_MS:-250}"
MAX_MS="${DOTFILES_PERF_MAX_MS:-1000}"
SHELL_FILTER=""
BY_TOOL=false
RESET_TIMINGS=false

# A flag that takes a value: --runs/-r, --target/-t, --shell/-s.
_perf_set_option() {
  case "$1" in
    --runs | -r) RUNS="${2:-3}" ;;
    --target | -t) TARGET_MS="${2:-$TARGET_MS}" ;;
    *) SHELL_FILTER="${2:-}" ;;
  esac
}

_perf_parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json | -j) JSON_OUTPUT=true ;;
      --profile | -p) PROFILE=true ;;
      --by-tool) BY_TOOL=true ;;
      --reset) RESET_TIMINGS=true ;;
      # Write the current per-shell means to the baseline file so
      # subsequent runs can warn on regression. Closes part of #863.
      --baseline) WRITE_BASELINE=true ;;
      # Skip the baseline-vs-current comparison entirely. Useful for
      # the very first run on a machine, or for short-lived CI.
      --no-baseline-check) NO_BASELINE_CHECK=true ;;
      --runs | -r | --target | -t | --shell | -s)
        _perf_set_option "$1" "${2:-}"
        shift
        ;;
    esac
    shift
  done
}

# --by-tool reader: aggregate $XDG_STATE_HOME/dotfiles/eval-timings.jsonl
# (populated by _cached_eval when EVALCACHE_TIMING=1) and report which
# tools dominate startup time. Independent of the runtime measurement
# loop, so it exits immediately.
_perf_by_tool() {
  local log_file="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/eval-timings.jsonl"
  if $RESET_TIMINGS; then
    : >"$log_file" 2>/dev/null || rm -f "$log_file" 2>/dev/null || true
    ui_ok "eval timings" "cleared $log_file"
    $BY_TOOL || exit 0
  fi
  if [[ ! -s "$log_file" ]]; then
    ui_warn "eval timings" "no data at $log_file"
    echo "  Hint: open a new shell with EVALCACHE_TIMING=1 to start collecting." >&2
    exit 0
  fi
  ui_dot_banner "Diagnostics"
  ui_header "Per-tool timing breakdown"
  ui_section "$log_file"
  python3 "$SCRIPT_DIR/perf/by_tool.py" "$log_file"
  exit 0
}

# Per-shell defaults. nu and pwsh are genuinely slower than POSIX shells;
# bash should be quickest. Override via DOTFILES_PERF_TARGET_<SHELL>_MS.
shell_target_for() {
  case "$1" in
    zsh) echo "${DOTFILES_PERF_TARGET_ZSH_MS:-$TARGET_MS}" ;;
    bash) echo "${DOTFILES_PERF_TARGET_BASH_MS:-60}" ;;
    fish) echo "${DOTFILES_PERF_TARGET_FISH_MS:-200}" ;;
    nu) echo "${DOTFILES_PERF_TARGET_NU_MS:-500}" ;;
    pwsh) echo "${DOTFILES_PERF_TARGET_PWSH_MS:-600}" ;;
    *) echo "$TARGET_MS" ;;
  esac
}

# Invoke a near-empty session for the named shell, picking flags that
# load the user's interactive profile (matches what a fresh terminal does).
invoke_shell() {
  case "$1" in
    zsh) zsh -i -c exit </dev/null ;;
    bash) bash -i -c exit </dev/null ;;
    fish) fish -i -c exit </dev/null ;;
    nu) nu -c exit </dev/null ;;
    pwsh) pwsh -Command exit </dev/null ;;
    *) return 1 ;;
  esac
}

_perf_now_ms() { python3 -c 'import time; print(int(time.time() * 1000))'; }

time_one_run() {
  local shell_name="$1" start end
  start=$(_perf_now_ms)
  invoke_shell "$shell_name" >/dev/null 2>&1 || true
  end=$(_perf_now_ms)
  echo $((end - start))
}

# Existing single-shell helper retained for backward compatibility with
# callers/tests that reference time_shell_startup; routes to time_one_run.
time_shell_startup() { time_one_run zsh; }

# Measure a shell across $RUNS iterations, return "mean min max".
measure_shell() {
  local shell_name="$1" sum=0 min=999999 max=0 t
  local times=()
  # One warm-up run discarded — caches a $_SHELL_CACHE on first invocation.
  invoke_shell "$shell_name" >/dev/null 2>&1 || true
  for _ in $(seq 1 "$RUNS"); do
    t=$(time_one_run "$shell_name")
    times+=("$t")
    sum=$((sum + t))
    [[ "$t" -lt "$min" ]] && min="$t"
    [[ "$t" -gt "$max" ]] && max="$t"
  done
  echo "$((sum / RUNS)) $min $max"
}

calc_score() {
  local mean_ms="$1"
  if [[ "$mean_ms" -le "$TARGET_MS" ]]; then
    echo 100
    return
  fi
  if [[ "$mean_ms" -ge "$MAX_MS" ]]; then
    echo 0
    return
  fi
  echo $((100 - (mean_ms - TARGET_MS) * 100 / (MAX_MS - TARGET_MS)))
}

run_profile() {
  zsh -c '
    zmodload zsh/zprof
# shellcheck disable=SC1091
    source ~/.zshenv 2>/dev/null
# shellcheck disable=SC1091
    source ~/.config/zsh/.zshrc 2>/dev/null
    zprof
  ' 2>/dev/null | head -20
}

# Discover installed shells. SHELL_FILTER (--shell <name>) restricts to one.
shells_to_measure=()
_perf_discover() {
  local s
  for s in zsh bash fish nu pwsh; do
    command -v "$s" >/dev/null 2>&1 || continue
    if [[ -n "$SHELL_FILTER" && "$s" != "$SHELL_FILTER" ]]; then
      continue
    fi
    shells_to_measure+=("$s")
  done
  if ((${#shells_to_measure[@]} == 0)); then
    ui_err "perf" "no measurable shells found${SHELL_FILTER:+ (filter: $SHELL_FILTER)}"
    exit 1
  fi
}

# Measure each shell once into parallel arrays.
declare -a shell_names shell_means shell_mins shell_maxs shell_targets shell_passes
_perf_measure() {
  local s m mn mx t
  for s in "${shells_to_measure[@]}"; do
    read -r m mn mx <<<"$(measure_shell "$s")"
    t=$(shell_target_for "$s")
    shell_names+=("$s")
    shell_means+=("$m")
    shell_mins+=("$mn")
    shell_maxs+=("$mx")
    shell_targets+=("$t")
    if [[ "$m" -le "$t" ]]; then
      shell_passes+=("1")
    else
      shell_passes+=("0")
    fi
  done
}

# Primary "score" continues to use the zsh measurement (when available)
# so existing dashboards / JSON consumers keep their reference number.
_perf_primary_mean() {
  local i
  mean=0
  for i in "${!shell_names[@]}"; do
    if [[ "${shell_names[$i]}" == "zsh" ]]; then
      mean="${shell_means[$i]}"
      break
    fi
  done
  if [[ "$mean" -eq 0 && "${#shell_means[@]}" -gt 0 ]]; then
    mean="${shell_means[0]}"
  fi
}

# -----------------------------------------------------------------------------
# Baseline persistence + regression detection (closes part of #863).
# Stored at $XDG_CACHE_HOME/dotfiles/perf-baseline.json. The file is a
# JSON object mapping shell name → recorded mean (ms). `--baseline`
# overwrites it with the current measurement; default behavior reads
# it (if present) and warns when any shell regresses by more than
# DOTFILES_PERF_REGRESSION_PCT (default 10%).
# -----------------------------------------------------------------------------

declare -a baseline_warnings=()
_perf_write_baseline() {
  local i
  mkdir -p "$(dirname "$BASELINE_FILE")"
  {
    printf '{\n  "recorded_at": "%s",\n  "regression_pct": %d,\n  "shells": {' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$BASELINE_REGRESSION_PCT"
    for i in "${!shell_names[@]}"; do
      [[ "$i" -gt 0 ]] && printf ','
      printf '\n    "%s": %d' "${shell_names[$i]}" "${shell_means[$i]}"
    done
    printf '\n  }\n}\n'
  } >"$BASELINE_FILE"
}

# _perf_compare_one <shell> <mean-ms>: record a warning when the mean is
# over the baseline by more than the threshold (current > baseline *
# (1 + pct/100)). A shell missing from the baseline is skipped.
_perf_compare_one() {
  local name="$1" m="$2" baseline_ms threshold delta_pct
  baseline_ms=$(python3 -c '
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    print(d.get("shells", {}).get(sys.argv[2], 0))
except Exception:
    print(0)
' "$BASELINE_FILE" "$name" 2>/dev/null)
  [[ -z "$baseline_ms" || "$baseline_ms" -eq 0 ]] && return 0
  threshold=$((baseline_ms * (100 + BASELINE_REGRESSION_PCT) / 100))
  if ((m > threshold)); then
    delta_pct=$((((m - baseline_ms) * 100) / baseline_ms))
    baseline_warnings+=("$name: $m ms vs baseline $baseline_ms ms (+${delta_pct}%, threshold +${BASELINE_REGRESSION_PCT}%)")
  fi
}

_perf_check_baseline() {
  local i
  for i in "${!shell_names[@]}"; do
    _perf_compare_one "${shell_names[$i]}" "${shell_means[$i]}"
  done
}

_perf_json_regressions() {
  local i
  [[ "${#baseline_warnings[@]}" -gt 0 ]] || return 0
  printf ',\n  "regressions": ['
  for i in "${!baseline_warnings[@]}"; do
    [[ "$i" -gt 0 ]] && printf ','
    # JSON-escape the warning text minimally (no embedded quotes expected).
    printf '\n    "%s"' "${baseline_warnings[$i]}"
  done
  printf '\n  ]'
}

_perf_json() {
  local i
  printf '{\n  "runs": %d,\n  "target_ms": %d,\n  "max_ms_target": %d,\n  "score": %d,\n  "mean_ms": %d,\n  "regression_count": %d,\n  "shells": {' \
    "$RUNS" "$TARGET_MS" "$MAX_MS" "$score" "$mean" "${#baseline_warnings[@]}"
  for i in "${!shell_names[@]}"; do
    [[ "$i" -gt 0 ]] && printf ','
    printf '\n    "%s": {"mean_ms": %d, "min_ms": %d, "max_ms": %d, "target_ms": %d, "pass": %s}' \
      "${shell_names[$i]}" "${shell_means[$i]}" "${shell_mins[$i]}" "${shell_maxs[$i]}" \
      "${shell_targets[$i]}" "$([[ ${shell_passes[$i]} == 1 ]] && echo true || echo false)"
  done
  printf '\n  }'
  _perf_json_regressions
  printf '\n}\n'
}

# Aligned table: name (6) | mean (8) | min/max (16) | target (12) | status
_perf_table() {
  local i m t status_marker detail
  for i in "${!shell_names[@]}"; do
    m="${shell_means[$i]}"
    t="${shell_targets[$i]}"
    if [[ "${shell_passes[$i]}" == "1" ]]; then
      status_marker="✓"
      detail=""
    else
      status_marker="✗"
      detail=" — over by $((m - t))ms"
    fi
    printf '  %s %-6s mean %4dms  (min %3dms, max %3dms)  target %4dms%s\n' \
      "$status_marker" "${shell_names[$i]}" "$m" "${shell_mins[$i]}" "${shell_maxs[$i]}" "$t" "$detail"
  done
}

# Baseline comparison summary
_perf_baseline_summary() {
  local w
  if [[ "${#baseline_warnings[@]}" -gt 0 ]]; then
    ui_section "Baseline regressions"
    for w in "${baseline_warnings[@]}"; do
      printf '  ✗ %s\n' "$w"
    done
    printf '  (threshold: >%s%% over the recorded baseline at %s)\n' \
      "$BASELINE_REGRESSION_PCT" "$BASELINE_FILE"
  elif [[ -s "$BASELINE_FILE" ]] && ! $NO_BASELINE_CHECK; then
    ui_section "Baseline"
    printf '  ✓ all measured shells within %s%% of baseline (%s)\n' \
      "$BASELINE_REGRESSION_PCT" "$BASELINE_FILE"
  elif $WRITE_BASELINE; then
    ui_section "Baseline"
    printf '  ✓ wrote baseline to %s\n' "$BASELINE_FILE"
  fi
}

# _perf_component <label> <command...>: time one zsh variant and print it
# when it took any time at all.
_perf_component() {
  local label="$1" c_start c_end c_time
  shift
  c_start=$(_perf_now_ms)
  "$@" >/dev/null 2>&1 || true
  c_end=$(_perf_now_ms)
  c_time=$((c_end - c_start))
  if [[ "$c_time" -gt 0 ]]; then
    if [[ "$UI_ENABLED" = "1" ]]; then
      ui_kv "$label" "${c_time}ms"
    else
      echo "  $label: ${c_time}ms"
    fi
  fi
}

_perf_zsh_bare() { zsh --no-rcs -c exit; }
_perf_zsh_ultra() { DOTFILES_ULTRA_FAST=1 zsh -i -c exit; }

# Per-component breakdown (Zsh only). Only bare zsh and paths+env are
# timed; the aliases/functions/tools rows were never measured (0ms, so
# never printed).
_perf_components() {
  ui_section "Component breakdown (estimated)"
  _perf_component "bare zsh" _perf_zsh_bare
  _perf_component "paths+env" _perf_zsh_ultra
}

_perf_verdict() {
  if [[ "$score" -eq 100 ]]; then
    ui_ok "Performance" "Excellent"
  elif [[ "$score" -ge 80 ]]; then
    ui_warn "Performance" "Good (tune to reach 100)"
  else
    ui_err "Performance" "Needs attention"
  fi
}

_perf_report() {
  ui_dot_banner "Diagnostics"
  ui_header "Shell Performance"
  ui_section "Per-shell startup ($RUNS runs each, after one warm-up)"
  _perf_table
  _perf_baseline_summary
  _perf_components
  if $PROFILE; then
    echo ""
    ui_section "Top contributors (zprof)"
    run_profile
    echo ""
  fi
  dot_log info "perf_complete" "mean_ms=$mean" "score=$score"
  dot_metric "shell_startup_mean" "$mean" "ms"
  dot_metric "perf_score" "$score" "percent"
  _perf_verdict
}

_perf_main() {
  _perf_parse_args "$@"
  WRITE_BASELINE="${WRITE_BASELINE:-false}"
  NO_BASELINE_CHECK="${NO_BASELINE_CHECK:-false}"
  BASELINE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/perf-baseline.json"
  BASELINE_REGRESSION_PCT="${DOTFILES_PERF_REGRESSION_PCT:-10}"
  if $BY_TOOL || $RESET_TIMINGS; then
    _perf_by_tool
  fi
  _perf_discover
  _perf_measure
  _perf_primary_mean
  score=$(calc_score "$mean")
  if $WRITE_BASELINE; then
    _perf_write_baseline
  fi
  if ! $NO_BASELINE_CHECK && [[ -s "$BASELINE_FILE" ]]; then
    _perf_check_baseline
  fi
  if $JSON_OUTPUT; then
    _perf_json
    exit 0
  fi
  _perf_report
}

_perf_main "$@"
