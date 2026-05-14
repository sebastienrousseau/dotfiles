#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC2155
#
# lint-reusable-pins.sh — fail if any workflow references a reusable
# workflow via a mutable ref (relative path, branch name, tag).
#
# Closes the lint-rule half of #855. Acceptable form for a reusable
# workflow reference:
#
#     uses: sebastienrousseau/dotfiles/.github/workflows/reusable-X.yml@<40-hex-sha>
#
# Rejected forms:
#
#     uses: ./.github/workflows/reusable-X.yml                  # relative path → mutable
#     uses: org/repo/.github/workflows/reusable-X.yml@master    # branch ref → mutable
#     uses: org/repo/.github/workflows/reusable-X.yml@v1        # tag ref → mutable
#
# The full-SHA constraint is what prevents a TOCTOU swap where a
# malicious push to the reusable's branch redirects the calling
# workflow at run time.

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$REPO_ROOT"

WORKFLOWS_DIR=".github/workflows"
fail_count=0
checked_count=0

if [[ ! -d "$WORKFLOWS_DIR" ]]; then
  echo "::error::workflows directory not found at $WORKFLOWS_DIR"
  exit 1
fi

# Walk every .yml under .github/workflows/ and inspect each `uses:`
# line whose target ends with `reusable-*.yml`.
while IFS= read -r workflow; do
  while IFS=: read -r line_no _; do
    line=$(sed -n "${line_no}p" "$workflow")
    # Extract the ref expression after `uses:`.
    # Acceptable: <owner>/<repo>/.github/workflows/reusable-X.yml@<40-hex>
    if echo "$line" | grep -qE '^\s*uses:\s*\./'; then
      echo "::error file=$workflow,line=$line_no::reusable workflow referenced by relative path (mutable). Pin to <owner>/<repo>/.github/workflows/<file>@<40-hex-sha>."
      echo "    $line"
      fail_count=$((fail_count + 1))
      continue
    fi
    if echo "$line" | grep -qE 'reusable-[a-z0-9-]+\.yml@[0-9a-f]{40}\b'; then
      checked_count=$((checked_count + 1))
      continue
    fi
    if echo "$line" | grep -qE 'reusable-[a-z0-9-]+\.yml@'; then
      ref=$(echo "$line" | sed -E 's|.*reusable-[a-z0-9-]+\.yml@([^ #]+).*|\1|')
      echo "::error file=$workflow,line=$line_no::reusable workflow pinned to mutable ref '$ref'. Pin to a 40-hex commit SHA instead."
      echo "    $line"
      fail_count=$((fail_count + 1))
      continue
    fi
  done < <(grep -nE 'reusable-[a-z0-9-]+\.yml' "$workflow" || true)
done < <(find "$WORKFLOWS_DIR" -maxdepth 1 -type f -name '*.yml')

echo "reusable-pin lint: checked $checked_count call site(s), $fail_count failure(s)"

if [[ "$fail_count" -gt 0 ]]; then
  echo ""
  echo "Refresh pinned SHAs with:"
  echo "  git fetch origin master"
  echo "  PIN=\$(git rev-parse origin/master)"
  echo "  # Apply per call site, then verify:"
  echo "  bash scripts/ci/lint-reusable-pins.sh"
  echo ""
  echo "Policy: docs/security/CI_PINNING.md"
  exit 1
fi

exit 0
