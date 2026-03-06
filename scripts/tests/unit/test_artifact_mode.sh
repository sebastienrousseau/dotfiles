#!/usr/bin/env bash
# Copyright (c) 2015-2026 . All rights reserved.
# Unit tests for Artifact-Only mode and hydration logic

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

ZSH_TEMPLATE="$REPO_ROOT/dot_config/zsh/dot_zshrc.tmpl"
FISH_TEMPLATE="$REPO_ROOT/dot_config/fish/conf.d/init.fish.tmpl"

# Test: Zsh template has artifact mode
test_start "zsh_has_artifact_mode"
if grep -q "DOTFILES_ARTIFACT_MODE" "$ZSH_TEMPLATE"; then
  ((TESTS_PASSED++)) || true
  printf "  ${GREEN}✓${NC} $CURRENT_TEST: Zsh template supports Artifact mode\n"
else
  ((TESTS_FAILED++)) || true
  printf "  ${RED}✗${NC} $CURRENT_TEST: Zsh template missing Artifact mode support\n"
fi

# Test: Fish template has artifact mode
test_start "fish_has_artifact_mode"
if grep -q "DOTFILES_ARTIFACT_MODE" "$FISH_TEMPLATE"; then
  ((TESTS_PASSED++)) || true
  printf "  ${GREEN}✓${NC} $CURRENT_TEST: Fish template supports Artifact mode\n"
else
  ((TESTS_FAILED++)) || true
  printf "  ${RED}✗${NC} $CURRENT_TEST: Fish template missing Artifact mode support\n"
fi

# Test: Lazy-Hydration logic present
test_start "lazy_hydration_present"
if grep -q "deferred_hydration" "$ZSH_TEMPLATE" && grep -q "trigger_hydration" "$FISH_TEMPLATE"; then
  ((TESTS_PASSED++)) || true
  printf "  ${GREEN}✓${NC} $CURRENT_TEST: Lazy-Hydration logic present in both shells\n"
else
  ((TESTS_FAILED++)) || true
  printf "  ${RED}✗${NC} $CURRENT_TEST: Lazy-Hydration logic missing\n"
fi

# Test: Redraw signal logic present
test_start "redraw_signal_present"
if grep -q "kill -WINCH" "$ZSH_TEMPLATE" && grep -q "kill -WINCH" "$FISH_TEMPLATE"; then
  ((TESTS_PASSED++)) || true
  printf "  ${GREEN}✓${NC} $CURRENT_TEST: SIGWINCH redraw signal present\n"
else
  ((TESTS_FAILED++)) || true
  printf "  ${RED}✗${NC} $CURRENT_TEST: SIGWINCH redraw signal missing\n"
fi

echo ""
echo "Artifact mode tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
