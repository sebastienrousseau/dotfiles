#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# Contracts for lib/dot/utils.sh helpers that gate other code:
#   validate_name — names reach paths and eval contexts, so a single bad
#     character anywhere must be refused (mutation U1: unanchored, "a;b"
#     passed);
#   check_cmd — must say "no" for a missing tool (mutation U3), and its
#     mise fallback must match a tool name exactly, not as a substring.
# Each case runs in a fresh bash with a stub-only PATH.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

UTILS="$REPO_ROOT/lib/dot/utils.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/utils-contract.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bare" "$WORK/mise"
BASH_BIN="$(command -v bash)"
# Tools utils.sh itself needs, and nothing else.
for t in dirname basename uname tr cat grep awk sed; do
  ln -s "$(command -v "$t")" "$WORK/bare/$t"
  ln -s "$(command -v "$t")" "$WORK/mise/$t"
done
cat >"$WORK/mise/mise" <<'EOF'
#!/bin/sh
[ "$1 $2" = "ls --installed" ] || exit 1
printf '%s\n' 'golangci-lint  1.64.8' 'aqua:cli/cli   2.60.0' 'npm:prettier   3.3.3' 'shfmt  3.10.0'
EOF
chmod +x "$WORK/mise/mise"

in_utils() { # in_utils <path-dir> <snippet>
  HOME="$WORK" PATH="$WORK/$1" NO_COLOR=1 "$BASH_BIN" -c "source '$UTILS'; $2" >"$WORK/out" 2>&1
}

test_start "validate_name_accepts_safe_names"
in_utils bare 'validate_name good-name_1.2 && echo ok'
assert_equals "0" "$?" "exit 0"
assert_equals "ok" "$(tail -n1 "$WORK/out")" "no die"

test_start "validate_name_rejects_any_unsafe_character"
for bad in 'a;b' 'x y' '$(id)' 'a/b' ''; do
  in_utils bare "validate_name '$bad' profile; echo reached"
  assert_equals "1" "$?" "'$bad' dies with exit 1"
  assert_file_contains "$WORK/out" "Invalid profile" "'$bad' refusal names the label"
  assert_output_not_contains "reached" "cat '$WORK/out'"
done

test_start "check_cmd_missing_tool_is_false"
in_utils bare 'check_cmd definitely-not-installed-xyz'
assert_equals "1" "$?" "absent from PATH and no mise"

test_start "check_cmd_tool_on_path_is_true"
in_utils bare 'check_cmd awk'
assert_equals "0" "$?" "found on PATH"

test_start "check_cmd_mise_fallback_matches_exact_names"
in_utils mise 'check_cmd golangci-lint'
assert_equals "0" "$?" "plain mise tool"
in_utils mise 'check_cmd cli'
assert_equals "0" "$?" "aqua:owner/name tool"
in_utils mise 'check_cmd prettier'
assert_equals "0" "$?" "npm:name tool"

test_start "check_cmd_mise_fallback_rejects_substrings"
in_utils mise 'check_cmd go'
assert_equals "1" "$?" "'go' is not golangci-lint"
in_utils mise 'check_cmd lint'
assert_equals "1" "$?" "'lint' is not golangci-lint"
in_utils mise 'check_cmd "sh.*"'
assert_equals "1" "$?" "a name is not a regex"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
