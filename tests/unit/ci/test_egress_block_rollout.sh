#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Regression for: egress-block rollout after doc-drift validation.
# Keep low-risk local verification workflows in block mode once their
# network shape is known.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

HARDEN_RUNNER_SHA="bf7454d06d71f1098171f2acdf0cd4708d7b5920"
CHECKOUT_ENDPOINTS=(
  "github.com:443"
  "api.github.com:443"
  "codeload.github.com:443"
  "objects.githubusercontent.com:443"
  "release-assets.githubusercontent.com:443"
)
BLOCKED_WORKFLOWS=(
  ".github/workflows/dco.yml"
  ".github/workflows/doc-drift.yml"
  ".github/workflows/pr-signature.yml"
  ".github/workflows/reusable-security-baseline.yml"
  ".github/workflows/verify-tag-signature.yml"
)
CHECKOUT_WORKFLOWS=(
  ".github/workflows/dco.yml"
  ".github/workflows/doc-drift.yml"
  ".github/workflows/reusable-security-baseline.yml"
  ".github/workflows/verify-tag-signature.yml"
)

test_start "egress_block_workflows_use_pinned_harden_runner"
for rel in "${BLOCKED_WORKFLOWS[@]}"; do
  assert_file_contains "$REPO_ROOT/$rel" "step-security/harden-runner@$HARDEN_RUNNER_SHA" \
    "$rel pins harden-runner"
done

test_start "egress_block_workflows_do_not_use_audit_mode"
for rel in "${BLOCKED_WORKFLOWS[@]}"; do
  if grep -q 'egress-policy: audit' "$REPO_ROOT/$rel"; then
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $rel still uses audit mode"
  else
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $rel has no audit-mode egress policy"
  fi
done

test_start "egress_block_workflows_block_each_harden_step"
for rel in "${BLOCKED_WORKFLOWS[@]}"; do
  workflow="$REPO_ROOT/$rel"
  harden_steps="$(grep -c 'step-security/harden-runner@' "$workflow" || true)"
  block_policies="$(grep -c 'egress-policy: block' "$workflow" || true)"
  assert_equals "$harden_steps" "$block_policies" "$rel blocks every harden-runner step"
done

test_start "egress_block_checkout_workflows_keep_github_allowlist"
for rel in "${CHECKOUT_WORKFLOWS[@]}"; do
  for endpoint in "${CHECKOUT_ENDPOINTS[@]}"; do
    assert_file_contains "$REPO_ROOT/$rel" "$endpoint" "$rel allows $endpoint"
  done
done

test_start "egress_block_rollout_avoids_wildcards"
for rel in "${BLOCKED_WORKFLOWS[@]}"; do
  if grep -Eq '(^|[[:space:]])(\*|0\.0\.0\.0/0|::/0)([[:space:]]|$)' "$REPO_ROOT/$rel"; then
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $rel contains wildcard egress"
  else
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $rel has no wildcard egress"
  fi
done

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
