#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for secret governance and provider bridge

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

PROVIDER_FILE="$REPO_ROOT/scripts/lib/secrets_provider.sh"
GOVERNANCE_FILE="$REPO_ROOT/scripts/diagnostics/secret-governance.sh"
HOOK_FILE="$REPO_ROOT/scripts/git-hooks/pre-commit"

test_start "provider_file_exists"
assert_file_exists "$PROVIDER_FILE" "secrets provider bridge should exist"

test_start "provider_file_syntax"
assert_exit_code 0 "bash -n '$PROVIDER_FILE'"

test_start "governance_file_exists"
assert_file_exists "$GOVERNANCE_FILE" "secret governance script should exist"

test_start "governance_file_syntax"
assert_exit_code 0 "bash -n '$GOVERNANCE_FILE'"

test_start "pre_commit_hook_exists"
assert_file_exists "$HOOK_FILE" "pre-commit hook should exist"

test_start "pre_commit_calls_governance"
assert_file_contains "$HOOK_FILE" "secret-governance.sh" "pre-commit hook should run secret governance"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
