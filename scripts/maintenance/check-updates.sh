#!/usr/bin/env bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
# Dependency update checker for nightly CI
# Reports available updates for all project dependencies

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPORT_DIR="$REPO_ROOT/nightly-reports"

mkdir -p "$REPORT_DIR"

check_github_actions_updates() {
  echo "=== GitHub Actions Updates ===" >>"$REPORT_DIR/updates.txt"

  # Extract all GitHub Actions from workflow files
  find "$REPO_ROOT/.github/workflows" -name "*.yml" -o -name "*.yaml" | while read -r workflow; do
    echo "Checking $(basename "$workflow")..." >&2
    grep -E "uses: [^@]+@v[0-9]+" "$workflow" | sed 's/.*uses: //' | sort -u >>"$REPORT_DIR/actions-current.txt" 2>/dev/null || true
  done

  if [[ -f "$REPORT_DIR/actions-current.txt" ]]; then
    # For each action, check if newer version exists (simplified check)
    while read -r action_version; do
      if [[ -n "$action_version" ]]; then
        action_name=$(echo "$action_version" | cut -d'@' -f1)
        current_version=$(echo "$action_version" | cut -d'@' -f2)
        echo "  $action_name: $current_version (check manually)" >>"$REPORT_DIR/updates.txt"
      fi
    done <"$REPORT_DIR/actions-current.txt"
  fi

  echo "" >>"$REPORT_DIR/updates.txt"
}

check_precommit_updates() {
  echo "=== Pre-commit Hook Updates ===" >>"$REPORT_DIR/updates.txt"

  if command -v pre-commit &>/dev/null && [[ -f "$REPO_ROOT/.pre-commit-config.yaml" ]]; then
    cd "$REPO_ROOT"
    pre-commit autoupdate --dry-run >>"$REPORT_DIR/updates.txt" 2>&1 || true
  else
    echo "pre-commit not available or config missing" >>"$REPORT_DIR/updates.txt"
  fi

  echo "" >>"$REPORT_DIR/updates.txt"
}

check_chezmoi_updates() {
  echo "=== Chezmoi Updates ===" >>"$REPORT_DIR/updates.txt"

  if command -v curl &>/dev/null; then
    LATEST_VERSION=$(curl -s "https://api.github.com/repos/twpayne/chezmoi/releases/latest" | grep '"tag_name"' | cut -d'"' -f4 | sed 's/^v//')
    CURRENT_VERSION=$(grep "CHEZMOI_VERSION:" "$REPO_ROOT/.github/workflows/ci.yml" | cut -d'"' -f2 | head -1)

    echo "Current Chezmoi: $CURRENT_VERSION" >>"$REPORT_DIR/updates.txt"
    echo "Latest Chezmoi:  $LATEST_VERSION" >>"$REPORT_DIR/updates.txt"

    if [[ "$CURRENT_VERSION" != "$LATEST_VERSION" ]]; then
      echo "⚠️  Chezmoi update available: $CURRENT_VERSION → $LATEST_VERSION" >>"$REPORT_DIR/updates.txt"
    else
      echo "✅ Chezmoi is up to date" >>"$REPORT_DIR/updates.txt"
    fi
  else
    echo "curl not available - cannot check Chezmoi version" >>"$REPORT_DIR/updates.txt"
  fi

  echo "" >>"$REPORT_DIR/updates.txt"
}

check_security_tools_updates() {
  echo "=== Security Tools Updates ===" >>"$REPORT_DIR/updates.txt"

  # Check shellcheck version
  if command -v shellcheck &>/dev/null; then
    SHELLCHECK_VERSION=$(shellcheck --version | grep version: | cut -d' ' -f2)
    echo "Shellcheck: $SHELLCHECK_VERSION" >>"$REPORT_DIR/updates.txt"
  fi

  # Check other tools if available
  for tool in shfmt stylua luacheck; do
    if command -v "$tool" &>/dev/null; then
      VERSION=$($tool --version 2>&1 | head -1 || echo "unknown")
      echo "$tool: $VERSION" >>"$REPORT_DIR/updates.txt"
    fi
  done

  echo "" >>"$REPORT_DIR/updates.txt"
}

generate_summary() {
  echo "=== Update Summary ===" >>"$REPORT_DIR/updates.txt"
  echo "Generated: $(date -Iseconds)" >>"$REPORT_DIR/updates.txt"
  echo "Repository: $REPO_ROOT" >>"$REPORT_DIR/updates.txt"
  echo "" >>"$REPORT_DIR/updates.txt"

  # Count potential updates (simplified heuristic)
  local update_count
  update_count=$(grep -c "⚠️\|→" "$REPORT_DIR/updates.txt" 2>/dev/null || echo "0")

  if [[ $update_count -gt 0 ]]; then
    echo "🔄 $update_count potential updates found" >>"$REPORT_DIR/updates.txt"
  else
    echo "✅ All dependencies appear current" >>"$REPORT_DIR/updates.txt"
  fi
}

main() {
  echo "Dependency Update Checker"
  echo "========================"
  echo "Checking for available updates..."

  # Clear previous report
  >"$REPORT_DIR/updates.txt"

  check_chezmoi_updates
  check_precommit_updates
  check_github_actions_updates
  check_security_tools_updates
  generate_summary

  echo "Report generated: $REPORT_DIR/updates.txt"
  echo ""
  echo "Summary:"
  tail -10 "$REPORT_DIR/updates.txt"
}

main "$@"
