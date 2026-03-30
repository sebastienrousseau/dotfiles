#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# shellcheck source=../../../tests/framework/assertions.sh
source "$REPO_ROOT/tests/framework/assertions.sh"

DOCS_SCRIPT="$REPO_ROOT/scripts/qa/docs-coverage.sh"
SCRIPTS_DOC="$REPO_ROOT/docs/reference/SCRIPTS.md"
ARCH_DOC="$REPO_ROOT/docs/architecture/ARCHITECTURE.md"

test_start "docs_repo_coverage_scripts_catalog_exists"
assert_file_exists "$SCRIPTS_DOC" "script catalog should exist"

test_start "docs_repo_coverage_scripts_catalog_has_key_utilities"
assert_file_contains "$SCRIPTS_DOC" '`ai-update`' "scripts catalog should document ai-update"
assert_file_contains "$SCRIPTS_DOC" '`jsonv`' "scripts catalog should document jsonv"
assert_file_contains "$SCRIPTS_DOC" '`tmux-sessionizer`' "scripts catalog should document tmux-sessionizer"

test_start "docs_repo_coverage_architecture_has_function_groups"
assert_file_contains "$ARCH_DOC" '`api`' "architecture doc should document api group"
assert_file_contains "$ARCH_DOC" '`files`' "architecture doc should document files group"
assert_file_contains "$ARCH_DOC" '`misc`' "architecture doc should document misc group"

test_start "docs_repo_coverage_contract_passes"
assert_exit_code 0 "bash '$DOCS_SCRIPT'"

test_start "docs_repo_coverage_contract_can_enforce_threshold"
assert_file_contains "$DOCS_SCRIPT" 'Threshold:' "docs coverage script should print the required threshold"
