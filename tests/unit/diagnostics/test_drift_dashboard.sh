#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
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

# --json and the four classes are checked by running it, below.

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
  if python3 <<PY; then
import json, sys
d = json.loads('''$json''')
ok = all(isinstance(d[k], int) for k in ("managed_drift", "untracked_source", "orphan_deployed", "stale_source", "total"))
sys.exit(0 if ok else 1)
PY
    assert_exit_code 0 "true"
  else
    echo "Non-integer field in $json" >&2
    assert_exit_code 0 "false"
  fi

  test_start "total_equals_sum_of_classes"
  if python3 <<PY; then
import json, sys
d = json.loads('''$json''')
expected = d["managed_drift"] + d["untracked_source"] + d["orphan_deployed"] + d["stale_source"]
sys.exit(0 if expected == d["total"] else 1)
PY
    assert_exit_code 0 "true"
  else
    echo "Total mismatch in $json" >&2
    assert_exit_code 0 "false"
  fi
fi

# -----------------------------------------------------------------------------
# `dot drift` wiring: command must dispatch to this dashboard
# -----------------------------------------------------------------------------

# `dot drift --json` must reach this dashboard: the same document, with the
# same four classes and their total.
DOT_BIN="$REPO_ROOT/bin/dot"
if command -v chezmoi >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
  test_start "dot_drift_runs_the_dashboard"
  drift_json="$(bash "$DOT_BIN" drift --json 2>/dev/null || true)"
  assert_equals "ok" "$(python3 -c 'import json,sys; d=json.loads(sys.stdin.read()); print("ok" if {"managed_drift","untracked_source","orphan_deployed","stale_source","total"} <= set(d) else "missing keys")' <<<"$drift_json" 2>&1)" \
    "dot drift --json returns the dashboard's document"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
