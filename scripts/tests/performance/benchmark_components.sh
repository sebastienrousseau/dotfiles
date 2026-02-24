#!/usr/bin/env bash
# shellcheck disable=SC1090,SC2034,SC2155
# Component-level performance benchmarks
# Measures individual shell components for granular optimization
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"

# Results storage
RESULTS_DIR="${RESULTS_DIR:-$HOME/.local/share/dotfiles/benchmarks}"
mkdir -p "$RESULTS_DIR"
RESULTS_FILE="$RESULTS_DIR/components_$(date +%Y%m%d_%H%M%S).json"

# Thresholds (milliseconds)
ZINIT_THRESHOLD_MS=100
COMPINIT_THRESHOLD_MS=150
STARSHIP_THRESHOLD_MS=50
ATUIN_THRESHOLD_MS=30
ZOXIDE_THRESHOLD_MS=20
FZF_THRESHOLD_MS=30
ALIAS_LOAD_THRESHOLD_MS=50

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;34m'
NC='\033[0m'

echo "Component Performance Benchmarks"
echo "================================="
echo ""

# Precision timer using perl
measure_time_ms() {
  local start end
  if command -v perl >/dev/null 2>&1; then
    start=$(perl -MTime::HiRes=time -e 'printf "%.0f\n", time * 1000')
    "$@" >/dev/null 2>&1 || true
    end=$(perl -MTime::HiRes=time -e 'printf "%.0f\n", time * 1000')
    echo $((end - start))
  else
    local start_s end_s
    start_s=$(date +%s)
    "$@" >/dev/null 2>&1 || true
    end_s=$(date +%s)
    echo $(((end_s - start_s) * 1000))
  fi
}

store_result() {
  local component="$1" value="$2" threshold="$3" status="$4"
  printf '{"timestamp":"%s","component":"%s","value_ms":%d,"threshold_ms":%d,"status":"%s"}\n' \
    "$(date -Iseconds)" "$component" "$value" "$threshold" "$status" >>"$RESULTS_FILE"
}

benchmark_component() {
  local name="$1"
  local threshold="$2"
  local cmd="$3"

  local time_ms
  time_ms=$(measure_time_ms bash -c "$cmd")

  local status
  if [[ $time_ms -gt $threshold ]]; then
    status="FAIL"
    printf "  ${RED}✗ FAIL${NC}: %-20s %4dms (threshold: %dms)\n" "$name" "$time_ms" "$threshold"
    store_result "$name" "$time_ms" "$threshold" "$status"
    return 1
  else
    status="PASS"
    printf "  ${GREEN}✓ PASS${NC}: %-20s %4dms (threshold: %dms)\n" "$name" "$time_ms" "$threshold"
    store_result "$name" "$time_ms" "$threshold" "$status"
    return 0
  fi
}

# ============================================================================
# Core Shell Components
# ============================================================================

echo "Core Shell Initialization"
echo "-------------------------"

# Zinit plugin manager (if installed)
if [[ -f ~/.local/share/zinit/zinit.git/zinit.zsh ]]; then
  benchmark_component "zinit" $ZINIT_THRESHOLD_MS \
    "source ~/.local/share/zinit/zinit.git/zinit.zsh" || true
else
  printf "  ${YELLOW}- SKIP${NC}: %-20s (not installed)\n" "zinit"
fi

# Completion initialization
benchmark_component "compinit" $COMPINIT_THRESHOLD_MS \
  "autoload -Uz compinit && compinit -C" || true

echo ""

# ============================================================================
# Tool Initializations
# ============================================================================

echo "Tool Initializations"
echo "-------------------"

# Starship prompt
if command -v starship >/dev/null 2>&1; then
  benchmark_component "starship" $STARSHIP_THRESHOLD_MS \
    "eval \"\$(starship init bash)\"" || true
else
  printf "  ${YELLOW}- SKIP${NC}: %-20s (not installed)\n" "starship"
fi

# Atuin history
if command -v atuin >/dev/null 2>&1; then
  benchmark_component "atuin" $ATUIN_THRESHOLD_MS \
    "eval \"\$(atuin init bash)\"" || true
else
  printf "  ${YELLOW}- SKIP${NC}: %-20s (not installed)\n" "atuin"
fi

# Zoxide directory jumper
if command -v zoxide >/dev/null 2>&1; then
  benchmark_component "zoxide" $ZOXIDE_THRESHOLD_MS \
    "eval \"\$(zoxide init bash)\"" || true
else
  printf "  ${YELLOW}- SKIP${NC}: %-20s (not installed)\n" "zoxide"
fi

# Fzf fuzzy finder
if command -v fzf >/dev/null 2>&1; then
  benchmark_component "fzf" $FZF_THRESHOLD_MS \
    "eval \"\$(fzf --bash)\"" || true
else
  printf "  ${YELLOW}- SKIP${NC}: %-20s (not installed)\n" "fzf"
fi

# Direnv
if command -v direnv >/dev/null 2>&1; then
  benchmark_component "direnv" 30 \
    "eval \"\$(direnv hook bash)\"" || true
else
  printf "  ${YELLOW}- SKIP${NC}: %-20s (not installed)\n" "direnv"
fi

echo ""

# ============================================================================
# Alias Loading
# ============================================================================

echo "Alias Loading"
echo "-------------"

ALIAS_DIR="$REPO_ROOT/.chezmoitemplates/aliases"
if [[ -d "$ALIAS_DIR" ]]; then
  for alias_file in "$ALIAS_DIR"/*.sh; do
    [[ -f "$alias_file" ]] || continue
    name=$(basename "$alias_file" .sh)
    benchmark_component "alias:$name" $ALIAS_LOAD_THRESHOLD_MS \
      "source '$alias_file'" || true
  done
else
  printf "  ${YELLOW}- SKIP${NC}: Alias directory not found\n"
fi

echo ""

# ============================================================================
# Node Version Manager
# ============================================================================

echo "Version Managers"
echo "----------------"

# FNM (Fast Node Manager)
if command -v fnm >/dev/null 2>&1; then
  benchmark_component "fnm" 50 \
    "eval \"\$(fnm env)\"" || true
else
  printf "  ${YELLOW}- SKIP${NC}: %-20s (not installed)\n" "fnm"
fi

# Mise (polyglot version manager)
if command -v mise >/dev/null 2>&1; then
  benchmark_component "mise" 100 \
    "eval \"\$(mise activate bash)\"" || true
else
  printf "  ${YELLOW}- SKIP${NC}: %-20s (not installed)\n" "mise"
fi

echo ""

# ============================================================================
# Summary
# ============================================================================

echo "Results saved to: $RESULTS_FILE"
echo ""

# Count results
if [[ -f "$RESULTS_FILE" ]]; then
  total=$(wc -l <"$RESULTS_FILE")
  passed=$(grep -c '"status":"PASS"' "$RESULTS_FILE" || echo 0)
  failed=$(grep -c '"status":"FAIL"' "$RESULTS_FILE" || echo 0)

  echo "Summary: $passed/$total passed, $failed failed"

  if [[ $failed -gt 0 ]]; then
    exit 1
  fi
fi
