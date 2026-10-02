#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
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

test_start "docs_coverage_utils_reference_has_public_ai_commands"
assert_file_contains "$UTILS_DOC" "\`dot ai-setup\`" "UTILS should document dot ai-setup"
assert_file_contains "$UTILS_DOC" "\`dot ai-query\`" "UTILS should document dot ai-query"
assert_file_contains "$UTILS_DOC" "\`dot fleet\`" "UTILS should document dot fleet"
assert_file_contains "$UTILS_DOC" "\`dot help\`" "UTILS should document dot help"

test_start "docs_coverage_ai_reference_has_provider_bridges"
assert_file_contains "$AI_DOC" "\`dot cl\`" "AI doc should document dot cl"
assert_file_contains "$AI_DOC" "\`dot copilot\`" "AI doc should document dot copilot"
assert_file_contains "$AI_DOC" "\`dot aider\`" "AI doc should document dot aider"

test_start "docs_coverage_contract_passes"
assert_exit_code 0 "bash '$SCRIPT_FILE'"

test_start "docs_coverage_contract_reports_100_percent_floor"
docs_out="$(bash "$SCRIPT_FILE" 2>&1)"
docs_counts="$(printf '%s\n' "$docs_out" | sed -n 's|^Docs coverage: \([0-9]*\)/\([0-9]*\) (100\.00%)$|\1 \2|p')"
assert_equals "true" "$([[ -n "$docs_counts" && "${docs_counts% *}" == "${docs_counts#* }" ]] && echo true || echo false)" \
  "every check is covered: ${docs_counts:-no report line}"
assert_contains "Threshold: 100%" "$docs_out" "the floor defaults to 100%"

# A minimal copy of the inputs with one documented command removed: the gap
# is named and the 100% floor fails the run.
test_start "docs_coverage_names_a_gap_and_fails_the_floor"
DOCS_WORK="$(mktemp -d -t dot-docs-cov.XXXXXX)"
trap 'rm -rf "$DOCS_WORK"' EXIT
for f in scripts/qa/docs-coverage.sh bin/dot docs/reference/UTILS.md docs/AI.md \
  docs/reference/SCRIPTS.md docs/ARCHITECTURE.md defaults/.chezmoitemplates/functions/groups.json; do
  mkdir -p "$DOCS_WORK/$(dirname "$f")"
  cp "$REPO_ROOT/$f" "$DOCS_WORK/$f"
done
sed -i.bak 's/`dot fleet/`dot FLEET/g' "$DOCS_WORK/docs/reference/UTILS.md"
gap_rc=0
gap_out="$(bash "$DOCS_WORK/scripts/qa/docs-coverage.sh" 2>&1)" || gap_rc=$?
assert_not_equals "0" "$gap_rc" "a documentation gap fails the run"
assert_contains "Missing documentation: dot fleet in UTILS.md" "$gap_out" "and names it"
