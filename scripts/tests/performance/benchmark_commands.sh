#!/usr/bin/env bash
# shellcheck disable=SC2034
# Command execution benchmarks
# Measures responsiveness of common operations
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Results storage
RESULTS_DIR="${RESULTS_DIR:-$HOME/.local/share/dotfiles/benchmarks}"
mkdir -p "$RESULTS_DIR"
RESULTS_FILE="$RESULTS_DIR/commands_$(date +%Y%m%d_%H%M%S).json"

# Thresholds (milliseconds)
ALIAS_RESOLUTION_THRESHOLD_MS=10
CD_OPERATION_THRESHOLD_MS=50
COMPLETION_THRESHOLD_MS=100
HISTORY_SEARCH_THRESHOLD_MS=50
PROMPT_RENDER_THRESHOLD_MS=50

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo "Command Execution Benchmarks"
echo "============================"
echo ""

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

measure_iterations() {
  local iterations="$1"
  shift

  local total=0
  for ((i = 1; i <= iterations; i++)); do
    local time_ms
    time_ms=$(measure_time_ms "$@")
    total=$((total + time_ms))
  done

  echo $((total / iterations))
}

store_result() {
  local command="$1" value="$2" threshold="$3" status="$4"
  printf '{"timestamp":"%s","command":"%s","value_ms":%d,"threshold_ms":%d,"status":"%s"}\n' \
    "$(date -Iseconds)" "$command" "$value" "$threshold" "$status" >>"$RESULTS_FILE"
}

benchmark_command() {
  local name="$1"
  local threshold="$2"
  local iterations="${3:-5}"
  shift 3

  local avg_ms
  avg_ms=$(measure_iterations "$iterations" "$@")

  local status
  if [[ $avg_ms -gt $threshold ]]; then
    status="FAIL"
    printf "  ${RED}✗ FAIL${NC}: %-25s %4dms avg (threshold: %dms)\n" "$name" "$avg_ms" "$threshold"
  else
    status="PASS"
    printf "  ${GREEN}✓ PASS${NC}: %-25s %4dms avg (threshold: %dms)\n" "$name" "$avg_ms" "$threshold"
  fi

  store_result "$name" "$avg_ms" "$threshold" "$status"
}

# ============================================================================
# Directory Operations
# ============================================================================

echo "Directory Operations"
echo "--------------------"

# Basic cd
benchmark_command "cd (basic)" $CD_OPERATION_THRESHOLD_MS 10 \
  bash -c "cd /tmp && cd ~ && cd /usr"

# cd with history tracking (if available)
if type cd_with_history &>/dev/null 2>&1; then
  benchmark_command "cd (with history)" $((CD_OPERATION_THRESHOLD_MS * 2)) 10 \
    bash -c "cd_with_history /tmp && cd_with_history ~"
fi

# Zoxide (if available)
if command -v zoxide >/dev/null 2>&1; then
  benchmark_command "zoxide query" $CD_OPERATION_THRESHOLD_MS 10 \
    zoxide query tmp
fi

echo ""

# ============================================================================
# Alias/Command Resolution
# ============================================================================

echo "Command Resolution"
echo "------------------"

# Type command resolution
benchmark_command "type (builtin)" $ALIAS_RESOLUTION_THRESHOLD_MS 10 \
  bash -c "type cd"

benchmark_command "which (external)" $ALIAS_RESOLUTION_THRESHOLD_MS 10 \
  which ls

# Hash lookup
benchmark_command "hash lookup" $ALIAS_RESOLUTION_THRESHOLD_MS 10 \
  bash -c "hash -t ls 2>/dev/null || true"

echo ""

# ============================================================================
# Git Operations
# ============================================================================

echo "Git Operations (in repo)"
echo "------------------------"

# Only run if we're in a git repo
if git rev-parse --git-dir >/dev/null 2>&1; then
  benchmark_command "git status" 100 5 \
    git status --porcelain

  benchmark_command "git branch" 50 5 \
    git branch --show-current

  benchmark_command "git log -1" 50 5 \
    git log -1 --oneline
else
  printf "  ${YELLOW}- SKIP${NC}: Not in a git repository\n"
fi

echo ""

# ============================================================================
# File Operations
# ============================================================================

echo "File Operations"
echo "---------------"

# ls with colors/icons (if using eza/exa)
if command -v eza >/dev/null 2>&1; then
  benchmark_command "eza (with icons)" 100 10 \
    eza --icons /tmp
elif command -v exa >/dev/null 2>&1; then
  benchmark_command "exa" 100 10 \
    exa /tmp
else
  benchmark_command "ls" 50 10 \
    ls /tmp
fi

# Find with fd
if command -v fd >/dev/null 2>&1; then
  benchmark_command "fd (find)" 100 5 \
    fd -d 2 . /tmp
fi

# Grep with ripgrep
if command -v rg >/dev/null 2>&1; then
  benchmark_command "rg (search)" 100 5 \
    bash -c "echo 'test' | rg test"
fi

echo ""

# ============================================================================
# Fuzzy Finding
# ============================================================================

echo "Fuzzy Finding"
echo "-------------"

if command -v fzf >/dev/null 2>&1; then
  # FZF with simple input
  benchmark_command "fzf (select first)" 100 5 \
    bash -c "echo -e 'a\nb\nc' | fzf --filter=a"
fi

echo ""

# ============================================================================
# Prompt Rendering
# ============================================================================

echo "Prompt Rendering"
echo "----------------"

if command -v starship >/dev/null 2>&1; then
  benchmark_command "starship prompt" $PROMPT_RENDER_THRESHOLD_MS 5 \
    starship prompt
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
