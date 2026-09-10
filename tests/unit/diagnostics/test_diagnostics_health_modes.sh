#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# The --json and --fix modes of scripts/diagnostics/health.sh.
#
# JSON mode makes every header and section a no-op, and the auto-remediation
# block only reports anything when heal.sh is missing — a state the checkout
# never has. Neither had run. The second is staged with a fixture tree that
# carries health.sh but no ops/ directory, so the missing-heal arm is taken
# without any repair actually running.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

HEALTH="$REPO_ROOT/scripts/diagnostics/health.sh"

cov_setup_sandbox
trap cov_teardown_sandbox EXIT

# ── 1. JSON mode ───────────────────────────────────────────────────────────
test_start "health_json_mode_emits_a_document"
HJ_RC=0
HJ_OUT="$(NO_COLOR=1 "${BASH:-bash}" "$HEALTH" --json 2>/dev/null </dev/null)" || HJ_RC=$?
assert_equals "0" "$HJ_RC" "--json should exit 0"
assert_contains '"check"' "$HJ_OUT" "the document should carry per-check records"

test_start "health_json_mode_prints_no_prose"
assert_false "[[ \"\$HJ_OUT\" == *'Dotfiles Health'* ]]" \
  "JSON mode should suppress the human-readable headers entirely"

# ── 2. Auto-remediation with no heal.sh to run ─────────────────────────────
#
# Not removed on exit: the aggregator resolves the symlinked script after the
# whole sweep, and a deleted fixture would resolve to nothing.
FX="${TMPDIR:-/tmp}"
FX="${FX%/}/dot-cov-fixtures/health-modes"
rm -rf "$FX"
mkdir -p "$FX/scripts/diagnostics"
ln -s "$REPO_ROOT/lib" "$FX/lib"
ln -s "$REPO_ROOT/defaults" "$FX/defaults"
ln -s "$HEALTH" "$FX/scripts/diagnostics/health.sh"

test_start "health_fix_reports_a_missing_heal_script"
HF_RC=0
HF_OUT="$(
  cd "$FX" &&
    NO_COLOR=1 "${BASH:-bash}" scripts/diagnostics/health.sh --fix 2>&1 </dev/null
)" || HF_RC=$?
assert_contains "heal.sh not found" "$HF_OUT" \
  "a missing heal.sh should be reported rather than silently skipped"
assert_contains "Auto-Remediation" "$HF_OUT" \
  "the remediation section should still be announced"

print_summary
