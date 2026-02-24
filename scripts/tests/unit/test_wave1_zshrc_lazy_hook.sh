#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034,SC2016
# Unit tests for Wave 1: zshrc lazy alias loading hook and FNM fix
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

ZSHRC="$REPO_ROOT/dot_config/zsh/dot_zshrc.tmpl"
OPTIONS="$REPO_ROOT/dot_config/zsh/rc.d/30-options.zsh.tmpl"

echo "Testing Wave 1: zshrc lazy hook and FNM fix..."

# --- zshrc lazy loading ---

test_start "zshrc_exists"
assert_file_exists "$ZSHRC" "dot_zshrc.tmpl should exist"

test_start "zshrc_loads_eager_aliases"
assert_file_contains "$ZSHRC" "90-ux-aliases" "should source 90-ux-aliases in core loop"

test_start "zshrc_loads_lazy_aliases"
assert_file_contains "$ZSHRC" "91-ux-aliases-lazy" "should reference 91-ux-aliases-lazy"

test_start "zshrc_uses_precmd_hook"
assert_file_contains "$ZSHRC" "add-zsh-hook precmd _load_deferred_layers" "should register precmd hook for deferred layers"

test_start "zshrc_removes_hook_after_load"
assert_file_contains "$ZSHRC" "add-zsh-hook -d precmd _load_deferred_layers" "should deregister hook after loading"

test_start "zshrc_autoloads_add_zsh_hook"
assert_file_contains "$ZSHRC" "autoload -Uz add-zsh-hook" "should autoload add-zsh-hook"

test_start "zshrc_no_eager_fnm_eval"
# There should be no eager `eval "$(fnm env` in the zshrc outside of 30-options
if grep -q 'eval "$(fnm env' "$ZSHRC" 2>/dev/null; then
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: zshrc should not eagerly eval fnm env"
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: no eager fnm eval in zshrc"
fi

test_start "zshrc_core_loop_layers"
# Verify the core loading loop includes the expected eager layers
# (50-logic-functions is now deferred via precmd hook)
all_layers_found=true
for layer in "00-core-paths" "05-core-safety" "40-ls-colors" "90-ux-aliases"; do
  if ! grep -q "$layer" "$ZSHRC"; then
    all_layers_found=false
    ((TESTS_FAILED++)) || true
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: missing layer $layer in core loop"
    break
  fi
done
if [[ "$all_layers_found" == "true" ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: all 4 eager core layers present in loading loop"
fi

test_start "zshrc_deferred_logic_functions"
assert_file_contains "$ZSHRC" "50-logic-functions" "50-logic-functions should be loaded via deferred hook"

test_start "zshrc_interactive_guard"
assert_file_contains "$ZSHRC" "[[ -o interactive ]] || return" "should skip non-interactive shells"

test_start "zshrc_source_guard"
assert_file_contains "$ZSHRC" "DOTFILES_SOURCED" "should guard against double-sourcing"

# --- 30-options.zsh lazy-load helper ---

test_start "options_exists"
assert_file_exists "$OPTIONS" "30-options.zsh.tmpl should exist"

test_start "options_fnm_lazy_load"
# Check for generic lazy-load helper usage with fnm
assert_file_contains "$OPTIONS" "_dotfiles_lazy_load fnm" "should use _dotfiles_lazy_load helper for fnm"

test_start "options_lazy_load_helper"
# Verify the generic lazy-load helper is defined
assert_file_contains "$OPTIONS" "_dotfiles_lazy_load()" "should define _dotfiles_lazy_load helper function"

test_start "options_fnm_commands"
# fnm lazy load should include node, npm, npx commands
assert_file_contains "$OPTIONS" "fnm node npm npx" "fnm lazy load should include node npm npx"

test_start "options_nvm_fallback"
# Check for NVM fallback when fnm unavailable
assert_file_contains "$OPTIONS" '_dotfiles_lazy_load nvm' "should have NVM fallback when fnm unavailable"

test_start "options_nvm_requires_no_fnm"
# NVM should only load if fnm is NOT available
assert_file_contains "$OPTIONS" '! command -v fnm' "NVM block should be guarded by fnm absence"

test_start "options_sdkman_lazy"
assert_file_contains "$OPTIONS" '_dotfiles_lazy_load sdkman' "should have SDKMAN lazy loader"

echo ""
echo "Wave 1 zshrc lazy hook and FNM fix tests completed."
print_summary
