#!/usr/bin/env bash
# Guard against full-history gitleaks scans on manual runs.
# This ensures workflow checkout remains shallow near gitleaks steps.

set -euo pipefail

check_workflow() {
  local workflow="$1"
  local failed=0
  local line_no

  while IFS=: read -r line_no _; do
    local start end context
    start=$((line_no - 16))
    end=$((line_no + 2))
    if [[ "$start" -lt 1 ]]; then
      start=1
    fi

    context="$(sed -n "${start},${end}p" "$workflow")"

    if [[ "$context" != *"actions/checkout"* ]]; then
      echo "ERROR: $workflow:$line_no missing nearby checkout for gitleaks step."
      failed=1
      continue
    fi

    if [[ "$context" != *"fetch-depth: 1"* ]]; then
      echo "ERROR: $workflow:$line_no gitleaks step must use checkout fetch-depth: 1."
      failed=1
    fi

    if [[ "$context" == *"fetch-depth: 0"* ]]; then
      echo "ERROR: $workflow:$line_no gitleaks step contains forbidden fetch-depth: 0."
      failed=1
    fi
  done < <(grep -n "gitleaks/gitleaks-action" "$workflow" || true)

  return "$failed"
}

main() {
  local failed=0

  check_workflow ".github/workflows/ci.yml" || failed=1
  check_workflow ".github/workflows/security-enhanced.yml" || failed=1

  if [[ "$failed" -ne 0 ]]; then
    echo "Gitleaks checkout guard failed."
    exit 1
  fi

  echo "Gitleaks checkout guard passed."
}

main "$@"
