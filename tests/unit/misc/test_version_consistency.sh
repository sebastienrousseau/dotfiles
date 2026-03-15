#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Tests for version string consistency across the repository
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

# Get the canonical version from .chezmoidata.toml
CANONICAL_VERSION="$(grep '^dotfiles_version' "$REPO_ROOT/.chezmoidata.toml" | sed 's/.*= *"\(.*\)"/\1/')"

test_start "canonical_version_exists"
if [[ -n "$CANONICAL_VERSION" ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: canonical version is $CANONICAL_VERSION"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: could not read version from .chezmoidata.toml"
fi

test_start "bento_version_matches"
local_file="$REPO_ROOT/scripts/dot/lib/bento.sh"
if [[ -f "$local_file" ]]; then
  if grep -q "v${CANONICAL_VERSION}" "$local_file"; then
    ((TESTS_PASSED++))
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: bento.sh has v${CANONICAL_VERSION}"
  else
    ((TESTS_FAILED++))
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: bento.sh version mismatch"
  fi
else
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: bento.sh not present (skipped)"
fi

test_start "pre_commit_audit_version_matches"
local_file="$REPO_ROOT/scripts/git-hooks/pre-commit-audit.sh"
if [[ -f "$local_file" ]]; then
  if grep -q "v${CANONICAL_VERSION}" "$local_file"; then
    ((TESTS_PASSED++))
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: pre-commit-audit.sh has v${CANONICAL_VERSION}"
  else
    ((TESTS_FAILED++))
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: pre-commit-audit.sh version mismatch"
  fi
else
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: pre-commit-audit.sh not present (skipped)"
fi

test_start "no_stale_versions_in_scripts"
# Check that no non-template .sh files have stale version strings
# Look for version strings that look like they should be the current version
# but are off by a few patches (within the same minor version)
patch="$(echo "$CANONICAL_VERSION" | grep -o '[0-9]*$')"
if [[ "$patch" -gt 5 ]]; then
  # Build a pattern for recent-but-stale patches (current-5 to current-1)
  low=$((patch - 5))
  high=$((patch - 1))
  stale_pattern="v0\\.2\\.($low"
  for i in $(seq $((low + 1)) "$high"); do
    stale_pattern+="|$i"
  done
  stale_pattern+=")"
  stale_count="$(grep -rEn "$stale_pattern" "$REPO_ROOT/scripts/" "$REPO_ROOT/.chezmoitemplates/" \
    --include='*.sh' --include='*.md' 2>/dev/null \
    | grep -v CHANGELOG \
    | grep -v 'archive/' \
    | grep -v 'example' \
    | grep -v 'Usage:' \
    | grep -v 'dot restore' \
    | wc -l)"
  if [[ "$stale_count" -eq 0 ]]; then
    ((TESTS_PASSED++))
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no stale version strings found"
  else
    ((TESTS_FAILED++))
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: found $stale_count stale version references"
  fi
else
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: patch too low for meaningful stale check"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
