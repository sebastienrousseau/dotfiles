#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Shell Performance Profiling
# Usage: dot perf [--json|-j] [--profile|-p] [--runs|-r N] [--target|-t MS]

set -euo pipefail

_cleanup_files=()
trap 'rm -f "${_cleanup_files[@]}"' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../dot/lib/ui.sh"
# shellcheck source=../dot/lib/log.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../dot/lib/log.sh"
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
    *)
      shift
      ;;
  esac
done

# Per-shell defaults. nu and pwsh are genuinely slower than POSIX shells;
# bash should be quickest. Override via DOTFILES_PERF_TARGET_<SHELL>_MS.
shell_target_for() {
  case "$1" in
    zsh)  echo "${DOTFILES_PERF_TARGET_ZSH_MS:-$TARGET_MS}" ;;
    bash) echo "${DOTFILES_PERF_TARGET_BASH_MS:-60}" ;;
    fish) echo "${DOTFILES_PERF_TARGET_FISH_MS:-200}" ;;
    nu)   echo "${DOTFILES_PERF_TARGET_NU_MS:-500}" ;;
    pwsh) echo "${DOTFILES_PERF_TARGET_PWSH_MS:-600}" ;;
    *)    echo "$TARGET_MS" ;;
  esac
}

# Invoke a near-empty session for the named shell, picking flags that
# load the user's interactive profile (matches what a fresh terminal does).
invoke_shell() {
  case "$1" in
    zsh)  zsh -i -c exit </dev/null ;;
    bash) bash -i -c exit </dev/null ;;
    fish) fish -i -c exit </dev/null ;;
    nu)   nu -c exit </dev/null ;;
    pwsh) pwsh -Command exit </dev/null ;;
    *)    return 1 ;;
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
if (( ${#shells_to_measure[@]} == 0 )); then
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

if $JSON_OUTPUT; then
  printf '{\n  "runs": %d,\n  "target_ms": %d,\n  "max_ms_target": %d,\n  "score": %d,\n  "mean_ms": %d,\n  "shells": {' \
    "$RUNS" "$TARGET_MS" "$MAX_MS" "$score" "$mean"
  for i in "${!shell_names[@]}"; do
    [[ "$i" -gt 0 ]] && printf ','
    printf '\n    "%s": {"mean_ms": %d, "min_ms": %d, "max_ms": %d, "target_ms": %d, "pass": %s}' \
      "${shell_names[$i]}" "${shell_means[$i]}" "${shell_mins[$i]}" "${shell_maxs[$i]}" \
      "${shell_targets[$i]}" "$([[ ${shell_passes[$i]} == 1 ]] && echo true || echo false)"
  done
  printf '\n  }\n}\n'
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
