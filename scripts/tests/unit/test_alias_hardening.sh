#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for alias hardening controls

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

LAZY_TEMPLATE="$REPO_ROOT/dot_config/shell/91-ux-aliases-lazy.sh.tmpl"
INTERACTIVE_ALIASES="$REPO_ROOT/.chezmoitemplates/aliases/interactive/interactive.aliases.sh"
SUDO_ALIASES="$REPO_ROOT/.chezmoitemplates/aliases/sudo/sudo.aliases.sh"
NMAP_ALIASES="$REPO_ROOT/.chezmoitemplates/aliases/security/nmap-scanning.aliases.sh"
UFW_ALIASES="$REPO_ROOT/.chezmoitemplates/aliases/security/ufw-rules.aliases.sh"
ZSHRC_TEMPLATE="$REPO_ROOT/dot_config/zsh/dot_zshrc.tmpl"
EDITOR_ALIASES="$REPO_ROOT/.chezmoitemplates/aliases/editor/editor.aliases.sh"
CURLSTATUS_FN="$REPO_ROOT/.chezmoitemplates/functions/curlstatus.sh"
CURLTIME_FN="$REPO_ROOT/.chezmoitemplates/functions/curltime.sh"
CURLHEADER_FN="$REPO_ROOT/.chezmoitemplates/functions/curlheader.sh"

test_start "lazy_template_heroku_submodule_exclusion"
if grep -q "isHerokuSubmodule" "$LAZY_TEMPLATE"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: lazy template excludes heroku submodule files"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: missing heroku submodule exclusion"
fi

test_start "interactive_safe_aliases_flag"
assert_file_contains "$INTERACTIVE_ALIASES" "DOTFILES_SAFE_ALIASES" "interactive overrides should be opt-in"

test_start "sudo_alias_opt_in_flag"
assert_file_contains "$SUDO_ALIASES" "DOTFILES_ENABLE_SUDO_ALIAS" "sudo shadow alias should be opt-in"

test_start "nmap_module_command_guard"
assert_file_contains "$NMAP_ALIASES" "command -v nmap" "nmap aliases should guard on command availability"

test_start "ufw_module_command_guard"
assert_file_contains "$UFW_ALIASES" "command -v ufw" "ufw aliases should guard on command availability"

test_start "alias_wrapper_opt_in_flag"
assert_file_contains "$ZSHRC_TEMPLATE" "DOTFILES_ALIAS_WRAPPER" "alias wrapper should be opt-in"

test_start "editor_legacy_aliases_opt_in"
assert_file_contains "$EDITOR_ALIASES" "DOTFILES_LEGACY_EDITOR_ALIASES" "legacy editor aliases should be gated"

test_start "curlstatus_deduplicated_aliases"
if grep -q "alias cst=" "$CURLSTATUS_FN"; then
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: cst alias should be removed"
else
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: redundant cst alias removed"
fi

test_start "curltime_deduplicated_aliases"
if grep -q "alias chtm=" "$CURLTIME_FN"; then
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: chtm alias should be removed"
else
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: redundant chtm alias removed"
fi

test_start "curlheader_deduplicated_aliases"
if grep -q "alias chdr=" "$CURLHEADER_FN"; then
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: chdr alias should be removed"
else
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: redundant chdr alias removed"
fi

echo ""
echo "Alias hardening tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
