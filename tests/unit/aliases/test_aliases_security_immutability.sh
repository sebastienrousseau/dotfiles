#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

ALIAS_FILE="$REPO_ROOT/defaults/.chezmoitemplates/aliases/security/immutability.aliases.sh"

test_start "security_immutability_file_exists"
assert_file_exists "$ALIAS_FILE" "immutability.aliases.sh should exist"

test_start "security_immutability_valid_syntax"
if bash -n "$ALIAS_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: syntax error"
fi

test_start "security_immutability_defines_content"
if grep -qE 'alias |function ' "$ALIAS_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: defines aliases or functions"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should define aliases"
fi

# lock_alias <relative-script-path>: the lock-configs alias a bash shell
# gets when the script exists at that path under a sandbox HOME.
lock_alias() {
  local sandbox
  sandbox="$(mktemp -d)"
  if [[ -n "$1" ]]; then
    mkdir -p "$sandbox/$(dirname "$1")"
    : >"$sandbox/$1"
  fi
  env -i HOME="$sandbox" PATH="$PATH" ${BASH_ENV:+BASH_ENV="$BASH_ENV"} ${PS4:+PS4="$PS4"} \
    bash --norc --noprofile -c ". \"\$1\"; alias lock-configs 2>/dev/null || echo none" _ "$ALIAS_FILE" |
    sed "s|$sandbox|~|"
  rm -rf "$sandbox"
}

test_start "security_immutability_default_source"
assert_equals "alias lock-configs='bash ~/.dotfiles/scripts/security/lock-configs.sh lock'" \
  "$(lock_alias .dotfiles/scripts/security/lock-configs.sh)" \
  "lock-configs is defined from the default source checkout ~/.dotfiles"

test_start "security_immutability_legacy_source"
assert_equals "alias lock-configs='bash ~/.local/share/chezmoi/scripts/security/lock-configs.sh lock'" \
  "$(lock_alias .local/share/chezmoi/scripts/security/lock-configs.sh)" \
  "lock-configs still works from the legacy chezmoi source location"

test_start "security_immutability_no_script"
assert_equals "none" "$(lock_alias "")" "no script, no alias"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
