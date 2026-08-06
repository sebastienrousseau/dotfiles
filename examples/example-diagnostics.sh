#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Example: Diagnostics and health-check utilities
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

printf 'Doctor script: %s\n' "$repo_root/scripts/diagnostics/doctor.sh"
printf 'Health dashboard: %s\n' "$repo_root/scripts/diagnostics/health.sh"
printf 'Smoke test: %s\n' "$repo_root/scripts/diagnostics/smoke-test.sh"
printf 'Scorecard: %s\n' "$repo_root/scripts/diagnostics/scorecard.sh"
printf 'Snapshot: %s\n' "$repo_root/scripts/diagnostics/snapshot.sh"
printf 'Verify state: %s\n' "$repo_root/scripts/diagnostics/verify_state.sh"
printf 'Benchmark: %s\n' "$repo_root/scripts/diagnostics/benchmark.sh"
printf 'Perf analysis: %s\n' "$repo_root/scripts/diagnostics/perf.sh"
printf 'Drift dashboard: %s\n' "$repo_root/scripts/diagnostics/drift-dashboard.sh"
printf 'Alias governance: %s\n' "$repo_root/scripts/diagnostics/alias-governance.sh"
printf 'Aliases cheatsheet: %s\n' "$repo_root/scripts/diagnostics/aliases-cheatsheet.sh"
printf 'Aliases manifest: %s\n' "$repo_root/scripts/diagnostics/aliases-manifest.sh"
printf 'Conflicts: %s\n' "$repo_root/scripts/diagnostics/conflicts.sh"
printf 'History analysis: %s\n' "$repo_root/scripts/diagnostics/history-analysis.sh"
printf 'MCP doctor: %s\n' "$repo_root/scripts/diagnostics/mcp-doctor.sh"
printf 'Security score: %s\n' "$repo_root/scripts/diagnostics/security-score.sh"
printf 'Secret governance: %s\n' "$repo_root/scripts/diagnostics/secret-governance.sh"
printf 'Doctor unified: %s\n' "$repo_root/scripts/diagnostics/doctor-unified.sh"
printf 'Version locks: %s\n' "$repo_root/scripts/diagnostics/version-locks.sh"
printf 'Verify: %s\n' "$repo_root/scripts/diagnostics/verify.sh"
printf 'A2A conformance: %s\n' "$repo_root/scripts/diagnostics/a2a-conformance.sh"
printf 'Workstation attestation: %s\n' "$repo_root/scripts/diagnostics/workstation-attestation.sh"

# Validate all diagnostic scripts have valid syntax
for script in "$repo_root"/scripts/diagnostics/*.sh; do
  bash -n "$script" || { printf 'FAIL: %s\n' "$script" >&2; exit 1; }
done
printf 'All %d diagnostic scripts pass syntax check.\n' "$(find "$repo_root/scripts/diagnostics" -name "*.sh" | wc -l | tr -d ' ')"
