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

# The harden-runner pin is derived from the workflows, never hardcoded here.
#
# The properties worth protecting are that harden-runner is pinned to a full
# commit SHA rather than a floating tag, and that every block-mode workflow
# agrees on the same one. Naming a specific SHA in this file protected
# neither: it only asserted "still on the release I was written against", so
# every harden-runner bump broke this test until someone edited it by hand.
# That is exactly what stalled the v2.20.1 -> v2.21.0 bump for two days.
harden_runner_refs() {
  grep -oE 'step-security/harden-runner@[^[:space:]]+' "$1" | sed 's|.*@||' | sort -u
}
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

ALL_PINS=""

test_start "egress_block_workflows_use_pinned_harden_runner"
for rel in "${BLOCKED_WORKFLOWS[@]}"; do
  refs="$(harden_runner_refs "$REPO_ROOT/$rel")"
  assert_not_empty "$refs" "$rel references harden-runner"
  while IFS= read -r ref; do
    [[ -n "$ref" ]] || continue
    ALL_PINS="$ALL_PINS$ref
"
    if printf '%s' "$ref" | grep -qE '^[0-9a-f]{40}$'; then
      ((TESTS_PASSED++)) || true
      printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $rel pins harden-runner to a full commit SHA"
    else
      ((TESTS_FAILED++)) || true
      printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $rel pins harden-runner to '$ref', which is not a 40-character commit SHA"
    fi
  done <<EOF
$refs
EOF
done

# A per-file SHA check alone would pass if two workflows pinned different
# releases, which is the state a partial bump leaves behind.
test_start "egress_block_workflows_agree_on_one_harden_runner_pin"
unique_pins="$(printf '%s' "$ALL_PINS" | grep -v '^$' | sort -u)"
unique_count="$(printf '%s\n' "$unique_pins" | grep -c . || true)"
assert_equals "1" "$unique_count" \
  "all block-mode workflows pin the same harden-runner SHA (found: $(printf '%s' "$unique_pins" | tr '\n' ' '))"

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
