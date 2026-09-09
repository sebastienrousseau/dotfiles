#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
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

# A restricted PATH for the runs below. `--benchmark` hands control to
# tests/benchmark.sh, whose fallback loop starts ten interactive shells
# and whose fast path runs hyperfine; neither belongs in a unit test, and
# on a busy runner they are unbounded. Leaving every shell and hyperfine
# out of PATH makes that target fail fast and identically everywhere,
# while still proving doctor-unified reached its exec.
DU_BIN="$TMP/du-bin"
mkdir -p "$DU_BIN"
for _t in cat env printf sed grep tr head tail dirname basename mktemp rm uname \
  locale tput wc awk date cut sort stat; do
  _p="$(command -v "$_t" 2>/dev/null || true)"
  [[ -n "$_p" ]] && ln -sf "$_p" "$DU_BIN/$_t"
done
ln -sf "$BASH" "$DU_BIN/bash"

DU_OUT=""
DU_RC=0
_run_du() {
  DU_RC=0
  DU_OUT="$(
    cd "$TMP/du-home" &&
      env BASH_XTRACEFD=21 PATH="$DU_BIN" HOME="$TMP/du-home" DOTFILES_ACCESSIBILITY=1 \
        "$BASH" "$DU_FILE" "$@" </dev/null 2>&1
  )" || DU_RC=$?
}

# _du_expect_out <label> <needle…> — assert on the target's output only.
# After `exec` the exit status belongs to the target, not to
# doctor-unified.sh, so a status assertion there would be testing the
# diagnostic (and the runner it found) rather than the routing.
_du_expect_out() {
  local label="$1"
  shift
  local needle problems=""
  for needle in "$@"; do
    [[ "$DU_OUT" == *"$needle"* ]] || problems="${problems}\n      missing: $needle"
  done
  test_start "$label"
  if [[ -z "$problems" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (target rc=$DU_RC)"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST$problems"
    printf '%s\n' "$DU_OUT" | tail -20 | sed 's/^/      /'
  fi
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
# 1. Every flag maps to a script that is actually in the tree.
#
#    Regression: `--audit` mapped to scripts/ops/health-check.sh, which
#    has never existed here, so the flag died with "Script not found" for
#    every user who tried it — a routing table nobody had checked against
#    the filesystem. Read the targets out of the case arms rather than
#    listing them here, so a new flag is covered the day it is added.
# =======================================================================
test_start "every_flag_target_exists_in_the_tree"
_missing=""
_targets=0
while IFS= read -r _target; do
  [[ -n "$_target" ]] || continue
  _targets=$((_targets + 1))
  [[ -f "$REPO_ROOT/$_target" ]] || _missing="$_missing $_target"
done < <(sed -n 's/^[[:space:]]*--[a-z]*[^)]*)[[:space:]]*target="\([^"]*\)".*/\1/p' "$DU_FILE")
if [[ "$_targets" -ge 6 && -z "$_missing" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST ($_targets targets)"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: parsed $_targets target(s), missing:$_missing"
fi

# =======================================================================
# 2. `--audit` reaches the health dashboard rather than a missing file.
# =======================================================================
_run_du --audit
_du_expect_out "audit_flag_execs_the_health_dashboard" "Dotfiles Health Dashboard"

_run_du -a
_du_expect_out "audit_short_flag_execs_the_health_dashboard" "Dotfiles Health Dashboard"

# =======================================================================
# 3. Every other flag arm runs in a single pass. The loop visits each
#    case arm in argv order, so ending on --audit keeps the exec on the
#    cheapest of the targets while still proving the mappings ran.
# =======================================================================
_run_du --heal --score --smoke --drift --benchmark --json --ai extra-arg --audit
# --json rides along in this pass, so the target renders JSON rather than the
# dashboard banner; assert on a check name, which both forms carry.
_du_expect_out "all_flag_arms_are_visited_last_one_wins" "Chezmoi installed"

_run_du -H -s -m -d -b -j -A -a
_du_expect_out "short_flag_arms_are_visited" "Chezmoi installed"

# =======================================================================
# 4. A second resolvable target. `--benchmark` picks tests/benchmark.sh,
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
