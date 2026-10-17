#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# test-kind: structural
# shellcheck disable=SC1090,SC1091,SC2034
# Regression for: 125ee036
# Regression: guard the test-framework invariant
#
#   TESTS_RUN == TESTS_PASSED + TESTS_FAILED
#
# For every regression suite in `tests/regression/`.
#
# Baseline: v0.2.510 audit found `test_boundary_edge_cases.sh` and
# `test_integration.sh` violating this invariant because some
# `test_start "name"` blocks were followed by MULTIPLE `assert_*`
# calls (each of which increments PASSED/FAILED, whereas test_start
# only increments RUN once). The runtime symptom was
# `RESULTS:59:61:0` — 59 named tests but 61 assertions.
#
# The invariant matters because parallel test runners rely on
# `RUN` matching `PASSED+FAILED` to detect under-counted failures
# — if you can bump PASSED without a matching RUN, a hidden
# assertion could fail silently after its RUN has already been
# counted.
#
# This test runs every regression suite AS-IS (in a sandbox) and
# extracts the RESULTS: line. Suites that print
# `RESULTS:<a>:<b>:<c>` with a != b+c are failures.
#
# The suite that self-runs is excluded to avoid infinite recursion.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

readonly SELF_NAME="test_test_framework_invariants.sh"

# Sandbox HOME so incidental writes land in tmp and don't leak.
sandbox="$(mktemp -d -t dot-inv.XXXXXX)"
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/.config" "$sandbox/.local/share" "$sandbox/.cache" \
  "$sandbox/.local/state"
ln -s "$REPO_ROOT" "$sandbox/.dotfiles"
export HOME="$sandbox" \
  XDG_CONFIG_HOME="$sandbox/.config" \
  XDG_DATA_HOME="$sandbox/.local/share" \
  XDG_CACHE_HOME="$sandbox/.cache" \
  XDG_STATE_HOME="$sandbox/.local/state" \
  CHEZMOI_SOURCE_DIR="$REPO_ROOT" \
  DOT_OPENER=true \
  BROWSER=true \
  EDITOR=true \
  VISUAL=true \
  GIT_EDITOR=true

# ═══════════════════════════════════════════════════════════════
# Runner: run one suite, extract RESULTS, assert invariant.
# ═══════════════════════════════════════════════════════════════

mkdir -p "$sandbox/out" "$sandbox/homes"

run_suite_worker() {
  local suite_path="$1"
  local suite_name suite_home rc=0
  suite_name="$(basename "$suite_path")"
  suite_home="$sandbox/homes/${suite_name%.sh}"
  mkdir -p "$suite_home/.config" "$suite_home/.local/share" \
    "$suite_home/.cache" "$suite_home/.local/state"
  ln -s "$REPO_ROOT" "$suite_home/.dotfiles"

  HOME="$suite_home" \
    XDG_CONFIG_HOME="$suite_home/.config" \
    XDG_DATA_HOME="$suite_home/.local/share" \
    XDG_CACHE_HOME="$suite_home/.cache" \
    XDG_STATE_HOME="$suite_home/.local/state" \
    run_with_timeout "${INVARIANT_SUITE_TIMEOUT:-360}" bash "$suite_path" \
    >"$sandbox/out/$suite_name.out" 2>&1 || rc=$?
  printf '%d\n' "$rc" >"$sandbox/out/$suite_name.rc"
}
export -f run_suite_worker run_with_timeout
export sandbox REPO_ROOT INVARIANT_SUITE_TIMEOUT

check_suite_invariant() {
  local suite_path="$1"
  local suite_name
  suite_name="$(basename "$suite_path")"
  test_start "framework_invariant_${suite_name%.sh}"

  local out results run passed failed rc=0
  out="$(cat "$sandbox/out/$suite_name.out" 2>/dev/null || true)"
  rc="$(cat "$sandbox/out/$suite_name.rc" 2>/dev/null || echo 1)"

  # The RESULTS: line is emitted by every well-formed suite.
  results="$(printf '%s\n' "$out" | grep -oE 'RESULTS:[0-9]+:[0-9]+:[0-9]+' | tail -1)"

  if [[ -z "$results" ]]; then
    ((TESTS_FAILED++)) || true
    if [[ "$rc" -eq 124 ]]; then
      printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: timed out after ${INVARIANT_SUITE_TIMEOUT:-360}s before emitting RESULTS:"
    else
      printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: no RESULTS: line emitted"
    fi
    printf '        last 3 output lines:\n'
    printf '%s\n' "$out" | tail -3 | sed 's/^/          /'
    return
  fi

  # Parse `RESULTS:<run>:<passed>:<failed>`
  IFS=':' read -r _ run passed failed <<<"$results"

  if [[ "$run" -eq $((passed + failed)) ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $run == $passed + $failed"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: invariant broken ($results)"
    printf '        RUN=%d != PASSED+FAILED=%d\n' "$run" "$((passed + failed))"
    printf '%s\n' "        Fix: some \`test_start\` blocks fire multiple asserts."
    printf '%s\n' "        Split each assert under its own \`test_start \"name_kind\"\`."
  fi
}

echo
echo "── Test framework invariant regression ──"
echo

suites=()
for suite in "$REPO_ROOT/tests/regression/"test_*.sh; do
  [[ "$(basename "$suite")" == "$SELF_NAME" ]] && continue
  suites+=("$suite")
done

if [[ -n "${INVARIANT_RESULTS_DIR:-}" && -d "$INVARIANT_RESULTS_DIR" ]]; then
  for suite in "${suites[@]}"; do
    suite_name="$(basename "$suite")"
    if [[ -f "$INVARIANT_RESULTS_DIR/$suite_name.out" ]]; then
      cp "$INVARIANT_RESULTS_DIR/$suite_name.out" "$sandbox/out/$suite_name.out"
      rc_line="$(grep '^EXIT_STATUS:' "$INVARIANT_RESULTS_DIR/$suite_name.out" | tail -1 || true)"
      printf '%s\n' "${rc_line#EXIT_STATUS:}" >"$sandbox/out/$suite_name.rc"
    else
      run_suite_worker "$suite"
    fi
  done
else
  # shellcheck disable=SC2016
  printf '%s\n' "${suites[@]}" | xargs -I{} -P "${INVARIANT_JOBS:-4}" \
    bash -c 'run_suite_worker "$@"' _ {}
fi

for suite in "${suites[@]}"; do
  check_suite_invariant "$suite"
done

echo
echo "── Summary ──"
echo "  RUN:    $((TESTS_PASSED + TESTS_FAILED))"
echo "  PASSED: $TESTS_PASSED"
echo "  FAILED: $TESTS_FAILED"

TESTS_RUN=$((TESTS_PASSED + TESTS_FAILED))
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"

[[ $TESTS_FAILED -eq 0 ]]
