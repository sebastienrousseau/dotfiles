#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
## Enforce examples coverage: every core feature domain ships a runnable
## example. Mirrors test_qa_docs_coverage.sh for the examples/ side.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
# shellcheck source=../../../tests/framework/assertions.sh
source "$REPO_ROOT/tests/framework/assertions.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/qa/examples-coverage.sh"
EXAMPLES_DIR="$REPO_ROOT/examples"

test_start "examples_coverage_script_exists"
assert_file_exists "$SCRIPT_FILE" "examples coverage script should exist"

test_start "examples_coverage_syntax"
assert_exit_code 0 "bash -n '$SCRIPT_FILE'"

# Feature domains that were previously undocumented-by-example.
test_start "examples_cover_theme_secrets_fleet"
assert_file_exists "$EXAMPLES_DIR/example-theme.sh" "theme feature must have an example"
assert_file_exists "$EXAMPLES_DIR/example-secrets.sh" "secrets feature must have an example"
assert_file_exists "$EXAMPLES_DIR/example-fleet.sh" "fleet feature must have an example"

# Per-command reference: every public dot command has a usage example.
test_start "examples_have_per_command_reference"
assert_file_exists "$EXAMPLES_DIR/example-command-reference.sh" "per-command reference example must exist"

# Contract passes at 100% for BOTH feature domains and per-command coverage.
test_start "examples_coverage_contract_passes"
assert_exit_code 0 "REPO_ROOT='$REPO_ROOT' bash '$SCRIPT_FILE'"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
