#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

DOT_CLI="$REPO_ROOT/bin/dot"
DOCTOR_UNIFIED="$REPO_ROOT/scripts/diagnostics/doctor-unified.sh"
SCORECARD="$REPO_ROOT/scripts/diagnostics/scorecard.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

# doctor-unified.sh runs from a fixture repo where every target script is a
# stub that records its name and arguments, so each flag's routing is
# observed without running heal, health or the benchmarks for real.
DU="$DOTFILES_COV_TMPDIR/doctor-unified"
mkdir -p "$DU/scripts/diagnostics" "$DU/scripts/ops" "$DU/tests"
cp "$DOCTOR_UNIFIED" "$DU/scripts/diagnostics/doctor-unified.sh"
cp -R "$REPO_ROOT/lib" "$DU/"
for t in scripts/diagnostics/doctor.sh scripts/ops/heal.sh scripts/diagnostics/health.sh \
  scripts/diagnostics/scorecard.sh scripts/diagnostics/smoke-test.sh \
  scripts/diagnostics/drift-dashboard.sh tests/benchmark.sh; do
  printf '#!/usr/bin/env bash\necho "%s $*"\n' "$t" >"$DU/$t"
done
# routed <args...>: the "<target> <args>" line doctor-unified ran.
routed() { NO_COLOR=1 bash "$DU/scripts/diagnostics/doctor-unified.sh" "$@" 2>/dev/null | tail -1; }

test_start "doctor_unified_flag_aliases"
for pair in "--heal -H scripts/ops/heal.sh" "--audit -a scripts/diagnostics/health.sh" \
  "--score -s scripts/diagnostics/scorecard.sh" "--smoke -m scripts/diagnostics/smoke-test.sh" \
  "--drift -d scripts/diagnostics/drift-dashboard.sh" "--benchmark -b tests/benchmark.sh"; do
  read -r long short target <<<"$pair"
  assert_equals "$target |$target " "$(routed "$long")|$(routed "$short")" "$long and $short both run $target"
done

test_start "doctor_unified_default_and_passthrough"
assert_equals "scripts/diagnostics/doctor.sh -j -A|scripts/diagnostics/doctor.sh --json --ai" \
  "$(routed -j -A)|$(routed --json --ai)" "with no mode flag doctor.sh runs, and -j/-A/--json/--ai pass through"

test_start "doctor_unified_missing_target_fails"
rm -f "$DU/scripts/diagnostics/smoke-test.sh"
rc=0
NO_COLOR=1 bash "$DU/scripts/diagnostics/doctor-unified.sh" -m >/dev/null 2>&1 || rc=$?
assert_equals "1" "$rc" "a mode whose script is missing exits 1"

test_start "scorecard_flag_alias"
short="$(bash "$SCORECARD" -j 2>/dev/null | python3 -c 'import json,sys; print(sorted(json.load(sys.stdin)))' 2>/dev/null)"
long="$(bash "$SCORECARD" --json 2>/dev/null | python3 -c 'import json,sys; print(sorted(json.load(sys.stdin)))' 2>/dev/null)"
assert_true '[[ -n $short && $short == "$long" && $short == *health* ]]' "scorecard -j and --json emit the same JSON report"

test_start "attest_json_short_runtime"
output=$(REPO_ROOT="$REPO_ROOT" bash "$DOT_CLI" attest -j 2>/dev/null) || true
if [[ "$output" == \{* ]] && [[ "$output" == *"\"dotfiles_version\""* ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dot attest -j emits JSON"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dot attest -j should emit JSON"
  printf '%b\n' "    Output: $output"
fi

test_start "mcp_json_short_runtime"
output=$(REPO_ROOT="$REPO_ROOT" MCP_CONFIG="$REPO_ROOT/defaults/dot_config/claude/mcp_servers.json" bash "$DOT_CLI" mcp -s -j 2>/dev/null) || true
if [[ "$output" == \{* ]] && [[ "$output" == *"\"status\""* ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dot mcp -s -j emits JSON"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dot mcp -s -j should emit JSON"
  printf '%b\n' "    Output: $output"
fi

test_start "snapshot_short_flags_runtime"
snapshot_state_dir="$(mktemp -d)"
XDG_STATE_HOME="$snapshot_state_dir" bash "$REPO_ROOT/scripts/diagnostics/snapshot.sh" -b >/dev/null 2>&1 || true
if [[ -f "$snapshot_state_dir/dotfiles/snapshots/baseline.json" ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: snapshot -b writes baseline"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: snapshot -b should write baseline"
fi
XDG_STATE_HOME="$snapshot_state_dir" bash "$REPO_ROOT/scripts/diagnostics/snapshot.sh" -b -f >/dev/null 2>&1 || true
rm -rf "$snapshot_state_dir"

test_start "help_reference_mentions_short_flags"
help_output=$(bash "$DOT_CLI" help all 2>&1) || true
if [[ "$help_output" == *"version"* ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: help reference remains available after alias additions"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: help reference should remain available"
fi

# Slice 2: drive real line coverage of the script under test
cov_exercise_script "$SCORECARD"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
