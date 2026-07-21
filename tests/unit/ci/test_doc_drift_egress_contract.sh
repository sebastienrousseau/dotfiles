#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Regression for: dc024903
# Why: doc-drift jobs are intentionally isolated. Keep their harden-runner
# egress policy in block mode so local-generator checks cannot gain surprise
# outbound network access.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORKFLOW="$REPO_ROOT/.github/workflows/doc-drift.yml"
HARDEN_RUNNER_SHA="bf7454d06d71f1098171f2acdf0cd4708d7b5920"

test_start "doc_drift_workflow_exists"
assert_file_exists "$WORKFLOW" "doc-drift workflow must exist"

test_start "doc_drift_harden_runner_pinned"
assert_file_contains "$WORKFLOW" "step-security/harden-runner@$HARDEN_RUNNER_SHA" \
  "doc-drift harden-runner action must stay pinned to a full commit SHA"

test_start "doc_drift_all_jobs_block_egress"
harden_steps="$(grep -c 'step-security/harden-runner@' "$WORKFLOW" || true)"
block_policies="$(grep -c 'egress-policy: block' "$WORKFLOW" || true)"
assert_equals "$harden_steps" "$block_policies" \
  "every doc-drift harden-runner step must use egress-policy: block"

test_start "doc_drift_expected_job_count"
assert_equals "2" "$harden_steps" "doc-drift currently has two isolated generator jobs"

test_start "doc_drift_no_wildcard_egress"
if grep -Eq '(^|[[:space:]])(\*|0\.0\.0\.0/0|::/0)([[:space:]]|$)' "$WORKFLOW"; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: wildcard egress is not allowed"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
fi

test_start "doc_drift_checkout_endpoints_allowed"
for endpoint in \
  "github.com:443" \
  "api.github.com:443" \
  "codeload.github.com:443" \
  "objects.githubusercontent.com:443" \
  "release-assets.githubusercontent.com:443"; do
  assert_file_contains "$WORKFLOW" "$endpoint" "doc-drift allowlist includes $endpoint"
done

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
