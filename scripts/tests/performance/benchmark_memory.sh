#!/usr/bin/env bash
# shellcheck disable=SC2034
# Memory usage benchmarks for shell environment
# Tracks memory footprint of shell initialization
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Results storage
RESULTS_DIR="${RESULTS_DIR:-$HOME/.local/share/dotfiles/benchmarks}"
mkdir -p "$RESULTS_DIR"
RESULTS_FILE="$RESULTS_DIR/memory_$(date +%Y%m%d_%H%M%S).json"

# Thresholds (KB)
SHELL_RSS_THRESHOLD_KB=50000   # 50MB
SHELL_VSZ_THRESHOLD_KB=200000  # 200MB
MINIMAL_RSS_THRESHOLD_KB=20000 # 20MB baseline

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo "Memory Usage Benchmarks"
echo "======================="
echo ""

store_result() {
  local metric="$1" value="$2" threshold="$3" status="$4"
  printf '{"timestamp":"%s","metric":"%s","value_kb":%d,"threshold_kb":%d,"status":"%s"}\n' \
    "$(date -Iseconds)" "$metric" "$value" "$threshold" "$status" >>"$RESULTS_FILE"
}

measure_memory() {
  local shell="$1"
  local config="$2"
  local name="$3"

  local tmp_rc
  tmp_rc=$(mktemp)
  echo "$config" >"$tmp_rc"

  local mem_info
  mem_info=$(ZDOTDIR="$(dirname "$tmp_rc")" "$shell" -c "
    source '$tmp_rc' 2>/dev/null
    ps -o rss=,vsz= -p \$\$ 2>/dev/null || echo '0 0'
  " 2>/dev/null || echo "0 0")

  rm -f "$tmp_rc"

  local rss vsz
  read -r rss vsz <<<"$mem_info"

  echo "$rss $vsz"
}

benchmark_memory() {
  local name="$1"
  local shell="$2"
  local config="$3"
  local threshold="$4"

  local result
  result=$(measure_memory "$shell" "$config" "$name")

  local rss vsz
  read -r rss vsz <<<"$result"

  local status
  if [[ $rss -gt $threshold ]]; then
    status="FAIL"
    printf "  ${RED}✗ FAIL${NC}: %-25s RSS: %6d KB  VSZ: %6d KB (threshold: %d KB)\n" \
      "$name" "$rss" "$vsz" "$threshold"
  else
    status="PASS"
    printf "  ${GREEN}✓ PASS${NC}: %-25s RSS: %6d KB  VSZ: %6d KB (threshold: %d KB)\n" \
      "$name" "$rss" "$vsz" "$threshold"
  fi

  store_result "${name}_rss" "$rss" "$threshold" "$status"
  store_result "${name}_vsz" "$vsz" "$((threshold * 4))" "$status"
}

# ============================================================================
# Baseline Measurements
# ============================================================================

echo "Baseline Shell Memory"
echo "---------------------"

# Minimal bash
MINIMAL_BASH='
PS1="$ "
'
benchmark_memory "minimal_bash" "bash" "$MINIMAL_BASH" $MINIMAL_RSS_THRESHOLD_KB

# Minimal zsh
if command -v zsh >/dev/null 2>&1; then
  MINIMAL_ZSH='
autoload -Uz compinit && compinit -C
PROMPT="%n@%m %1~ %# "
'
  benchmark_memory "minimal_zsh" "zsh" "$MINIMAL_ZSH" $MINIMAL_RSS_THRESHOLD_KB
fi

echo ""

# ============================================================================
# Full Environment Memory
# ============================================================================

echo "Full Environment Memory"
echo "-----------------------"

# Full dotfiles
if command -v zsh >/dev/null 2>&1 && [[ -f ~/.zshrc ]]; then
  benchmark_memory "full_dotfiles_zsh" "zsh" "source ~/.zshrc" $SHELL_RSS_THRESHOLD_KB
fi

# DOTFILES_FAST mode
if command -v zsh >/dev/null 2>&1 && [[ -f ~/.zshrc ]]; then
  FAST_CONFIG='
export DOTFILES_FAST=1
source ~/.zshrc
'
  benchmark_memory "dotfiles_fast_mode" "zsh" "$FAST_CONFIG" $((SHELL_RSS_THRESHOLD_KB / 2))
fi

echo ""

# ============================================================================
# Per-Plugin Memory Impact
# ============================================================================

echo "Plugin Memory Impact"
echo "--------------------"

# Measure incremental memory for common plugins
if command -v zsh >/dev/null 2>&1; then
  # With zinit
  if [[ -f ~/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    ZINIT_ONLY='
source ~/.local/share/zinit/zinit.git/zinit.zsh
'
    benchmark_memory "zinit_only" "zsh" "$ZINIT_ONLY" 30000
  fi

  # With starship
  if command -v starship >/dev/null 2>&1; then
    STARSHIP_ONLY='
eval "$(starship init zsh)"
'
    benchmark_memory "starship_only" "zsh" "$STARSHIP_ONLY" 25000
  fi
fi

echo ""

# ============================================================================
# Memory Growth Test
# ============================================================================

echo "Memory Stability Test"
echo "---------------------"

if command -v zsh >/dev/null 2>&1 && [[ -f ~/.zshrc ]]; then
  printf "  Running 5 iterations to check for memory leaks...\n"

  prev_rss=0
  growth_detected=false

  for i in {1..5}; do
    result=$(measure_memory "zsh" "source ~/.zshrc" "iteration_$i")
    rss=$(echo "$result" | cut -d' ' -f1)

    if [[ $prev_rss -gt 0 ]]; then
      diff=$((rss - prev_rss))
      if [[ $diff -gt 1000 ]]; then # More than 1MB growth
        growth_detected=true
      fi
    fi
    prev_rss=$rss
  done

  if $growth_detected; then
    printf "  ${YELLOW}⚠ WARN${NC}: Potential memory growth detected between iterations\n"
  else
    printf "  ${GREEN}✓ PASS${NC}: No significant memory growth detected\n"
  fi
fi

echo ""

# ============================================================================
# Summary
# ============================================================================

echo "Results saved to: $RESULTS_FILE"
echo ""

if [[ -f "$RESULTS_FILE" ]]; then
  total=$(wc -l <"$RESULTS_FILE")
  passed=$(grep -c '"status":"PASS"' "$RESULTS_FILE" || echo 0)
  failed=$(grep -c '"status":"FAIL"' "$RESULTS_FILE" || echo 0)

  echo "Summary: $passed/$total passed, $failed failed"
fi
