#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

ALIASES_DIR="$REPO_ROOT/.chezmoitemplates/aliases/modern"

test_start "alias_dir_exists"
assert_dir_exists "$ALIASES_DIR" "aliases directory should exist"

test_start "alias_files_valid"
invalid=0
shopt -s nullglob
for f in "$ALIASES_DIR"/*.sh; do
  [[ -f "$f" ]] && ! bash -n "$f" 2>/dev/null && ((invalid++))
done
if [[ "$invalid" -eq 0 ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: all valid"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $invalid invalid"
fi

test_start "alias_no_hardcoded_paths"
if grep -rqE '"/home/[a-z]+' "$ALIASES_DIR" 2>/dev/null; then
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
else
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
fi

test_start "alias_modern_tooling_coverage"
MODERN_FILE="$ALIASES_DIR/modern.aliases.sh"
assert_file_contains "$MODERN_FILE" "alias ms='mise'" "modern aliases include mise"
assert_file_contains "$MODERN_FILE" "alias nx='nix'" "modern aliases include nix"
assert_file_contains "$MODERN_FILE" "alias j='just'" "modern aliases include just"
assert_file_contains "$MODERN_FILE" "alias zz='zoxide'" "modern aliases include zoxide"
assert_file_contains "$MODERN_FILE" "alias de='direnv'" "modern aliases include direnv"
assert_file_contains "$MODERN_FILE" "alias ghpr='gh pr view --web'" "modern aliases include gh"
assert_file_contains "$MODERN_FILE" "alias p='podman'" "modern aliases include podman"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
