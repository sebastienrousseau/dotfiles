#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# tools/ci/hook-bench.sh: the agent hook's p95 gate. It runs in a copy of
# the tree whose bin/dot is a stub that writes the session's state file and
# takes STUB_MS to do it, so a pass, a fail and the guard against timing a
# hook that wrote nothing are each chosen by the fixture.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/hook-bench-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
T="$WORK/tree"
mkdir -p "$T/tools/ci" "$T/bin"
cp "$REPO_ROOT/tools/ci/hook-bench.sh" "$T/tools/ci/"
# The stub: like the hook, it records the session named on stdin.
cat >"$T/bin/dot" <<'EOF'
session="$(sed -n 's/.*"session_id":"\([^"]*\)".*/\1/p')"
[[ "${STUB_WRITES:-1}" == 1 ]] || exit 0
mkdir -p "$XDG_STATE_HOME/dot/cli/agents/claude"
echo '{}' >"$XDG_STATE_HOME/dot/cli/agents/claude/$session.json"
[[ "${STUB_MS:-0}" == 0 ]] || sleep "0.$(printf '%03d' "$STUB_MS")"
EOF

# bench [VAR=value...] -- ARGS...: the bench under bash 5; sets RC and OUT.
bench() {
  local -a vars=()
  while [[ $# -gt 0 && "$1" != -- ]]; do
    vars+=("$1")
    shift
  done
  shift
  RC=0
  OUT="$(env ${vars[@]+"${vars[@]}"} "$BASH" "$T/tools/ci/hook-bench.sh" "$@" 2>&1)" || RC=$?
}

test_start "a_fast_hook_passes"
bench -- --runs 5 --budget-ms 10000
assert_equals "0" "$RC" "within budget exits 0"
assert_contains "agent hook: 5 events" "$OUT" "it reports how many events it timed"
assert_contains "✓ agent hook within budget" "$OUT" "and says it passed"

test_start "the_runs_and_budget_come_from_the_environment_too"
bench DOT_HOOK_BENCH_RUNS=3 DOT_HOOK_BENCH_BUDGET_MS=10000 --
assert_equals "0|yes" "$RC|$([[ "$OUT" == *"agent hook: 3 events"* ]] && echo yes)" "no arguments: the env sets both"

test_start "a_single_run_is_its_own_median"
bench -- --runs 1 --budget-ms 10000
assert_equals "0" "$RC" "one event exits 0"
assert_true "[[ '$OUT' =~ p50\ [0-9]+ms\ +p95\ [0-9]+ms ]]" "and still yields a p50 and a p95"

test_start "a_slow_hook_fails_the_gate"
bench STUB_MS=60 -- --runs 3 --budget-ms 20
assert_equals "1" "$RC" "over budget exits 1"
assert_contains "::error::agent hook p95" "$OUT" "with a CI error naming the p95"
assert_contains "> budget 20ms" "$OUT" "and the budget"

test_start "a_hook_that_writes_nothing_is_not_timed_as_a_pass"
bench STUB_WRITES=0 -- --runs 2 --budget-ms 10000
assert_equals "1" "$RC" "no state file fails the gate"
assert_contains "wrote no state file" "$OUT" "and says why"

test_start "bad_usage_and_old_bash_exit_2"
bench -- --bogus
assert_equals "2" "$RC" "an unknown argument"
RC=0
OUT="$("$BASH" -c 'unset EPOCHREALTIME; . "$0" --runs 1' "$T/tools/ci/hook-bench.sh" 2>&1)" || RC=$?
assert_equals "2" "$RC" "a bash without EPOCHREALTIME"
assert_contains "needs bash 5" "$OUT" "is named"

print_summary
