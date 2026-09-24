#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Runs the Python unit tests for the local AI gateway (dot-ai-serve):
# token file lifecycle, config parsing, request shaping, engine failure
# modes, HTTP routes and main(). See dot_ai_serve_units.py.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 not installed"
  echo "RESULTS:0:0:0"
  exit 0
fi

test_start "dot_ai_serve_python_units"
out="$(cd "$REPO_ROOT" && python3 "$SCRIPT_DIR/dot_ai_serve_units.py" 2>&1)"
rc=$?
if [[ "$rc" -eq 0 ]]; then
  assert_exit_code 0 "true"
else
  printf '%s\n' "$out" | tail -30
  assert_exit_code 0 "false  # python unit tests failed (rc=$rc)"
fi

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
