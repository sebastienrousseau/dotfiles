#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural coverage for scripts/dot/commands/diagnostics.sh — the `dot`
# diagnostics dispatcher. Every arm hands off with `exec bash <script>`,
# `exec chezmoi …` or `command dot-load-benchmark`, so the suite puts a
# recording stub for each of those first on PATH and asserts *what the
# dispatcher handed off to*. The dispatcher itself is started through an
# absolute bash path so the stub only ever catches the hand-off.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

DIAG="$REPO_ROOT/scripts/dot/commands/diagnostics.sh"
REAL_BASH="$(command -v bash)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

BIN="$DOTFILES_COV_TMPDIR/bin"
OUTF="$DOTFILES_COV_TMPDIR/out.txt"
export DISPATCH_LOG="$DOTFILES_COV_TMPDIR/dispatch.log"

# The stub's own shebang must name the real bash by absolute path: a
# `#!/usr/bin/env bash` shebang would resolve back through PATH to the stub
# itself and fork-bomb.
cat >"$BIN/bash" <<STUB
#!$REAL_BASH
printf '%s\n' "\$*" >>"\$DISPATCH_LOG"
exit 0
STUB
cat >"$BIN/dot-load-benchmark" <<STUB
#!$REAL_BASH
printf 'dot-load-benchmark %s\n' "\$*" >>"\$DISPATCH_LOG"
exit 0
STUB
cat >"$BIN/dot-load-benchmark-pty" <<STUB
#!$REAL_BASH
printf 'dot-load-benchmark-pty %s\n' "\$*" >>"\$DISPATCH_LOG"
exit 0
STUB
cat >"$BIN/chezmoi" <<STUB
#!$REAL_BASH
printf 'chezmoi %s\n' "\$*" >>"\$DISPATCH_LOG"
exit 0
STUB
chmod +x "$BIN/bash" "$BIN/dot-load-benchmark" "$BIN/dot-load-benchmark-pty" "$BIN/chezmoi"

# diag <args…> — run the dispatcher via the real bash, capture stdout+status.
diag() {
  : >"$DISPATCH_LOG"
  "$REAL_BASH" "$DIAG" "$@" >"$OUTF" </dev/null
  RC=$?
  return 0
}
out_has() { assert_file_contains "$OUTF" "$1" "${2:-output contains $1}"; }
# handed_to <needle> — assert the dispatcher exec'd the expected target.
handed_to() { assert_file_contains "$DISPATCH_LOG" "$1" "hands off to $1"; }

test_start "script_exists_and_parses"
assert_file_exists "$DIAG" "diagnostics.sh must exist"
assert_true "bash -n '$DIAG'" "valid bash syntax"

test_start "help_lists_the_commands"
diag --help
assert_equals 0 "$RC" "rc"
out_has "Usage: diagnostics.sh" "usage"
out_has "doctor, heal, health" "command list"

test_start "no_command_prints_usage_and_fails"
diag
assert_equals 1 "$RC" "rc"
out_has "Usage: diagnostics.sh" "usage"

test_start "unknown_command_fails"
diag definitely-not-a-command
assert_equals 1 "$RC" "rc"

test_start "doctor_prefers_the_unified_doctor"
diag doctor --json
assert_equals 0 "$RC" "rc"
handed_to "scripts/diagnostics/doctor-unified.sh --json"

test_start "drift_hands_off_to_the_drift_dashboard"
diag drift --json
assert_equals 0 "$RC" "rc"
handed_to "scripts/diagnostics/drift-dashboard.sh --json"

# Each remaining arm is a one-line `run_script` hand-off; assert the pairing
# of subcommand to target script (and that arguments are forwarded).
run_script_case() {
  local sub="$1" target="$2"
  test_start "${sub//-/_}_hands_off_to_${target##*/}"
  diag "$sub" --flag-forwarded
  assert_equals 0 "$RC" "rc"
  handed_to "$target --flag-forwarded"
}

run_script_case heal scripts/ops/heal.sh
run_script_case health scripts/diagnostics/health.sh
run_script_case health-check scripts/diagnostics/health.sh
run_script_case security-score scripts/diagnostics/security-score.sh
run_script_case scorecard scripts/diagnostics/scorecard.sh
run_script_case score scripts/diagnostics/scorecard.sh
run_script_case perf scripts/diagnostics/perf.sh
run_script_case conflicts scripts/diagnostics/conflicts.sh
run_script_case locks scripts/diagnostics/version-locks.sh
run_script_case snapshot scripts/diagnostics/snapshot.sh
run_script_case attest scripts/diagnostics/workstation-attestation.sh
run_script_case attestation scripts/diagnostics/workstation-attestation.sh
run_script_case rollback scripts/ops/rollback.sh
run_script_case history scripts/diagnostics/history-analysis.sh
run_script_case benchmark scripts/diagnostics/benchmark.sh
run_script_case verify scripts/diagnostics/verify.sh
run_script_case restore scripts/dot/commands/restore.sh
run_script_case chaos scripts/ops/chaos.sh
run_script_case teleport scripts/ops/teleport.sh
run_script_case secret-audit scripts/diagnostics/secret-governance.sh
run_script_case bundle scripts/ops/bundle.sh
run_script_case smoke-test scripts/diagnostics/smoke-test.sh
run_script_case intelligence lib/dot/bento.sh

test_start "load_bench_calls_the_deployed_binary"
diag load-bench --quick
assert_equals 0 "$RC" "rc"
handed_to "dot-load-benchmark --quick"

test_start "load_bench_pty_calls_the_pty_binary"
diag load-bench-pty --quick
assert_equals 0 "$RC" "rc"
handed_to "dot-load-benchmark-pty --quick"

test_start "metrics_reports_from_the_local_log"
METRICS="$XDG_STATE_HOME/dotfiles/metrics.jsonl"
mkdir -p "$(dirname "$METRICS")"
printf '{"metric":"shell_startup_mean","value":42,"unit":"ms"}\n' >"$METRICS"
diag metrics 5
assert_equals 0 "$RC" "rc"
out_has "Recent Metrics" "header"
out_has "shell_startup_mean" "metric row"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
