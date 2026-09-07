#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Flag-dispatch tests for scripts/diagnostics/doctor-unified.sh.
#
# The script maps each flag to a target script and then `exec`s it, so
# a naive per-flag test would run six real diagnostics. Instead the
# flags are passed together: the `for` loop visits every case arm, and
# the last flag decides the target. That reaches all six mappings in one
# run while keeping the target under the test's control.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# The assertions below capture each child's stdout and stderr, which
# would also swallow the xtrace records the repo's coverage runner reads
# from stderr. Hand every child a copy of this test's real stderr on
# fd 21 and point BASH_XTRACEFD at it, so its line records still reach
# the runner while the captured text stays clean.
exec 21>&2

DU_FILE="$REPO_ROOT/scripts/diagnostics/doctor-unified.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

TMP="$DOTFILES_COV_TMPDIR"
mkdir -p "$TMP/du-home"

DU_OUT=""
DU_RC=0
_run_du() {
  DU_RC=0
  DU_OUT="$(
    cd "$TMP/du-home" &&
      env BASH_XTRACEFD=21 HOME="$TMP/du-home" DOTFILES_ACCESSIBILITY=1 \
        "$BASH" "$DU_FILE" "$@" </dev/null 2>&1
  )" || DU_RC=$?
}

_du_expect() {
  local label="$1" want_rc="$2"
  shift 2
  local needle problems=""
  [[ "$DU_RC" == "$want_rc" ]] || problems="${problems}\n      rc: want $want_rc, got $DU_RC"
  for needle in "$@"; do
    [[ "$DU_OUT" == *"$needle"* ]] || problems="${problems}\n      missing: $needle"
  done
  test_start "$label"
  if [[ -z "$problems" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST$problems"
    printf '%s\n' "$DU_OUT" | tail -20 | sed 's/^/      /'
  fi
}

# =======================================================================
# 1. `--audit` maps to scripts/ops/health-check.sh, which the repo does
#    not ship: that is the missing-target guard.
# =======================================================================
_run_du --audit
_du_expect "audit_flag_reports_missing_target" 1 \
  "Script not found" "scripts/ops/health-check.sh"

_run_du -a
_du_expect "audit_short_flag_reports_missing_target" 1 "scripts/ops/health-check.sh"

# =======================================================================
# 2. Every other flag arm runs in a single pass. The loop visits each
#    case arm in argv order, so ending on --audit keeps the exec away
#    from a real diagnostic while still proving the mappings ran.
# =======================================================================
_run_du --heal --score --smoke --drift --benchmark --json --ai extra-arg --audit
_du_expect "all_flag_arms_are_visited_last_one_wins" 1 \
  "Script not found" "scripts/ops/health-check.sh"

_run_du -H -s -m -d -b -j -A -a
_du_expect "short_flag_arms_are_visited" 1 "scripts/ops/health-check.sh"

# =======================================================================
# 3. A resolvable target is exec'd. `--benchmark` picks tests/benchmark.sh,
#    which is the cheapest of the six and needs no fixture.
#
#    The assertion is on the banner the target prints, not on the exit
#    status: after `exec` the status belongs to benchmark.sh, which is
#    not this script's contract. It exits 0 where zsh and hyperfine are
#    installed and 127 on a runner without them, and doctor-unified has
#    done its job identically in both cases.
# =======================================================================
_run_du --benchmark
test_start "benchmark_flag_execs_its_target"
if [[ "$DU_OUT" == *"Total Startup Benchmark"* ]] &&
  [[ "$DU_OUT" != *"Script not found"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (target rc=$DU_RC)"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: the benchmark target did not run"
  printf '%s\n' "$DU_OUT" | tail -20 | sed 's/^/      /'
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
