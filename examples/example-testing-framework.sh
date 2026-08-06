#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Example: Testing framework capabilities
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

printf 'Test runner: %s\n' "$repo_root/tests/framework/test_runner.sh"
printf 'Assertions: %s\n' "$repo_root/tests/framework/assertions.sh"
printf 'Mocks: %s\n' "$repo_root/tests/framework/mocks.sh"
printf 'Mock OS: %s\n' "$repo_root/tests/framework/mock_os.sh"
printf 'Property testing: %s\n' "$repo_root/tests/framework/property_testing.sh"
printf 'Coverage analyzer: %s\n' "$repo_root/tests/framework/coverage_analyzer.sh"
printf 'Module coverage: %s\n' "$repo_root/tests/framework/module_coverage.sh"
printf 'Test framework: %s\n' "$repo_root/tests/framework/test_framework.sh"

# Validate all framework files have valid syntax
for script in "$repo_root"/tests/framework/*.sh; do
  bash -n "$script" || { printf 'FAIL: %s\n' "$script" >&2; exit 1; }
done

# Count test files
unit_count="$(find "$repo_root/tests/unit" -name "test_*.sh" -o -name "test_*.lua" | wc -l | tr -d ' ')"
printf '\nUnit test files: %s\n' "$unit_count"
printf 'Framework files: 8\n'
printf 'All framework files pass syntax check.\n'
