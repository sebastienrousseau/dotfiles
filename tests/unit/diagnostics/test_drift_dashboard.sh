#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for scripts/diagnostics/drift-dashboard.sh — the
# consolidated drift surface that powers `dot drift` and the nightly
# drift-detection workflow.
#
# Regression for: GH-875
# Why: ensure the JSON contract and the four-class signal set remain
# stable so the nightly workflow's issue-opening logic doesn't break.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
# shellcheck source=../../framework/assertions.sh
source "$REPO_ROOT/tests/framework/assertions.sh"

DASH="$REPO_ROOT/scripts/diagnostics/drift-dashboard.sh"

# -----------------------------------------------------------------------------
# Structural
# -----------------------------------------------------------------------------

test_start "dashboard_exists"
assert_file_exists "$DASH" "drift-dashboard.sh should exist"

test_start "dashboard_executable_syntax"
assert_exit_code 0 "bash -n '$DASH'"

test_start "dashboard_supports_json"
assert_file_contains "$DASH" -- "--json" "dashboard must accept --json"

test_start "dashboard_covers_four_classes"
# Each class name must appear at least once in the source so the report
# layout stays consistent with the JSON keys.
for token in "managed_drift" "untracked_source" "orphan_deployed" "stale_source"; do
  assert_file_contains "$DASH" "$token" "dashboard must reference $token"
done

# -----------------------------------------------------------------------------
# JSON contract: keys, types, and exit code semantics
# -----------------------------------------------------------------------------

if command -v chezmoi >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
  test_start "json_has_required_keys"
  json="$(bash "$DASH" --json 2>/dev/null || true)"
  required_keys="managed_drift untracked_source orphan_deployed stale_source total"
  for key in $required_keys; do
    if ! python3 -c "import json, sys; sys.exit(0 if '$key' in json.loads(open('/dev/stdin').read()) else 1)" <<<"$json"; then
      echo "Missing key: $key in $json" >&2
      assert_exit_code 0 "false"
      break
    fi
  done
  assert_exit_code 0 "true"

  test_start "json_values_are_integers"
  if python3 <<PY
import json, sys
d = json.loads('''$json''')
ok = all(isinstance(d[k], int) for k in ("managed_drift", "untracked_source", "orphan_deployed", "stale_source", "total"))
sys.exit(0 if ok else 1)
PY
  then
    assert_exit_code 0 "true"
  else
    echo "Non-integer field in $json" >&2
    assert_exit_code 0 "false"
  fi

  test_start "total_equals_sum_of_classes"
  if python3 <<PY
import json, sys
d = json.loads('''$json''')
expected = d["managed_drift"] + d["untracked_source"] + d["orphan_deployed"] + d["stale_source"]
sys.exit(0 if expected == d["total"] else 1)
PY
  then
    assert_exit_code 0 "true"
  else
    echo "Total mismatch in $json" >&2
    assert_exit_code 0 "false"
  fi
fi

# -----------------------------------------------------------------------------
# `dot drift` wiring: command must dispatch to this dashboard
# -----------------------------------------------------------------------------

DOT_BIN="$REPO_ROOT/bin/dot"
test_start "dot_drift_dispatches_to_dashboard"
if [[ -f "$DOT_BIN" ]] && grep -Fq 'drift|diagnostics' "$DOT_BIN"; then
  assert_exit_code 0 "true"
else
  assert_exit_code 0 "false  # dot CLI must route 'drift' to the diagnostics command group"
fi

DIAG="$REPO_ROOT/scripts/dot/commands/diagnostics.sh"
test_start "diagnostics_invokes_drift_dashboard"
if [[ -f "$DIAG" ]] && grep -Fq "drift-dashboard.sh" "$DIAG"; then
  assert_exit_code 0 "true"
else
  assert_exit_code 0 "false  # diagnostics command group must call drift-dashboard.sh"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
