#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# =============================================================================
# examples-coverage.sh — enforce that every core feature domain ships a
# runnable example under examples/. Mirrors scripts/qa/docs-coverage.sh:
# it is a *coverage contract*, not a linter. Threshold defaults to 100%.
#
# A feature domain is "covered" when examples/example-<domain>.sh exists.
# Keep REQUIRED_AREAS in lockstep with the feature surface — adding a major
# user-facing capability (a new `dot` subsystem) means adding its example.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
EXAMPLES_DIR="$REPO_ROOT/examples"
MIN_EXAMPLES_COVERAGE="${MIN_EXAMPLES_COVERAGE:-100}"

# Core feature domains that must each have examples/example-<area>.sh.
REQUIRED_AREAS=(
  ai-patterns
  cli-utilities
  coverage-gate
  diagnostics
  dot-commands
  functions
  fleet
  git-hooks
  install-uninstall
  ops
  platform-contract
  qa
  secrets
  security
  test-suite
  testing-framework
  theme
)

total=0
covered=0
missing=()
for area in "${REQUIRED_AREAS[@]}"; do
  total=$((total + 1))
  if [ -f "$EXAMPLES_DIR/example-$area.sh" ]; then
    covered=$((covered + 1))
  else
    missing+=("$area")
  fi
done

pct="$(awk -v c="$covered" -v t="$total" \
  'BEGIN{if(t==0){print "0.00"}else{printf "%.2f", (100*c/t)}}')"
printf 'Examples coverage: %s/%s (%s%%)\n' "$covered" "$total" "$pct"
printf 'Threshold: %s%%\n' "$MIN_EXAMPLES_COVERAGE"
if [ "${#missing[@]}" -gt 0 ]; then
  printf 'Missing example for: %s\n' "${missing[*]}" >&2
fi

if awk -v p="$pct" -v min="$MIN_EXAMPLES_COVERAGE" 'BEGIN{exit !(p+0 >= min+0)}'; then
  printf 'PASS: every required feature domain has a runnable example.\n'
  exit 0
fi
printf 'FAIL: examples coverage %s%% is below the %s%% threshold.\n' "$pct" "$MIN_EXAMPLES_COVERAGE" >&2
exit 1
