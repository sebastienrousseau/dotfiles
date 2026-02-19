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

ui_init

print_header() {
  echo ""
  ui_header "Shell Performance Benchmark"
  echo ""
}

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
  ui_header "Zsh profiler (zprof)"
  echo ""

  zsh -c '
    zmodload zsh/zprof
    source ~/.zshenv 2>/dev/null
    source ~/.config/zsh/.zshrc 2>/dev/null
    zprof
  ' 2>/dev/null | head -30
}

# Benchmark individual components
benchmark_components() {
  ui_header "Per-Component Timing"
  echo ""
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
    if [[ "$UI_ENABLED" = "1" ]]; then
      ui_warn "hyperfine" "not installed, using basic timing"
    else
      echo -e "${YELLOW}hyperfine not installed. Using basic timing.${NC}"
    fi
    local times=()
    for _ in {1..5}; do
      times+=("$(time_command "zsh -i -c exit")")
    done
    local sum=0
    for t in "${times[@]}"; do sum=$((sum + t)); done
    if [[ "$UI_ENABLED" = "1" ]]; then
      ui_ok "Average startup time" "$((sum / 5))ms"
    else
      echo -e "\n${GREEN}Average startup time: $((sum / 5))ms${NC}"
    fi
    return
  fi

  echo ""
  ui_header "Running hyperfine benchmark"
  echo ""
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

    echo ""
    ui_header "Results"
    if [[ "$UI_ENABLED" = "1" ]]; then
      ui_kv "Mean:" "${mean_ms}ms"
      ui_kv "Min:" "${min_ms}ms"
      ui_kv "Max:" "${max_ms}ms"
    else
      echo "  Mean: ${mean_ms}ms"
      echo "  Min:  ${min_ms}ms"
      echo "  Max:  ${max_ms}ms"
    fi

    # Performance rating
    if [[ $mean_ms -lt 100 ]]; then
      if [[ "$UI_ENABLED" = "1" ]]; then
        ui_ok "Performance" "Excellent (<100ms)"
      else
        echo -e "\n${GREEN}⚡ Excellent (<100ms)${NC}"
      fi
    elif [[ $mean_ms -lt 200 ]]; then
      if [[ "$UI_ENABLED" = "1" ]]; then
        ui_ok "Performance" "Good (<200ms)"
      else
        echo -e "\n${GREEN}✓ Good (<200ms)${NC}"
      fi
    elif [[ $mean_ms -lt 500 ]]; then
      if [[ "$UI_ENABLED" = "1" ]]; then
        ui_warn "Performance" "Acceptable (<500ms)"
      else
        echo -e "\n${YELLOW}⚠ Acceptable (<500ms)${NC}"
      fi
    else
      if [[ "$UI_ENABLED" = "1" ]]; then
        ui_err "Performance" "Slow (>500ms)"
      else
        echo -e "\n${RED}✗ Slow (>500ms) - optimization needed${NC}"
      fi
    fi

    # Save with timestamp for history
    cp "$BENCHMARK_DIR/latest.json" "$BENCHMARK_DIR/$(date +%Y%m%d_%H%M%S).json"
  fi
}

# Compare with previous benchmarks
compare_benchmarks() {
  ui_header "Benchmark History"
  echo ""

  local files
  files=$(find "$BENCHMARK_DIR" -name "*.json" -type f | sort -r | head -10)

  if [[ -z "$files" ]]; then
    echo "No benchmark history found."
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
print_header

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

if [[ "$UI_ENABLED" = "1" ]]; then
  echo ""
  ui_info "Tip" "dot benchmark --detailed"
  ui_info "Tip" "dot benchmark --profile"
else
  echo -e "\n${CYAN}Tip: Run 'dot benchmark --detailed' for per-component timing${NC}"
  echo -e "${CYAN}     Run 'dot benchmark --profile' for zprof analysis${NC}"
fi
echo -e "${CYAN}     Run 'dot benchmark --compare' for history${NC}\n"
