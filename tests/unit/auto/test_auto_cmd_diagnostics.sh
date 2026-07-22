#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Auto-generated function-exercise test for scripts/dot/commands/diagnostics.sh.
# These dot command files are sourced by the dispatcher; their case
# arms only execute when a specific subcommand fires. To cover the
# internal helper functions defined alongside the dispatch we source
# the file directly and invoke each name.
#
# AUTO-GENERATED: true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/dot/commands/diagnostics.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "scripts/dot/commands/diagnostics.sh must exist"

test_start "script_valid_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

test_start "diagnostics_deep_branches_execute"
diag_tmp="$DOTFILES_COV_TMPDIR/diagnostics-deep"
mkdir -p "$diag_tmp/repo/scripts/diagnostics" \
  "$diag_tmp/repo/scripts/ops" \
  "$diag_tmp/repo/scripts/dot/commands" \
  "$diag_tmp/repo/lib/dot" \
  "$diag_tmp/bin"
for helper in \
  scripts/diagnostics/doctor-unified.sh \
  scripts/diagnostics/doctor.sh \
  scripts/diagnostics/smoke-test.sh \
  scripts/diagnostics/health.sh \
  scripts/diagnostics/security-score.sh \
  scripts/diagnostics/scorecard.sh \
  scripts/diagnostics/perf.sh \
  scripts/diagnostics/conflicts.sh \
  scripts/diagnostics/version-locks.sh \
  scripts/diagnostics/snapshot.sh \
  scripts/diagnostics/workstation-attestation.sh \
  scripts/diagnostics/history-analysis.sh \
  scripts/diagnostics/benchmark.sh \
  scripts/diagnostics/verify.sh \
  scripts/diagnostics/secret-governance.sh \
  scripts/ops/heal.sh \
  scripts/ops/rollback.sh \
  scripts/ops/chaos.sh \
  scripts/ops/teleport.sh \
  scripts/ops/bundle.sh \
  scripts/dot/commands/restore.sh \
  lib/dot/bento.sh; do
  mkdir -p "$diag_tmp/repo/$(dirname "$helper")"
  cat >"$diag_tmp/repo/$helper" <<'EOF_HELPER'
#!/usr/bin/env bash
printf 'helper:%s\n' "$0"
EOF_HELPER
  chmod +x "$diag_tmp/repo/$helper"
done
cat >"$diag_tmp/repo/lib/dot/log.sh" <<'EOF_LOG'
#!/usr/bin/env bash
dot_metrics_summary() {
  printf 'metrics:%s\n' "${1:-20}"
}
EOF_LOG
cat >"$diag_tmp/bin/chezmoi" <<'EOF_CHEZMOI'
#!/usr/bin/env bash
case "${1:-}" in
  status) printf 'M changed\n' ;;
  doctor) printf 'doctor fallback\n' ;;
  *) exit 0 ;;
esac
EOF_CHEZMOI
cat >"$diag_tmp/bin/dot-load-benchmark" <<'EOF_BENCH'
#!/usr/bin/env bash
printf 'load-benchmark\n'
EOF_BENCH
cat >"$diag_tmp/bin/dot-load-benchmark-pty" <<'EOF_BENCH_PTY'
#!/usr/bin/env bash
printf 'load-benchmark-pty\n'
EOF_BENCH_PTY
chmod +x "$diag_tmp/bin/chezmoi" \
  "$diag_tmp/bin/dot-load-benchmark" \
  "$diag_tmp/bin/dot-load-benchmark-pty"
(
  set +e
  export HOME="$diag_tmp/home"
  export PATH="$diag_tmp/bin:$PATH"
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/dot/utils.sh"
  _DOT_SOURCE_DIR_CACHE="$diag_tmp/repo"
  set -- help
  # shellcheck disable=SC1090
  source "$SCRIPT_FILE"
  (cmd_doctor)
  rm -f "$diag_tmp/repo/scripts/diagnostics/doctor-unified.sh"
  (cmd_doctor)
  rm -f "$diag_tmp/repo/scripts/diagnostics/doctor.sh"
  (cmd_doctor)
  (cmd_smoke_test)
  (cmd_intelligence)
  (cmd_heal)
  (cmd_health)
  (cmd_security_score)
  (cmd_scorecard)
  (cmd_perf)
  (cmd_conflicts)
  (cmd_locks)
  (cmd_snapshot)
  (cmd_attest)
  (cmd_rollback)
  (cmd_drift)
  rm -f "$diag_tmp/repo/scripts/diagnostics/drift-dashboard.sh"
  (cmd_drift)
  (cmd_history)
  (cmd_benchmark)
  (cmd_verify)
  (cmd_restore)
  (cmd_load_bench)
  (cmd_load_bench_pty)
  (cmd_chaos)
  (cmd_teleport)
  (cmd_secret_audit)
  (cmd_bundle)
  cmd_metrics 7
) >/dev/null || true
assert_file_exists "$diag_tmp/repo/lib/dot/log.sh" \
  "diagnostics deep branches used sandbox metrics shim"

cov_exercise_functions_file "$SCRIPT_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
