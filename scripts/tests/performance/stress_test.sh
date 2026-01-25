#!/usr/bin/env bash
set -euo pipefail

# Stress test for shell functions
# Tests behavior under repeated rapid invocation

ITERATIONS="${1:-100}"

stress_test_function() {
  local func_name="$1"
  local test_cmd="$2"
  local start end elapsed

  echo "Stress testing $func_name ($ITERATIONS iterations)..."

  start=$(date +%s%3N)
  for ((i=1; i<=ITERATIONS; i++)); do
    eval "$test_cmd" >/dev/null 2>&1 || true
  done
  end=$(date +%s%3N)

  elapsed=$((end - start))
  local per_call=$((elapsed / ITERATIONS))

  echo "  Total: ${elapsed}ms, Per call: ${per_call}ms"
}

main() {
  echo "Starting stress tests..."
  echo ""

  # Test genpass under load
  source "$HOME/.dotfiles/.chezmoitemplates/functions/genpass.sh" 2>/dev/null || true
  if type genpass &>/dev/null; then
    stress_test_function "genpass" "genpass 16"
  fi

  # Test extract help (no actual extraction)
  source "$HOME/.dotfiles/.chezmoitemplates/functions/extract.sh" 2>/dev/null || true
  if type extract &>/dev/null; then
    stress_test_function "extract --help" "extract --help"
  fi
}

main "$@"
