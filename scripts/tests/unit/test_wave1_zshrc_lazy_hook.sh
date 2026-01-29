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
assert_file_contains "$ZSHRC" "add-zsh-hook precmd _load_lazy_aliases" "should register precmd hook for lazy aliases"

test_start "zshrc_removes_hook_after_load"
assert_file_contains "$ZSHRC" "add-zsh-hook -d precmd _load_lazy_aliases" "should deregister hook after loading"

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
# Verify the core loading loop includes the expected layers
all_layers_found=true
for layer in "00-core-paths" "05-core-safety" "40-ls-colors" "50-logic-functions" "90-ux-aliases"; do
  if ! grep -q "$layer" "$ZSHRC"; then
    all_layers_found=false
    ((TESTS_FAILED++)) || true
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: missing layer $layer in core loop"
    break
  fi
done
if [[ "$all_layers_found" == "true" ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: all 5 core layers present in loading loop"
fi

test_start "zshrc_interactive_guard"
assert_file_contains "$ZSHRC" "[[ -o interactive ]] || return" "should skip non-interactive shells"

test_start "zshrc_source_guard"
assert_file_contains "$ZSHRC" "DOTFILES_SOURCED" "should guard against double-sourcing"

# --- 30-options.zsh FNM fix ---

test_start "options_exists"
assert_file_exists "$OPTIONS" "30-options.zsh.tmpl should exist"

test_start "options_fnm_lazy_load"
assert_file_contains "$OPTIONS" "_lazy_load_fnm" "should define _lazy_load_fnm function"

test_start "options_fnm_lazy_wrapper"
# fnm should be wrapped as lazy-load function
if grep -q 'fnm() { _lazy_load_fnm; command fnm' "$OPTIONS"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: fnm has lazy-load wrapper"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: fnm should have lazy-load wrapper"
fi

test_start "options_node_lazy_wrapper"
assert_file_contains "$OPTIONS" 'node() { _lazy_load_fnm' "node should trigger fnm lazy load"

test_start "options_no_duplicate_fnm_lazy"
# Count how many _lazy_load_fnm function definitions exist (should be exactly 1)
fnm_defs=$(grep -c '_lazy_load_fnm()' "$OPTIONS" || true)
if [[ "$fnm_defs" -eq 1 ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: exactly one _lazy_load_fnm definition"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: expected 1 _lazy_load_fnm definition, found $fnm_defs"
fi

test_start "options_nvm_fallback"
assert_file_contains "$OPTIONS" '_lazy_load_nvm' "should have NVM fallback when fnm unavailable"

test_start "options_nvm_requires_no_fnm"
# NVM should only load if fnm is NOT available
assert_file_contains "$OPTIONS" '! command -v fnm' "NVM block should be guarded by fnm absence"

test_start "options_sdkman_lazy"
assert_file_contains "$OPTIONS" '_lazy_load_sdkman' "should have SDKMAN lazy loader"

echo ""
echo "Wave 1 zshrc lazy hook and FNM fix tests completed."
print_summary
