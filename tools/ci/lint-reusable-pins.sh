#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# Validate reusable-workflow references.
#
# Same-repository reusable workflows MUST use the local form so GitHub loads
# the workflow from the exact commit/ref under test:
#
#   uses: ./.github/workflows/reusable-shell-lint.yml
#
# Referring to this repository through owner/repo@SHA is immutable, but it is
# the wrong isolation boundary for pull requests: a PR that changes a reusable
# workflow would continue executing the older pinned implementation. External
# reusable workflows retain the normal full-commit-SHA requirement.

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
REPOSITORY="${GITHUB_REPOSITORY:-sebastienrousseau/dotfiles}"
WORKFLOWS_DIR="$REPO_ROOT/.github/workflows"
fail_count=0
checked_count=0

if [[ ! -d "$WORKFLOWS_DIR" ]]; then
  echo "::error::workflows directory not found at $WORKFLOWS_DIR"
  exit 1
fi

while IFS= read -r workflow; do
  while IFS=: read -r line_no line; do
    target="${line#*uses:}"
    target="${target%%#*}"
    target="$(printf '%s' "$target" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"

    case "$target" in
      ./.github/workflows/*.yml | ./.github/workflows/*.yaml)
        checked_count=$((checked_count + 1))
        ;;
      slsa-framework/slsa-github-generator/.github/workflows/generator_generic_slsa3.yml@v2.1.0)
        # The upstream SLSA bootstrap requires a semver tag and rejects a
        # commit-SHA caller. Keep this exception exact and pair it with the
        # release-signing contract test that records the reviewed version.
        checked_count=$((checked_count + 1))
        ;;
      "$REPOSITORY"/.github/workflows/*)
        echo "::error file=$workflow,line=$line_no::same-repository reusable workflow must use ./.github/workflows/<file> so the caller executes the workflow from the commit under test."
        echo "    $line"
        fail_count=$((fail_count + 1))
        ;;
      */.github/workflows/*)
        ref="${target##*@}"
        if [[ "$target" == *@* ]] && [[ "$ref" =~ ^[0-9a-f]{40}$ ]]; then
          checked_count=$((checked_count + 1))
        else
          echo "::error file=$workflow,line=$line_no::external reusable workflow must be pinned to a full 40-hex commit SHA."
          echo "    $line"
          fail_count=$((fail_count + 1))
        fi
        ;;
    esac
  done < <(grep -nE '^[[:space:]]*uses:[[:space:]]*[^#]+/\.github/workflows/' "$workflow" || true)
done < <(find "$WORKFLOWS_DIR" -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) -print)

echo "reusable-reference lint: checked $checked_count call site(s), $fail_count failure(s)"
exit "$fail_count"
