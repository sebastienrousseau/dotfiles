#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

test_start "consumer_smoke_is_not_a_native_integration_test"
if [[ -f "$REPO_ROOT/tests/consumer/test_npx_clean_container.sh" && ! -e "$REPO_ROOT/tests/integration/test_npx_clean_container.sh" ]]; then
  ((TESTS_PASSED++)) || true
else
  ((TESTS_FAILED++)) || true
fi

test_start "consumer_smoke_keeps_its_explicit_ci_gate"
if grep -qF 'run: bash tests/consumer/test_npx_clean_container.sh 0.2.522' "$REPO_ROOT/.github/workflows/core-contracts.yml"; then
  ((TESTS_PASSED++)) || true
else
  ((TESTS_FAILED++)) || true
fi

test_start "consumer_smoke_shell_syntax"
if bash -n "$REPO_ROOT/tests/consumer/test_npx_clean_container.sh"; then
  ((TESTS_PASSED++)) || true
else
  ((TESTS_FAILED++)) || true
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" == 0 ]]
