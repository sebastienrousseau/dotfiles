#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# test-kind: structural
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for Wave 1: CI chezmoi version pinning
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

CI_FILE="$REPO_ROOT/.github/workflows/ci.yml"

echo "Testing Wave 1: CI chezmoi version pinning..."

test_start "ci_yml_exists"
assert_file_exists "$CI_FILE" "ci.yml should exist"

test_start "ci_chezmoi_version_env"
assert_file_contains "$CI_FILE" "CHEZMOI_VERSION:" "should define CHEZMOI_VERSION env variable"

test_start "ci_chezmoi_version_pinned"
# Verify the version is a proper semver (not 'latest')
if grep -q 'CHEZMOI_VERSION:.*"[0-9]' "$CI_FILE"; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: CHEZMOI_VERSION is pinned to a semver"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: CHEZMOI_VERSION should be pinned to a semver"
fi

test_start "ci_chezmoi_not_latest"
if grep -q 'CHEZMOI_VERSION.*latest' "$CI_FILE" 2>/dev/null; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: CHEZMOI_VERSION should not be 'latest'"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: CHEZMOI_VERSION is not 'latest'"
fi

test_start "ci_chezmoi_uses_tag_flag"
# get.chezmoi.io uses -t flag, not -v
if grep -q 'get.chezmoi.io.*-v ' "$CI_FILE" 2>/dev/null; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: get.chezmoi.io should use -t flag, not -v"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: get.chezmoi.io does not use incorrect -v flag"
fi

test_start "ci_chezmoi_installer_uses_env_version"
# CI should install chezmoi with the pinned CHEZMOI_VERSION env variable.
# ci.yml now delegates to the setup-chezmoi composite action, which
# falls back to $CHEZMOI_VERSION when no `version:` input is supplied.
# So accept two acceptable wirings: either the legacy inline call to
# install-chezmoi-verified.sh referencing CHEZMOI_VERSION, OR the
# current shape where ci.yml exports CHEZMOI_VERSION at workflow scope
# AND uses the setup-chezmoi action that reads it.
ACTION_FILE="$REPO_ROOT/.github/actions/setup-chezmoi/action.yml"
if grep -q 'install-chezmoi-verified.sh.*CHEZMOI_VERSION' "$CI_FILE"; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: install script uses pinned CHEZMOI_VERSION env variable (legacy inline)"
elif grep -q '^  CHEZMOI_VERSION:' "$CI_FILE" \
  && grep -q 'setup-chezmoi' "$CI_FILE" \
  && grep -q 'install-chezmoi-verified.sh' "$ACTION_FILE" 2>/dev/null \
  && grep -q 'CHEZMOI_VERSION' "$ACTION_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: install script uses pinned CHEZMOI_VERSION env variable (via setup-chezmoi composite)"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: install script should use pinned CHEZMOI_VERSION env variable"
fi

# Every workflow that uses setup-chezmoi must give it a version: the action
# exits when neither its `version:` input nor $CHEZMOI_VERSION is set, so a
# workflow that supplies neither fails at setup on every run.
# step_has_version FILE: 0 when each setup-chezmoi step in FILE has a
# non-empty `version:` input before the next step starts.
step_has_version() {
  awk '
    /uses: *\.\/\.github\/actions\/setup-chezmoi/ {
      if (open && !found) bad = 1
      open = 1; found = 0; match($0, /[^ ]/); indent = RSTART; next
    }
    open && /^ *- / { match($0, /[^ ]/); if (RSTART <= indent) { if (!found) bad = 1; open = 0 } }
    open && /^ *[a-z_-]+:/ { match($0, /[^ ]/); if (RSTART < indent) { if (!found) bad = 1; open = 0 } }
    open && /^ +version: *["'\'']?[0-9]/ { found = 1 }
    END { if (open && !found) bad = 1; exit bad }
  ' "$1"
}

test_start "every_setup_chezmoi_user_supplies_a_version"
missing=""
for wf in "$REPO_ROOT"/.github/workflows/*.yml; do
  grep -q 'uses: *\./\.github/actions/setup-chezmoi' "$wf" || continue
  grep -Eq '^ +CHEZMOI_VERSION: *"?[0-9]' "$wf" && continue
  step_has_version "$wf" || missing+=" ${wf##*/}"
done
if [[ -z "$missing" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: no CHEZMOI_VERSION or version: input in:$missing"
fi

echo ""
echo "Wave 1 CI pinning tests completed."
print_summary
