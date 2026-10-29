#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

ALIASES_DIR="$REPO_ROOT/defaults/.chezmoitemplates/aliases/chmod"

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

# chmod_run <function> <mode> <expected-octal>: run a chmod helper on a
# fresh 644 file in bash; print its status and whether the mode matches.
chmod_run() {
  local sandbox
  sandbox="$(mktemp -d)"
  : >"$sandbox/file"
  chmod 644 "$sandbox/file"
  env -i HOME="$sandbox" PATH="$PATH" ${BASH_ENV:+BASH_ENV="$BASH_ENV"} ${PS4:+PS4="$PS4"} \
    bash --norc --noprofile -c ". \"\$1\"; \"\$2\" \"\$3\" \"\$4\" >/dev/null 2>&1; echo \"rc=\$?\"" _ \
    "$REPO_ROOT/defaults/.chezmoitemplates/aliases/chmod/chmod.aliases.sh" "$1" "$2" "$sandbox/file"
  if [[ -n "$(find "$sandbox/file" -perm "$3")" ]]; then echo "mode=$3"; else echo "mode=other"; fi
  rm -rf "$sandbox"
}

# Without -R the helpers must not hand chmod an empty argument (GNU chmod
# then fails with "cannot access ''" after changing the mode).
test_start "chmod_change_permission_non_recursive"
assert_equals "rc=0 mode=600" "$(chmod_run change_permission 600 600 | tr '\n' ' ' | sed 's/ $//')" \
  "change_permission 600 <file> succeeds"

test_start "chmod_symbolic_permission_non_recursive"
assert_equals "rc=0 mode=744" "$(chmod_run symbolic_permission u+x 744 | tr '\n' ' ' | sed 's/ $//')" \
  "symbolic_permission u+x <file> succeeds"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
