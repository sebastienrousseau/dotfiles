#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

include_module_coverage=0

usage() {
  cat <<'EOF'
Coverage Baseline

Usage:
  coverage-baseline.sh [--with-module-coverage]

Options:
  --with-module-coverage  Run tests/framework/module_coverage.sh and include the result
  -h, --help              Show this help
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --with-module-coverage)
      include_module_coverage=1
      ;;
    -h | --help)
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

unit_tests="$(find "$REPO_ROOT/tests/unit" -name 'test_*.sh' | wc -l | tr -d ' ')"
integration_tests="$(find "$REPO_ROOT/tests/integration" -name 'test_*.sh' | wc -l | tr -d ' ')"
total_tests="$(find "$REPO_ROOT/tests" -path '*/framework/*' -prune -o -name 'test_*.sh' -print | wc -l | tr -d ' ')"
named_tests="$(rg -o '\btest_start\b' "$REPO_ROOT/tests/unit" "$REPO_ROOT/tests/integration" -g 'test_*.sh' | wc -l | tr -d ' ')"
docs_files="$(find "$REPO_ROOT/docs" -type f \( -name '*.md' -o -name '*.md.tmpl' \) | wc -l | tr -d ' ')"
shell_surfaces="$(find "$REPO_ROOT/scripts" "$REPO_ROOT/dot_local/bin" "$REPO_ROOT/.chezmoitemplates/functions" -type f \( -name '*.sh' -o -name 'executable_*' \) | wc -l | tr -d ' ')"

printf 'Coverage Baseline\n'
printf 'Repository: %s\n' "$REPO_ROOT"
printf 'Documentation files: %s\n' "$docs_files"
printf 'Executable shell surfaces: %s\n' "$shell_surfaces"
printf 'Unit test files: %s\n' "$unit_tests"
printf 'Integration test files: %s\n' "$integration_tests"
printf 'Total test files: %s\n' "$total_tests"
printf 'Named tests: %s\n' "$named_tests"

if [ "$include_module_coverage" -eq 1 ]; then
  printf '\n'
  (cd "$REPO_ROOT" && bash ./tests/framework/module_coverage.sh)
fi
