#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Example: Quality assurance and validation scripts
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

printf 'Coverage baseline: %s\n' "$repo_root/scripts/qa/coverage-baseline.sh"
printf 'Docs coverage: %s\n' "$repo_root/scripts/qa/docs-coverage.sh"
printf 'Reliability audit: %s\n' "$repo_root/scripts/qa/reliability-audit.sh"
printf 'Traceability coverage: %s\n' "$repo_root/scripts/qa/traceability-coverage.sh"
printf 'Validate examples: %s\n' "$repo_root/scripts/qa/validate-examples.sh"
printf 'WSL contract: %s\n' "$repo_root/scripts/qa/wsl-contract.sh"

# Run docs coverage as a functional validation
bash "$repo_root/scripts/qa/docs-coverage.sh"
