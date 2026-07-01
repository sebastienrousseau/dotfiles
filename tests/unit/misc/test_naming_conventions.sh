#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
## Enforce the repository naming conventions (docs/NAMING_CONVENTIONS.md).
##
## Codifies the low-risk, unambiguous rules so drift is caught in CI:
##   - alias files:    .chezmoitemplates/aliases/**/*.sh  ends with .aliases.sh
##   - function files: .chezmoitemplates/functions/**/*.sh is lowercase
##   - test files:     tests/{unit,integration,regression}/**/*.sh -> test_*.sh
## Case-sensitive checks (CI is Linux); harmless on case-insensitive FS too.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
# shellcheck source=../../framework/assertions.sh
source "$REPO_ROOT/tests/framework/assertions.sh"

cd "$REPO_ROOT"

# 1. Alias files must match {tool}.aliases.sh (the **/*.aliases.sh glob only
#    autodiscovers these; a hyphen variant silently never loads).
test_start "naming_alias_files_use_dot_aliases_sh"
bad_aliases="$(find defaults/.chezmoitemplates/aliases -type f -name '*.sh' |
  grep -vE '\.aliases\.sh$' || true)"
assert_equals "" "$bad_aliases" "alias files must end in .aliases.sh (got: ${bad_aliases:-none})"

# 2. Function files must be lowercase (bash 3.2 / cross-shell friendliness).
test_start "naming_function_files_lowercase"
upper_fns="$(find defaults/.chezmoitemplates/functions -type f -name '*.sh' |
  grep -E '[A-Z]' || true)"
assert_equals "" "$upper_fns" "function files must be lowercase (got: ${upper_fns:-none})"

# 3. Test files under the unit/integration/regression trees must be test_*.
test_start "naming_test_files_prefixed"
bad_tests="$(find tests/unit tests/integration tests/regression -type f -name '*.sh' 2>/dev/null |
  grep -vE '/test_[^/]+\.sh$' || true)"
assert_equals "" "$bad_tests" "test files must be named test_*.sh (got: ${bad_tests:-none})"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
