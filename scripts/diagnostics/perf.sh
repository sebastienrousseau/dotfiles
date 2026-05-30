#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Shell Performance Profiling
# Usage: dot perf [--json|-j] [--profile|-p] [--runs|-r N] [--target|-t MS]

set -euo pipefail

_cleanup_files=()
trap 'rm -f "${_cleanup_files[@]}"' EXIT

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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json | -j)
      JSON_OUTPUT=true
      shift
      ;;
    --profile | -p)
      PROFILE=true
      shift
      ;;
    --runs | -r)
      RUNS="${2:-3}"
      shift 2
      ;;
    --target | -t)
      TARGET_MS="${2:-$TARGET_MS}"
      shift 2
      ;;
    --shell | -s)
      SHELL_FILTER="${2:-}"
      shift 2
      ;;
    --by-tool)
      BY_TOOL=true
      shift
      ;;
    --reset)
      RESET_TIMINGS=true
      shift
      ;;
    --baseline)
      # Write the current per-shell means to the baseline file so
      # subsequent runs can warn on regression. Closes part of #863.
      WRITE_BASELINE=true
      shift
      ;;
    --no-baseline-check)
      # Skip the baseline-vs-current comparison entirely. Useful for
      # the very first run on a machine, or for short-lived CI.
      NO_BASELINE_CHECK=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

WRITE_BASELINE="${WRITE_BASELINE:-false}"
NO_BASELINE_CHECK="${NO_BASELINE_CHECK:-false}"
BASELINE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/perf-baseline.json"
BASELINE_REGRESSION_PCT="${DOTFILES_PERF_REGRESSION_PCT:-10}"

# --by-tool reader: aggregate $XDG_STATE_HOME/dotfiles/eval-timings.jsonl
# (populated by _cached_eval when EVALCACHE_TIMING=1) and report which
# tools dominate startup time. Independent of the runtime measurement
# loop above, so it returns immediately.
if $BY_TOOL || $RESET_TIMINGS; then
  log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
  log_file="$log_dir/eval-timings.jsonl"
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
  python3 - "$log_file" <<'PY'
import json, sys
from collections import defaultdict

def percentile(sorted_vals, p):
    """Linear-interpolation percentile, matching numpy.percentile defaults."""
    if not sorted_vals:
        return 0
    if len(sorted_vals) == 1:
        return sorted_vals[0]
    k = (len(sorted_vals) - 1) * (p / 100.0)
    f = int(k)
    c = min(f + 1, len(sorted_vals) - 1)
    if f == c:
        return sorted_vals[f]
    return sorted_vals[f] + (sorted_vals[c] - sorted_vals[f]) * (k - f)

samples = defaultdict(list)        # label -> [ms, ms, ...]
shells_by_label = defaultdict(set) # label -> {shell, ...}

with open(sys.argv[1]) as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            ev = json.loads(line)
        except Exception:
            continue
        label = ev.get("label", "?")
        try:
            ms = int(ev.get("ms", 0) or 0)
        except (TypeError, ValueError):
            continue
        samples[label].append(ms)
        shells_by_label[label].add(ev.get("shell", "?"))

rows = []
for label, vals in samples.items():
    vals_sorted = sorted(vals)
    rows.append({
        "label":  label,
        "count":  len(vals_sorted),
        "total":  sum(vals_sorted),
        "mean":   sum(vals_sorted) // max(len(vals_sorted), 1),
        "min":    vals_sorted[0],
        "max":    vals_sorted[-1],
        "p50":    int(percentile(vals_sorted, 50)),
        "p95":    int(percentile(vals_sorted, 95)),
        "p99":    int(percentile(vals_sorted, 99)),
        "shells": ",".join(sorted(shells_by_label[label])),
    })

rows.sort(key=lambda r: r["total"], reverse=True)
header = (f"  {'label':<20} {'calls':>5} {'total':>8} "
          f"{'mean':>7} {'p50':>5} {'p95':>5} {'p99':>5}  shells")
print(header)
print("  " + "-" * (len(header) - 2))
for r in rows:
    print(f"  {r['label']:<20} {r['count']:>5} {r['total']:>6}ms "
          f"{r['mean']:>5}ms {r['p50']:>3}ms {r['p95']:>3}ms {r['p99']:>3}ms  {r['shells']}")
PY
  exit 0
fi

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

time_one_run() {
  local shell_name="$1" start end
  start=$(python3 -c 'import time; print(int(time.time() * 1000))')
  invoke_shell "$shell_name" >/dev/null 2>&1 || true
  end=$(python3 -c 'import time; print(int(time.time() * 1000))')
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
all_shells=(zsh bash fish nu pwsh)
shells_to_measure=()
for s in "${all_shells[@]}"; do
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

# Measure each shell once into parallel arrays.
declare -a shell_names shell_means shell_mins shell_maxs shell_targets shell_passes
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

# Primary "score" continues to use the zsh measurement (when available)
# so existing dashboards / JSON consumers keep their reference number.
mean=0
for i in "${!shell_names[@]}"; do
  if [[ "${shell_names[$i]}" == "zsh" ]]; then
    mean="${shell_means[$i]}"
    break
  fi
done
[[ "$mean" -eq 0 && "${#shell_means[@]}" -gt 0 ]] && mean="${shell_means[0]}"
score=$(calc_score "$mean")

# -----------------------------------------------------------------------------
# Baseline persistence + regression detection (closes part of #863).
# Stored at $XDG_CACHE_HOME/dotfiles/perf-baseline.json. The file is a
# JSON object mapping shell name → recorded mean (ms). `--baseline`
# overwrites it with the current measurement; default behavior reads
# it (if present) and warns when any shell regresses by more than
# DOTFILES_PERF_REGRESSION_PCT (default 10%).
# -----------------------------------------------------------------------------

declare -a baseline_warnings=()
if $WRITE_BASELINE; then
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
fi

if ! $NO_BASELINE_CHECK && [[ -s "$BASELINE_FILE" ]]; then
  # Read the baseline and compare each measured shell.
  for i in "${!shell_names[@]}"; do
    name="${shell_names[$i]}"
    m="${shell_means[$i]}"
    baseline_ms=$(python3 -c '
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    print(d.get("shells", {}).get(sys.argv[2], 0))
except Exception:
    print(0)
' "$BASELINE_FILE" "$name" 2>/dev/null)
    [[ -z "$baseline_ms" || "$baseline_ms" -eq 0 ]] && continue
    # Threshold: current > baseline * (1 + pct/100)
    threshold=$((baseline_ms * (100 + BASELINE_REGRESSION_PCT) / 100))
    if ((m > threshold)); then
      delta_pct=$((((m - baseline_ms) * 100) / baseline_ms))
      baseline_warnings+=("$name: $m ms vs baseline $baseline_ms ms (+${delta_pct}%, threshold +${BASELINE_REGRESSION_PCT}%)")
    fi
  done
fi

if $JSON_OUTPUT; then
  printf '{\n  "runs": %d,\n  "target_ms": %d,\n  "max_ms_target": %d,\n  "score": %d,\n  "mean_ms": %d,\n  "regression_count": %d,\n  "shells": {' \
    "$RUNS" "$TARGET_MS" "$MAX_MS" "$score" "$mean" "${#baseline_warnings[@]}"
  for i in "${!shell_names[@]}"; do
    [[ "$i" -gt 0 ]] && printf ','
    printf '\n    "%s": {"mean_ms": %d, "min_ms": %d, "max_ms": %d, "target_ms": %d, "pass": %s}' \
      "${shell_names[$i]}" "${shell_means[$i]}" "${shell_mins[$i]}" "${shell_maxs[$i]}" \
      "${shell_targets[$i]}" "$([[ ${shell_passes[$i]} == 1 ]] && echo true || echo false)"
  done
  printf '\n  }'
  if [[ "${#baseline_warnings[@]}" -gt 0 ]]; then
    printf ',\n  "regressions": ['
    for i in "${!baseline_warnings[@]}"; do
      [[ "$i" -gt 0 ]] && printf ','
      # JSON-escape the warning text minimally (no embedded quotes expected).
      printf '\n    "%s"' "${baseline_warnings[$i]}"
    done
    printf '\n  ]'
  fi
  printf '\n}\n'
  exit 0
fi

ui_dot_banner "Diagnostics"
ui_header "Shell Performance"

ui_section "Per-shell startup ($RUNS runs each, after one warm-up)"

# Aligned table: name (6) | mean (8) | min/max (16) | target (12) | status
for i in "${!shell_names[@]}"; do
  name="${shell_names[$i]}"
  m="${shell_means[$i]}"
  mn="${shell_mins[$i]}"
  mx="${shell_maxs[$i]}"
  t="${shell_targets[$i]}"
  if [[ "${shell_passes[$i]}" == "1" ]]; then
    status_marker="✓"
    detail=""
  else
    status_marker="✗"
    detail=" — over by $((m - t))ms"
  fi
  printf '  %s %-6s mean %4dms  (min %3dms, max %3dms)  target %4dms%s\n' \
    "$status_marker" "$name" "$m" "$mn" "$mx" "$t" "$detail"
done

# Baseline comparison summary
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

# Per-component breakdown (Zsh only, uses DOTFILES_DEBUG timing)
ui_section "Component breakdown (estimated)"
for component in "bare zsh" "paths+env" "aliases" "functions" "tools"; do
  case "$component" in
    "bare zsh")
      c_start=$(python3 -c 'import time; print(int(time.time() * 1000))')
      zsh --no-rcs -c exit >/dev/null 2>&1 || true
      c_end=$(python3 -c 'import time; print(int(time.time() * 1000))')
      ;;
    "paths+env")
      c_start=$(python3 -c 'import time; print(int(time.time() * 1000))')
      DOTFILES_ULTRA_FAST=1 zsh -i -c exit >/dev/null 2>&1 || true
      c_end=$(python3 -c 'import time; print(int(time.time() * 1000))')
      ;;
    *)
      # Approximate — full minus ultra gives the delta
      c_start=0
      c_end=0
      ;;
  esac
  c_time=$((c_end - c_start))
  if [[ "$c_time" -gt 0 ]]; then
    if [[ "$UI_ENABLED" = "1" ]]; then
      ui_kv "$component" "${c_time}ms"
    else
      echo "  $component: ${c_time}ms"
    fi
  fi
done

if $PROFILE; then
  echo ""
  ui_section "Top contributors (zprof)"
  run_profile
  echo ""
fi

dot_log info "perf_complete" "mean_ms=$mean" "score=$score"
dot_metric "shell_startup_mean" "$mean" "ms"
dot_metric "perf_score" "$score" "percent"

if [[ "$score" -eq 100 ]]; then
  ui_ok "Performance" "Excellent"
elif [[ "$score" -ge 80 ]]; then
  ui_warn "Performance" "Good (tune to reach 100)"
else
  ui_err "Performance" "Needs attention"
fi
