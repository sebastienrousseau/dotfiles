#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# test-kind: structural
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

TEST_SCRIPT="$REPO_ROOT/scripts/diagnostics/version-locks.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "version_locks_exists"
assert_file_exists "$TEST_SCRIPT" "version-locks.sh should exist"

test_start "version_locks_syntax"
if bash -n "$TEST_SCRIPT" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: syntax error"
fi

test_start "version_locks_shebang"
first_line=$(head -n 1 "$TEST_SCRIPT")
assert_equals "#!/usr/bin/env bash" "$first_line" "should have bash shebang"

# The report reads the managed conf.d. An inline-table entry (first-party
# tools carry minimum_release_age = "0s") shows its version, not the table
# syntax, and the update note points at conf.d: config.toml pins shadow it.
test_start "version_locks_reports_conf_d_versions_and_where_to_edit"
FX="$(mktemp -d)"
mkdir -p "$FX/defaults/dot_config/mise/conf.d"
echo defaults >"$FX/.chezmoiroot"
cat >"$FX/defaults/dot_config/mise/conf.d/00-dotfiles.toml" <<'TOML'
[tools]
node = "26"
"github:me/tool" = { version = "0.0.54", minimum_release_age = "0s" }
TOML
out="$(CHEZMOI_SOURCE_DIR="$FX" NO_COLOR=1 bash "$TEST_SCRIPT" 2>&1 | sed 's/[[:space:]]\{1,\}/ /g')"
rm -rf "$FX"
assert_contains "github:me/tool 0.0.54" "$out" "an inline table's version is reported" || true
assert_contains "node 26" "$out" "a plain version is reported" || true
assert_contains "Edit defaults/dot_config/mise/conf.d/00-dotfiles.toml" "$out" "the note names conf.d as the place to edit" || true

# Slice 3 (#883): exercise the script under sandbox for line coverage
cov_exercise_script "$TEST_SCRIPT"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
