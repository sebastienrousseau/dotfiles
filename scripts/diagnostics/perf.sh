#!/usr/bin/env bash
# Shell Performance Profiling
# Usage: dot perf [--json] [--profile] [--runs N] [--target MS]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"

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

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)
      JSON_OUTPUT=true
      shift
      ;;
    --profile)
      PROFILE=true
      shift
      ;;
    --runs)
      RUNS="${2:-3}"
      shift 2
      ;;
    --target)
      TARGET_MS="${2:-$TARGET_MS}"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

time_shell_startup() {
  local start end
  start=$(python3 -c 'import time; print(int(time.time() * 1000))')
  zsh -i -c exit >/dev/null 2>&1
  end=$(python3 -c 'import time; print(int(time.time() * 1000))')
  echo $((end - start))
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
    source ~/.zshenv 2>/dev/null
    source ~/.config/zsh/.zshrc 2>/dev/null
    zprof
  ' 2>/dev/null | head -20
}

if $JSON_OUTPUT; then
  times=()
  for _ in $(seq 1 "$RUNS"); do
    times+=("$(time_shell_startup)")
  done
  sum=0
  min=999999
  max=0
  for t in "${times[@]}"; do
    sum=$((sum + t))
    if [[ "$t" -lt "$min" ]]; then min="$t"; fi
    if [[ "$t" -gt "$max" ]]; then max="$t"; fi
  done
  mean=$((sum / RUNS))
  score=$(calc_score "$mean")
  cat <<JSON
{
  "mean_ms": $mean,
  "min_ms": $min,
  "max_ms": $max,
  "runs": $RUNS,
  "target_ms": $TARGET_MS,
  "max_ms_target": $MAX_MS,
  "score": $score
}
JSON
  exit 0
fi

ui_header "Shell Performance"

ui_section "Startup timing"

times=()
for _ in $(seq 1 "$RUNS"); do
  times+=("$(time_shell_startup)")
done
sum=0
min=999999
max=0
for t in "${times[@]}"; do
  sum=$((sum + t))
  if [[ "$t" -lt "$min" ]]; then min="$t"; fi
  if [[ "$t" -gt "$max" ]]; then max="$t"; fi
  if [[ "$UI_ENABLED" = "1" ]]; then
    ui_kv "Run" "${t}ms"
  else
    echo "  Run: ${t}ms"
  fi
done
mean=$((sum / RUNS))
score=$(calc_score "$mean")

if [[ "$UI_ENABLED" = "1" ]]; then
  ui_kv "Average" "${mean}ms"
  ui_kv "Min" "${min}ms"
  ui_kv "Max" "${max}ms"
  ui_kv "Target" "${TARGET_MS}ms"
  ui_kv "Score" "${score}/100"
else
  echo "  Average: ${mean}ms"
  echo "  Min:     ${min}ms"
  echo "  Max:     ${max}ms"
  echo "  Target:  ${TARGET_MS}ms"
  echo "  Score:   ${score}/100"
fi

if $PROFILE; then
  echo ""
  ui_section "Top contributors (zprof)"
  run_profile
  echo ""
fi

if [[ "$score" -eq 100 ]]; then
  ui_ok "Performance" "Excellent"
elif [[ "$score" -ge 80 ]]; then
  ui_warn "Performance" "Good (tune to reach 100)"
else
  ui_err "Performance" "Needs attention"
fi
