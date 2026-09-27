#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for alias hardening controls

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"

LAZY_TEMPLATE="$REPO_ROOT/defaults/dot_config/shell/91-ux-aliases-lazy.sh.tmpl"
INTERACTIVE_ALIASES="$REPO_ROOT/defaults/.chezmoitemplates/aliases/interactive/interactive.aliases.sh"
SUDO_ALIASES="$REPO_ROOT/defaults/.chezmoitemplates/aliases/sudo/sudo.aliases.sh"
UFW_ALIASES="$REPO_ROOT/defaults/.chezmoitemplates/aliases/security/ufw-rules.aliases.sh"
ZSHRC_TEMPLATE="$REPO_ROOT/defaults/dot_config/zsh/dot_zshrc.tmpl"
EDITOR_ALIASES="$REPO_ROOT/defaults/.chezmoitemplates/aliases/editor/editor.aliases.sh"
CURLSTATUS_FN="$REPO_ROOT/defaults/.chezmoitemplates/functions/curl/curlstatus.sh"
CURLTIME_FN="$REPO_ROOT/defaults/.chezmoitemplates/functions/curl/curltime.sh"
CURLHEADER_FN="$REPO_ROOT/defaults/.chezmoitemplates/functions/curl/curlheader.sh"

test_start "lazy_template_ecosystem_filtering"
if grep -q "DOTFILES_ALIAS_ECOSYSTEMS" "$LAZY_TEMPLATE"; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: lazy template supports ecosystem filtering"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: missing ecosystem filtering support"
fi

# alias_probe <file> <path-dir> <env...> -- <alias names...>: source <file>
# in a clean bash (PATH = <path-dir> plus the system dirs, env as given) and
# print the names from the list that ended up defined, space-separated.
AH_TMP="$(mktemp -d)"
trap 'rm -rf "$AH_TMP"' EXIT
mkdir -p "$AH_TMP/none" "$AH_TMP/tools"
for tool in nmap ufw; do
  printf '#!/bin/sh\nexit 0\n' >"$AH_TMP/tools/$tool"
  chmod +x "$AH_TMP/tools/$tool"
done
alias_probe() {
  local file="$1" pathdir="$2"
  shift 2
  local -a envs=()
  while [[ $# -gt 0 && "$1" != "--" ]]; do
    envs+=("$1")
    shift
  done
  shift
  # shellcheck disable=SC2016
  env -i HOME="$AH_TMP" PATH="$pathdir:/usr/bin:/bin" ${envs[@]+"${envs[@]}"} bash --norc --noprofile -c '
    shopt -s expand_aliases
    dot_confirm_destructive() { :; }
    source "$1" >/dev/null 2>&1
    shift
    for a in "$@"; do alias "$a" >/dev/null 2>&1 && printf "%s " "$a"; done
    true' _ "$file" "$@"
}

test_start "interactive_overrides_off_by_default"
assert_equals "" "$(alias_probe "$INTERACTIVE_ALIASES" "$AH_TMP/none" -- cp mv rm ln del)" "no core command is shadowed without DOTFILES_SAFE_ALIASES"

test_start "interactive_overrides_opt_in"
assert_equals "cp mv rm ln del " "$(alias_probe "$INTERACTIVE_ALIASES" "$AH_TMP/none" DOTFILES_SAFE_ALIASES=1 -- cp mv rm ln del)" "DOTFILES_SAFE_ALIASES=1 enables them"

test_start "sudo_alias_off_by_default"
assert_equals "" "$(alias_probe "$SUDO_ALIASES" "$AH_TMP/none" -- sudo)" "sudo is not shadowed by default"

test_start "sudo_alias_opt_in"
assert_equals "sudo " "$(alias_probe "$SUDO_ALIASES" "$AH_TMP/none" DOTFILES_ENABLE_SUDO_ALIAS=1 -- sudo)" "DOTFILES_ENABLE_SUDO_ALIAS=1 shadows sudo"

SYSTEM_ALIASES="$REPO_ROOT/defaults/.chezmoitemplates/aliases/system/system.aliases.sh"
test_start "nmap_aliases_need_nmap"
assert_equals "|nma nmfast " "$(alias_probe "$SYSTEM_ALIASES" "$AH_TMP/none" -- nma nmfast)|$(alias_probe "$SYSTEM_ALIASES" "$AH_TMP/tools" -- nma nmfast)" "nmap aliases exist only when nmap is on PATH"

test_start "ufw_aliases_need_ufw"
assert_equals "|fws fwsv " "$(alias_probe "$UFW_ALIASES" "$AH_TMP/none" -- fws fwsv)|$(alias_probe "$UFW_ALIASES" "$AH_TMP/tools" -- fws fwsv)" "ufw aliases exist only when ufw is on PATH"

test_start "alias_wrapper_opt_in_flag"
assert_file_contains "$ZSHRC_TEMPLATE" "DOTFILES_ALIAS_WRAPPER" "alias wrapper should be opt-in"

test_start "editor_legacy_aliases_opt_in"
assert_equals "|vi vim " "$(alias_probe "$EDITOR_ALIASES" "$AH_TMP/none" EDITOR=nvim -- vi vim)|$(alias_probe "$EDITOR_ALIASES" "$AH_TMP/none" EDITOR=nvim DOTFILES_LEGACY_EDITOR_ALIASES=1 -- vi vim)" "vi/vim -> nvim only with DOTFILES_LEGACY_EDITOR_ALIASES=1"

test_start "curlstatus_deduplicated_aliases"
if grep -q "alias cst=" "$CURLSTATUS_FN"; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: cst alias should be removed"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: redundant cst alias removed"
fi

test_start "curltime_deduplicated_aliases"
if grep -q "alias chtm=" "$CURLTIME_FN"; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: chtm alias should be removed"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: redundant chtm alias removed"
fi

test_start "curlheader_deduplicated_aliases"
if grep -q "alias chdr=" "$CURLHEADER_FN"; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: chdr alias should be removed"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: redundant chdr alias removed"
fi

echo ""
echo "Alias hardening tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
