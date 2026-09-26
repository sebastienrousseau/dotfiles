#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# tools/ci/run-coverage.sh, the xtrace-based bash coverage runner: run it on
# a tiny fixture project and check the lcov report it writes, instead of
# grepping the runner for PS4=, BASH_ENV= and friends.
#
# The fixture script has a line inside a command substitution, a line in a
# subshell and a function no test calls; one test in unit/ and one with the
# same file name in regression/ each call a different function.
#
# Under a coverage sweep (COV_TRACE_DIR is set) the fixture runs are
# skipped: a nested runner would add its own tracing to the sweep's.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

RUNNER="$REPO_ROOT/tools/ci/run-coverage.sh"

if [[ -n "${COV_TRACE_DIR:-}" ]] || ! command -v git >/dev/null 2>&1; then
  test_start "run_coverage_fixture_skipped"
  assert_true "true" "skipped: running inside a coverage sweep or without git"
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
  exit 0
fi

# A short physical path: the runner reports physical paths, and macOS
# /bin/bash 3.2 truncates the expanded PS4 at 100 characters, so a deep
# TMPDIR (/private/var/folders/...) mangles records and the runner, by
# design, refuses to report.
FX="$(cd "$(mktemp -d /tmp/rcov.XXXXXX)" && pwd -P)"
trap 'rm -rf "$FX"' EXIT
mkdir -p "$FX/repo/scripts" "$FX/repo/tests/unit" "$FX/repo/tests/regression"
cat >"$FX/repo/scripts/lib.sh" <<'LIB'
#!/usr/bin/env bash
subst_line() {
  local v
  v="$(printf 'in-subst')"
  printf '%s\n' "$v"
}
subshell_line() {
  (printf 'in-subshell\n')
}
never_called() {
  printf 'never\n'
}
LIB
printf '#!/usr/bin/env bash\nsource "$(dirname "$0")/../../scripts/lib.sh"\nsubst_line >/dev/null\necho "RESULTS:1:1:0"\n' \
  >"$FX/repo/tests/unit/test_lib.sh"
printf '#!/usr/bin/env bash\nsource "$(dirname "$0")/../../scripts/lib.sh"\nsubshell_line >/dev/null\necho "RESULTS:1:1:0"\n' \
  >"$FX/repo/tests/regression/test_lib.sh"
chmod +x "$FX"/repo/tests/*/*.sh "$FX/repo/scripts/lib.sh"
(cd "$FX/repo" && git init -q . && git add -A && git -c user.email=t@example.com -c user.name=t commit -qm fixture)

# run_cov <out-dir> <min-pct>: run the runner on the fixture.
run_cov() {
  COV_RC=0
  env REPO_ROOT="$FX/repo" TESTS_DIR="$FX/repo/tests" COVERAGE_DIR="$FX/$1" \
    COV_INCLUDE_DIRS="$FX/repo/scripts" JOBS=2 MIN_COVERAGE_PCT="$2" \
    bash "$RUNNER" >"$FX/$1.log" 2>&1 || COV_RC=$?
}

# hits <line>: the lcov hit count for that line of the fixture script.
hits() { sed -n "s/^DA:$1,//p" "$FX/cov/lcov.info"; }

run_cov cov 0

test_start "run_coverage_writes_lcov"
assert_equals "0|SF:$FX/repo/scripts/lib.sh" "$COV_RC|$(grep '^SF:' "$FX/cov/lcov.info")" \
  "the runner succeeds and reports the fixture script"

test_start "run_coverage_counts_command_substitution"
assert_true '[[ "$(hits 4)" -ge 2 ]]' "a line run inside \$(...) is counted twice: the assignment and the nested command"

test_start "run_coverage_traces_regression_tests"
assert_true '[[ "$(hits 8)" -ge 1 ]]' "a subshell line that only regression/test_lib.sh reaches is counted"

test_start "run_coverage_keeps_same_named_tests_apart"
assert_true '[[ "$(hits 3)" -ge 1 && "$(hits 8)" -ge 1 ]]' \
  "unit/test_lib.sh and regression/test_lib.sh both contribute their lines"

test_start "run_coverage_reports_uncovered_lines"
assert_true '[[ "$(hits 11)" == 0 ]] && grep -q "4/5 lines = 80.00%" "$FX/cov.log"' \
  "an uncalled function's line is reported as 0 and the total is 4/5"

test_start "run_coverage_enforces_minimum"
run_cov cov-floor 90
assert_true '[[ $COV_RC -ne 0 ]] && grep -q "coverage 80.00% is below the floor 90%" "$FX/cov-floor.log"' \
  "coverage below MIN_COVERAGE_PCT fails the run and says so"

test_start "run_coverage_passes_at_minimum"
run_cov cov-met 80
assert_equals "0" "$COV_RC" "coverage at MIN_COVERAGE_PCT passes"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
