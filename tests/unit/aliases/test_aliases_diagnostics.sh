#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

ALIASES_DIR="$REPO_ROOT/defaults/.chezmoitemplates/aliases/diagnostics"

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

# diag_alias <name>: the alias definition a bash shell gets from the
# diagnostics aliases, with chezmoi on PATH (the helpers need it).
diag_alias() {
  local sandbox
  sandbox="$(mktemp -d)"
  mkdir -p "$sandbox/bin"
  printf '#!/bin/sh\nexit 0\n' >"$sandbox/bin/chezmoi"
  chmod +x "$sandbox/bin/chezmoi"
  env -i HOME="$sandbox" PATH="$sandbox/bin:$PATH" ${BASH_ENV:+BASH_ENV="$BASH_ENV"} ${PS4:+PS4="$PS4"} \
    bash --norc --noprofile -c ". \"\$1\"; alias \"\$2\" 2>/dev/null || echo none" _ \
    "$ALIASES_DIR/diagnostics.aliases.sh" "$1"
  rm -rf "$sandbox"
}

test_start "diagnostics_helpers_defined"
assert_equals "alias cdiff='dot diff'" "$(diag_alias cdiff)" "the chezmoi helpers load when chezmoi is on PATH"

# `dot remove` is not a dot command (it prints "Unknown command: remove").
test_start "diagnostics_no_crem"
assert_equals "none" "$(diag_alias crem)" "crem is not defined: it called the unknown 'dot remove'"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
