#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

TEST_SCRIPT="$REPO_ROOT/scripts/diagnostics/scorecard.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "scorecard_exists"
assert_file_exists "$TEST_SCRIPT" "scorecard.sh should exist"

test_start "scorecard_syntax"
if bash -n "$TEST_SCRIPT" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: syntax error"
fi

# A fixture tree whose health/security/perf probes print fixed JSON, so the
# report renders without measuring the host.
FX="$DOTFILES_COV_TMPDIR/scorecard-fx"
mkdir -p "$FX/scripts/diagnostics" "$FX/bin"
ln -s "$REPO_ROOT/lib" "$FX/lib"
ln -s "$TEST_SCRIPT" "$FX/scripts/diagnostics/scorecard.sh"
probe() {
  printf '#!/usr/bin/env bash\ncat <<'"'"'JSON'"'"'\n%s\nJSON\n' "$2" >"$FX/scripts/diagnostics/$1"
}
probe health.sh '{"score": 60, "warnings": 0, "failures": 2}'
probe security-score.sh '{"score": 100}'
probe perf.sh '{"score": 100, "mean_ms": 50, "target_ms": 150}'
printf '#!/usr/bin/env bash\nexit 0\n' >"$FX/bin/chezmoi"
chmod +x "$FX/bin/chezmoi"

test_start "scorecard_health_failure_verdict_stays_on_stdout"
# The Health verdict is a result row: stdout, not stderr (ui_fail).
sc_rc=0
sc_out="$(NO_COLOR=1 PATH="$FX/bin:$PATH" bash "$FX/scripts/diagnostics/scorecard.sh" 2>"$FX/stderr" </dev/null)" || sc_rc=$?
assert_equals "0" "$sc_rc" "the scorecard renders"
assert_contains "Failures detected (run 'dot doctor fix')" "$sc_out" "the failed Health verdict is on stdout"
assert_equals "0" "$(grep -v '^+' "$FX/stderr" | grep -c 'Failures detected' || true)" "and not on stderr"

# Slice 3 (#883): exercise the script under sandbox for line coverage
cov_exercise_script "$TEST_SCRIPT"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
