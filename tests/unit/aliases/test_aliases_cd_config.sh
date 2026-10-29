#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

ALIAS_FILE="$REPO_ROOT/defaults/.chezmoitemplates/aliases/cd/cd-config.aliases.sh"

test_start "cd_config_file_exists"
assert_file_exists "$ALIAS_FILE" "cd/cd-config.aliases.sh should exist"

test_start "cd_config_valid_syntax"
if bash -n "$ALIAS_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: syntax error"
fi

test_start "cd_config_defines_content"
if grep -qE 'alias |function |^[a-z_]+\(\)|_LOADED=' "$ALIAS_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: defines aliases or functions"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should define aliases or functions"
fi

# DOTFILES_VERSION comes from the shell rc (zsh's 10-env renders it from
# .chezmoidata.toml); the cd alias files must not overwrite it with a
# hard-coded release. version_after <file> [preset]: the value after sourcing.
version_after() {
  local sandbox
  sandbox="$(mktemp -d)"
  env -i HOME="$sandbox" PATH="$PATH" ${BASH_ENV:+BASH_ENV="$BASH_ENV"} ${PS4:+PS4="$PS4"} \
    ${2:+DOTFILES_VERSION="$2"} bash --norc --noprofile -c \
    ". \"\$1\" >/dev/null 2>&1; printf %s \"\${DOTFILES_VERSION-unset}\"" _ "$1"
  rm -rf "$sandbox"
}

for cd_file in cd-config cd; do
  test_start "${cd_file}_keeps_dotfiles_version"
  assert_equals "9.9.9" "$(version_after "$REPO_ROOT/defaults/.chezmoitemplates/aliases/cd/$cd_file.aliases.sh" 9.9.9)" \
    "$cd_file.aliases.sh keeps the DOTFILES_VERSION the shell already set"

  test_start "${cd_file}_sets_no_dotfiles_version"
  assert_equals "unset" "$(version_after "$REPO_ROOT/defaults/.chezmoitemplates/aliases/cd/$cd_file.aliases.sh")" \
    "$cd_file.aliases.sh exports no hard-coded DOTFILES_VERSION"
done

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
