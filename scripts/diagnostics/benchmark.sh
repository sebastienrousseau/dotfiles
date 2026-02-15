#!/usr/bin/env bash
# Enhanced Shell Benchmark with Per-Component Profiling
# Usage: dot benchmark [--detailed|--profile|--compare]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"

BENCHMARK_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/benchmarks"
mkdir -p "$BENCHMARK_DIR"

# Parse arguments
DETAILED=false
PROFILE=false
COMPARE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --detailed | -d)
      DETAILED=true
      shift
      ;;
    --profile | -p)
      PROFILE=true
      shift
      ;;
    --compare | -c)
      COMPARE=true
      shift
      ;;
    *) shift ;;
  esac
done

# Basic timing function
time_command() {
  local start end
  start=$(python3 -c 'import time; print(int(time.time() * 1000))')
  eval "$1" >/dev/null 2>&1
  end=$(python3 -c 'import time; print(int(time.time() * 1000))')
  echo $((end - start))
}

# Per-component profiling using zprof
run_zsh_profile() {
  ui_section "Zsh Profiler (zprof)"

  zsh -c '
    zmodload zsh/zprof
    source ~/.zshenv 2>/dev/null
    source ~/.config/zsh/.zshrc 2>/dev/null
    zprof
  ' 2>/dev/null | head -30
}

# Benchmark individual components
benchmark_components() {
  ui_section "Per-Component Timing"
  printf "%-35s %8s\n" "Component" "Time (ms)"
  echo "───────────────────────────────────────────────"

  # zshenv (bootloader)
  local zshenv_time
  zshenv_time=$(time_command "zsh -c 'source ~/.zshenv 2>/dev/null; exit'")
  printf "%-35s %8s\n" "zshenv (bootloader)" "${zshenv_time}ms"

  # Core shell options
  local options_time
  options_time=$(time_command "zsh -c 'source ~/.config/zsh/rc.d/30-options.zsh 2>/dev/null; exit'" 2>/dev/null || echo "N/A")
  printf "%-35s %8s\n" "rc.d/30-options.zsh" "${options_time}ms"

  # Zinit plugins
  local zinit_time
  zinit_time=$(time_command "zsh -c 'source ~/.config/zsh/rc.d/20-zinit.zsh 2>/dev/null; exit'" 2>/dev/null || echo "N/A")
  printf "%-35s %8s\n" "rc.d/20-zinit.zsh (plugins)" "${zinit_time}ms"

  # Tool initializations
  for tool in starship atuin zoxide fzf direnv; do
    if command -v "$tool" >/dev/null 2>&1; then
      local tool_time
      case "$tool" in
        starship) tool_time=$(time_command "starship init zsh >/dev/null") ;;
        atuin) tool_time=$(time_command "atuin init zsh >/dev/null") ;;
        zoxide) tool_time=$(time_command "zoxide init zsh >/dev/null") ;;
        fzf) tool_time=$(time_command "true") ;; # FZF sourced from file
        direnv) tool_time=$(time_command "direnv hook zsh >/dev/null") ;;
      esac
      printf "%-35s %8s\n" "$tool init" "${tool_time}ms"
    fi
  done

  echo "───────────────────────────────────────────────"
}

# Run hyperfine benchmark
run_hyperfine() {
  if ! command -v hyperfine >/dev/null 2>&1; then
    ui_warn "hyperfine not installed. Using basic timing."
    local times=()
    for _ in {1..5}; do
      times+=("$(time_command "zsh -i -c exit")")
    done
    local sum=0
    for t in "${times[@]}"; do sum=$((sum + t)); done
    printf "\n"
    ui_success "Average startup time" "$((sum / 5))ms"
    return
  fi

  ui_section "Hyperfine Benchmark"
  ui_info "10 runs with 3 warmups"
  hyperfine --warmup 3 --runs 10 --shell=none \
    --export-json "$BENCHMARK_DIR/latest.json" \
    'zsh -i -c exit'

  # Extract and display results
  if [[ -f "$BENCHMARK_DIR/latest.json" ]]; then
    local mean_ms
    mean_ms=$(jq '.results[0].mean * 1000 | floor' "$BENCHMARK_DIR/latest.json")
    local min_ms
    min_ms=$(jq '.results[0].min * 1000 | floor' "$BENCHMARK_DIR/latest.json")
    local max_ms
    max_ms=$(jq '.results[0].max * 1000 | floor' "$BENCHMARK_DIR/latest.json")

    printf "\n"
    ui_section "Results"
    ui_key_value "Mean" "${mean_ms}ms"
    ui_key_value "Min" "${min_ms}ms"
    ui_key_value "Max" "${max_ms}ms"

    # Performance rating
    if [[ $mean_ms -lt 100 ]]; then
      printf "\n"
      ui_success "Excellent (<100ms)"
    elif [[ $mean_ms -lt 200 ]]; then
      printf "\n"
      ui_success "Good (<200ms)"
    elif [[ $mean_ms -lt 500 ]]; then
      printf "\n"
      ui_warn "Acceptable (<500ms)"
    else
      printf "\n"
      ui_error "Slow (>500ms) - optimization needed"
    fi

    # Save with timestamp for history
    cp "$BENCHMARK_DIR/latest.json" "$BENCHMARK_DIR/$(date +%Y%m%d_%H%M%S).json"
  fi
}

# Compare with previous benchmarks
compare_benchmarks() {
  ui_section "Benchmark History"

  local files
  files=$(find "$BENCHMARK_DIR" -name "*.json" -type f | sort -r | head -10)

  if [[ -z "$files" ]]; then
    ui_info "No benchmark history found."
    return
  fi

  printf "%-20s %10s %10s %10s\n" "Date" "Mean" "Min" "Max"
  echo "────────────────────────────────────────────────"

  for f in $files; do
    local basename
    basename=$(basename "$f" .json)
    if [[ "$basename" == "latest" ]]; then continue; fi

    local mean min max
    mean=$(jq '.results[0].mean * 1000 | floor' "$f" 2>/dev/null || echo "N/A")
    min=$(jq '.results[0].min * 1000 | floor' "$f" 2>/dev/null || echo "N/A")
    max=$(jq '.results[0].max * 1000 | floor' "$f" 2>/dev/null || echo "N/A")

    printf "%-20s %10sms %10sms %10sms\n" "$basename" "$mean" "$min" "$max"
  done
}

# Main execution
ui_logo_dot "Dot Benchmark • Performance"

if $PROFILE; then
  run_zsh_profile
elif $COMPARE; then
  compare_benchmarks
elif $DETAILED; then
  benchmark_components
  echo ""
  run_hyperfine
else
  run_hyperfine
fi

ui_section "Tips"
ui_bullet "dot benchmark --detailed  (per-component timing)"
ui_bullet "dot benchmark --profile   (zprof analysis)"
ui_bullet "dot benchmark --compare   (history)"
