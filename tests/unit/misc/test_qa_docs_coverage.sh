#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# shellcheck source=../../../tests/framework/assertions.sh
source "$REPO_ROOT/tests/framework/assertions.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/qa/docs-coverage.sh"
UTILS_DOC="$REPO_ROOT/docs/reference/UTILS.md"
AI_DOC="$REPO_ROOT/docs/AI.md"

test_start "docs_coverage_script_exists"
assert_file_exists "$SCRIPT_FILE" "docs coverage script should exist"

test_start "docs_coverage_syntax"
assert_exit_code 0 "bash -n '$SCRIPT_FILE'"

test_start "docs_coverage_utils_reference_has_public_ai_commands"
assert_file_contains "$UTILS_DOC" '`dot ai-setup`' "UTILS should document dot ai-setup"
assert_file_contains "$UTILS_DOC" '`dot ai-query`' "UTILS should document dot ai-query"
assert_file_contains "$UTILS_DOC" '`dot fleet`' "UTILS should document dot fleet"
assert_file_contains "$UTILS_DOC" '`dot help`' "UTILS should document dot help"

test_start "docs_coverage_ai_reference_has_provider_bridges"
assert_file_contains "$AI_DOC" '`dot cl`' "AI doc should document dot cl"
assert_file_contains "$AI_DOC" '`dot copilot`' "AI doc should document dot copilot"
assert_file_contains "$AI_DOC" '`dot cline`' "AI doc should document dot cline"
assert_file_contains "$AI_DOC" '`dot aider`' "AI doc should document dot aider"

test_start "docs_coverage_contract_passes"
assert_exit_code 0 "bash '$SCRIPT_FILE'"
