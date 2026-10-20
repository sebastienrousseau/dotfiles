#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# The fish completion for `dot` (defaults/dot_config/fish/completions/
# dot.fish, generated from the plugin manifests): load it into a clean fish
# and ask fish what it completes with `complete -C`, instead of grepping the
# file for the flag strings.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

TARGET="$REPO_ROOT/defaults/dot_config/fish/completions/dot.fish"
FISH_BIN="$(command -v fish || true)"

if [[ -z "$FISH_BIN" ]]; then
  test_start "fish_dot_completion_requires_fish"
  assert_true "true" "skipped: fish not installed"
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
  exit 0
fi

SB="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/fish-compl.XXXXXX")" && pwd)"
trap 'rm -rf "$SB"' EXIT

test_start "fish_dot_completion_parses"
rc=0
"$FISH_BIN" --no-config -n "$TARGET" 2>"$SB/parse.err" || rc=$?
assert_equals "0" "$rc" "the completion parses"

# completes <command line>: the candidates fish offers, space-separated.
completes() {
  env -i HOME="$SB" PATH="/usr/bin:/bin:$(dirname "$FISH_BIN")" "$FISH_BIN" --no-config -c \
    'function dot; end; source $argv[1]; complete -C $argv[2]' "$TARGET" "$1" 2>/dev/null |
    cut -f1 | tr '\n' ' '
}

# has <needle> <haystack>: 0 when <needle> is one of the space-separated words.
has() { [[ " $2 " == *" $1 "* ]]; }

test_start "fish_dot_completion_version"
out="$(completes 'dot ver')$(completes 'dot --ver')"
assert_true "has version '$out' && has --version '$out'" "offers the version subcommand and --version"

test_start "fish_dot_completion_mcp_flags"
out="$(completes 'dot mcp check -')"
assert_true "has --strict '$out' && has -s '$out' && has --json '$out' && has -j '$out'" \
  "mcp completes --strict/-s and --json/-j"

test_start "fish_dot_completion_attest_flags"
out="$(completes 'dot attest show -')"
assert_true "has --write '$out' && has -w '$out'" "attest completes --write/-w"

test_start "fish_dot_completion_restore_flags"
out="$(completes 'dot doctor restore -')"
assert_true "has --latest '$out' && has -L '$out' && has --git '$out' && has -g '$out' && has --diff '$out' && has -d '$out' && has --dry-run '$out' && has -n '$out'" \
  "restore completes --latest/-L, --git/-g, --diff/-d and --dry-run/-n"

test_start "fish_dot_completion_flags_are_scoped"
out="$(completes 'dot doctor restore -')"
assert_false "has --strict '$out'" "mcp's --strict is not offered for restore"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
