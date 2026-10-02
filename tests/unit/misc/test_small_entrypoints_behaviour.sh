#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1091
# Small entry points whose only coverage came from exercise runs that
# asserted nothing: the zsh completion script, dot-load-benchmark's option
# handling, the git pre-commit wrapper and the WSL contract runner. Each
# is run and its outcome checked.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d -t dot-entrypoints.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# run <cmd…> — capture combined output in OUT and the exit code in RC.
run() {
  RC=0
  OUT="$("$@" 2>&1)" || RC=$?
}

# ── dot_completion ────────────────────────────────────────────────────────
COMPLETION="$REPO_ROOT/defaults/dot_local/bin/executable_dot_completion"
test_start "completion_help"
run bash "$COMPLETION" --help
assert_equals "0" "$RC" "--help exits 0"
assert_contains "Usage: dot_completion" "$OUT" "prints its usage"

test_start "completion_lists_commands_without_compsys"
# Outside zsh's completion system there is no _describe: the script prints
# the command table instead.
run bash "$COMPLETION"
assert_equals "0" "$RC" "exits 0"
assert_contains "apply:Apply dotfiles (chezmoi apply)" "$OUT" "lists apply"
assert_contains "help:Show this help message" "$OUT" "lists help"

# ── dot-load-benchmark options ────────────────────────────────────────────
BENCH="$REPO_ROOT/defaults/dot_local/bin/executable_dot-load-benchmark"
test_start "load_benchmark_help"
run bash "$BENCH" --help
assert_equals "0" "$RC" "--help exits 0"
assert_contains "Usage: dot-load-benchmark [runs]" "$OUT" "prints its usage"

test_start "load_benchmark_rejects_an_unknown_option"
run bash "$BENCH" --bogus
assert_equals "2" "$RC" "an unknown option exits 2"
assert_contains "Unknown option: --bogus" "$OUT" "and is named"

test_start "load_benchmark_rejects_a_bad_run_count"
run bash "$BENCH" 0
assert_equals "2" "$RC" "zero runs exits 2"
assert_contains "Invalid runs value: 0" "$OUT" "and says why"

# ── git pre-commit wrapper ────────────────────────────────────────────────
# A tree with a copy of the hook and recording stubs for the two scripts it
# runs: the hook finds them relative to its own location. (Line coverage
# does not credit a run of a copy; the behaviour is what is pinned here.)
HOOKTREE="$WORK/hooktree"
mkdir -p "$HOOKTREE/scripts/git-hooks" "$HOOKTREE/scripts/diagnostics"
cp "$REPO_ROOT/scripts/git-hooks/pre-commit" "$HOOKTREE/scripts/git-hooks/pre-commit"
for s in diagnostics/secret-governance.sh git-hooks/pre-commit-audit.sh; do
  printf '#!/usr/bin/env bash\necho "ran %s"\nexit "${STUB_RC:-0}"\n' "$s" >"$HOOKTREE/scripts/$s"
  chmod +x "$HOOKTREE/scripts/$s"
done

test_start "precommit_runs_both_checks"
run bash "$HOOKTREE/scripts/git-hooks/pre-commit"
assert_equals "0" "$RC" "both checks pass, the hook passes"
assert_contains "ran diagnostics/secret-governance.sh" "$OUT" "the secret check ran"
assert_contains "ran git-hooks/pre-commit-audit.sh" "$OUT" "the audit ran"

test_start "precommit_fails_when_a_check_fails"
STUB_RC=1 run bash "$HOOKTREE/scripts/git-hooks/pre-commit"
assert_not_equals "0" "$RC" "a failing check fails the commit"

test_start "precommit_skips_checks_that_are_absent"
rm -f "$HOOKTREE/scripts/diagnostics/secret-governance.sh"
run bash "$HOOKTREE/scripts/git-hooks/pre-commit"
assert_equals "0" "$RC" "a missing check is skipped"
assert_contains "ran git-hooks/pre-commit-audit.sh" "$OUT" "the other still runs"

# ── WSL contract runner ───────────────────────────────────────────────────
WSLTREE="$WORK/wsltree"
mkdir -p "$WSLTREE/scripts/qa" "$WSLTREE/tests/unit/install" "$WSLTREE/tests/unit/functions"
cp "$REPO_ROOT/scripts/qa/wsl-contract.sh" "$WSLTREE/scripts/qa/wsl-contract.sh"
for t in install/test_os_detection_comprehensive.sh functions/test_platform_detection_behavior.sh; do
  printf 'echo "suite %s"\nexit "${STUB_RC:-0}"\n' "$t" >"$WSLTREE/tests/unit/$t"
done

test_start "wsl_contract_runs_both_suites"
run bash "$WSLTREE/scripts/qa/wsl-contract.sh"
assert_equals "0" "$RC" "both suites pass, the contract passes"
assert_contains "suite install/test_os_detection_comprehensive.sh" "$OUT" "OS detection ran"
assert_contains "suite functions/test_platform_detection_behavior.sh" "$OUT" "platform detection ran"

test_start "wsl_contract_fails_when_a_suite_fails"
STUB_RC=1 run bash "$WSLTREE/scripts/qa/wsl-contract.sh"
assert_not_equals "0" "$RC" "a failing suite fails the contract"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
