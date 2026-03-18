#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

mode="full"
run_integration=0
min_coverage="${MIN_COVERAGE:-100}"

platform_name() {
  case "$(uname -s)" in
    Darwin) echo "macOS" ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "WSL"
      else
        echo "Linux"
      fi
      ;;
    *) echo "Unknown" ;;
  esac
}

usage() {
  cat <<'EOF'
Reliability Audit

Usage:
  reliability-audit.sh [--quick] [--unit-only] [--with-integration]

Options:
  --quick             Run syntax, unit, coverage, and examples
  --unit-only         Run syntax, unit, coverage, and examples
  --with-integration  Include integration tests
EOF
}

run_step() {
  local label="$1"
  shift
  printf '\n[%s] %s\n' "$(date +%H:%M:%S)" "$label"
  "$@"
}

shell_syntax() {
  local failed=0
  local file

  while IFS= read -r -d '' file; do
    if ! bash -n "$file"; then
      failed=$((failed + 1))
    fi
  done < <(find "$REPO_ROOT" \
    \( -path "$REPO_ROOT/.git" -o -path "$REPO_ROOT/.coverage" \) -prune \
    -o -type f \( -name "*.sh" -o -name "*.bash" \) -print0)

  if [ "$failed" -ne 0 ]; then
    printf 'Syntax failures: %s\n' "$failed" >&2
    return 1
  fi
}

unit_tests() {
  cd "$REPO_ROOT"
  ./tests/framework/test_runner.sh
}

integration_tests() {
  cd "$REPO_ROOT"
  RUN_INTEGRATION=1 ./tests/framework/test_runner.sh -i
}

coverage_gate() {
  cd "$REPO_ROOT"
  MIN_COVERAGE="$min_coverage" ./tests/framework/module_coverage.sh
}

example_gate() {
  cd "$REPO_ROOT"
  bash ./scripts/qa/validate-examples.sh
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --quick)
      mode="quick"
      ;;
    --unit-only)
      mode="unit"
      ;;
    --with-integration)
      run_integration=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [ "$mode" = "full" ]; then
  run_integration=1
fi

printf 'Reliability Audit\n'
printf 'Platform: %s\n' "$(platform_name)"
printf 'Coverage floor: %s%%\n' "$min_coverage"

run_step "Shell syntax" shell_syntax
run_step "Unit suite" unit_tests
run_step "Module coverage" coverage_gate
run_step "Executable examples" example_gate

if [ "$run_integration" -eq 1 ]; then
  run_step "Integration suite" integration_tests
fi

printf '\nReliability audit passed.\n'
