#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# shellcheck source=../../../tests/framework/assertions.sh
source "$REPO_ROOT/tests/framework/assertions.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/qa/coverage-baseline.sh"

test_start "coverage_baseline_script_exists"
assert_file_exists "$SCRIPT_FILE" "coverage baseline script should exist"

# A fixture tree with known contents: every count the report prints is
# checked against what is actually there.
CB_WORK="$(mktemp -d -t dot-cov-baseline.XXXXXX)"
trap 'rm -rf "$CB_WORK"' EXIT
mkdir -p "$CB_WORK/scripts/qa" "$CB_WORK/tests/unit/a" "$CB_WORK/tests/integration" \
  "$CB_WORK/tests/framework" "$CB_WORK/docs/sub" "$CB_WORK/defaults/dot_local/bin" \
  "$CB_WORK/defaults/.chezmoitemplates/functions/x"
cp "$SCRIPT_FILE" "$CB_WORK/scripts/qa/coverage-baseline.sh"
printf 'test_start "a"\ntest_start "b"\n' >"$CB_WORK/tests/unit/a/test_one.sh"
printf 'test_start "c"\n' >"$CB_WORK/tests/unit/a/test_two.sh"
printf 'test_start "d"\n' >"$CB_WORK/tests/integration/test_three.sh"
touch "$CB_WORK/docs/a.md" "$CB_WORK/docs/sub/b.md.tmpl" "$CB_WORK/docs/not-counted.txt"
touch "$CB_WORK/scripts/qa/extra.sh" "$CB_WORK/defaults/dot_local/bin/executable_tool" \
  "$CB_WORK/defaults/.chezmoitemplates/functions/x/f.sh"
printf 'echo "module coverage stub ran"\n' >"$CB_WORK/tests/framework/module_coverage.sh"

test_start "coverage_baseline_reports_inventory"
cb_out="$(bash "$CB_WORK/scripts/qa/coverage-baseline.sh" 2>&1)"
assert_contains "Documentation files: 2" "$cb_out" "counts .md and .md.tmpl under docs/"
assert_contains "Executable shell surfaces: 4" "$cb_out" "counts scripts, bin executables and functions"
assert_contains "Unit test files: 2" "$cb_out" "counts unit tests"
assert_contains "Integration test files: 1" "$cb_out" "counts integration tests"
assert_contains "Named tests: 4" "$cb_out" "counts test_start calls"
assert_equals "0" "$(grep -c 'module coverage stub ran' <<<"$cb_out")" "module coverage only when asked"

test_start "coverage_baseline_supports_module_gate"
cb_out="$(bash "$CB_WORK/scripts/qa/coverage-baseline.sh" --with-module-coverage 2>&1)"
assert_contains "module coverage stub ran" "$cb_out" "--with-module-coverage runs tests/framework/module_coverage.sh"
