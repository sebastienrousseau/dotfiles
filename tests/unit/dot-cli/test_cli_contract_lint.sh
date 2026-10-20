#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Runs the CLI-contract lint tests: tools/ci/check-cli-contract.py passes the
# repository and fails each planted violation. See test_cli_contract_lint.py;
# CI also runs it in the Core and delivery contracts workflow.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

if ! python3 -c 'import jsonschema, tomllib' >/dev/null 2>&1; then
  echo "SKIP: python3 with jsonschema and tomllib (3.11+) not available"
  echo "RESULTS:0:0:0"
  exit 0
fi

test_start "cli_contract_lint_python_units"
out="$(cd "$REPO_ROOT" && python3 "$SCRIPT_DIR/test_cli_contract_lint.py" 2>&1)"
rc=$?
if [[ "$rc" -eq 0 ]]; then
  assert_exit_code 0 "true"
else
  printf '%s\n' "$out" | tail -30
  assert_exit_code 0 "false  # CLI-contract lint tests failed (rc=$rc)"
fi

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
