#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# shellcheck source=../../../tests/framework/assertions.sh
source "$REPO_ROOT/tests/framework/assertions.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/qa/coverage-baseline.sh"

test_start "coverage_baseline_script_exists"
assert_file_exists "$SCRIPT_FILE" "coverage baseline script should exist"

test_start "coverage_baseline_syntax"
assert_exit_code 0 "bash -n '$SCRIPT_FILE'"

test_start "coverage_baseline_reports_inventory"
assert_file_contains "$SCRIPT_FILE" "Documentation files:" "coverage baseline reports documentation files"
assert_file_contains "$SCRIPT_FILE" "Executable shell surfaces:" "coverage baseline reports executable shell surfaces"
assert_file_contains "$SCRIPT_FILE" "Unit test files:" "coverage baseline reports unit tests"
assert_file_contains "$SCRIPT_FILE" "Integration test files:" "coverage baseline reports integration tests"
assert_file_contains "$SCRIPT_FILE" "Named tests:" "coverage baseline reports named tests"

test_start "coverage_baseline_supports_module_gate"
assert_file_contains "$SCRIPT_FILE" "--with-module-coverage" "coverage baseline supports module coverage flag"
assert_file_contains "$SCRIPT_FILE" "tests/framework/module_coverage.sh" "coverage baseline can run module coverage"
