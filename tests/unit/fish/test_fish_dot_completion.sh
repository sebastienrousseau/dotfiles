#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# The fish completion for `dot` (defaults/dot_config/fish/completions/
# dot.fish.tmpl): render it with chezmoi against this checkout in a sandbox,
# load it into a clean fish, and ask fish what it completes with
# `complete -C`, instead of grepping the template for the flag strings.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

TARGET="$REPO_ROOT/defaults/dot_config/fish/completions/dot.fish.tmpl"
FISH_BIN="$(command -v fish || true)"
CHEZMOI_BIN="$(command -v chezmoi || true)"

if [[ -z "$FISH_BIN" || -z "$CHEZMOI_BIN" ]]; then
  test_start "fish_dot_completion_requires_fish_and_chezmoi"
  assert_true "true" "skipped: fish or chezmoi not installed"
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
  exit 0
fi

SB="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/fish-compl.XXXXXX")" && pwd)"
trap 'rm -rf "$SB"' EXIT
: >"$SB/chezmoi.toml"

test_start "fish_dot_completion_renders"
rc=0
env -i HOME="$SB" PATH="/usr/bin:/bin" "$CHEZMOI_BIN" --config "$SB/chezmoi.toml" \
  --source "$REPO_ROOT" --destination "$SB" --cache "$SB/cache" \
  --persistent-state "$SB/state.boltdb" execute-template <"$TARGET" >"$SB/dot.fish" 2>"$SB/render.err" || rc=$?
assert_equals "0" "$rc" "the completion template renders"

# completes <command line>: the candidates fish offers, space-separated.
completes() {
  env -i HOME="$SB" PATH="/usr/bin:/bin:$(dirname "$FISH_BIN")" "$FISH_BIN" --no-config -c \
    'function dot; end; source $argv[1]; complete -C $argv[2]' "$SB/dot.fish" "$1" 2>/dev/null |
    cut -f1 | tr '\n' ' '
}

# has <needle> <haystack>: 0 when <needle> is one of the space-separated words.
has() { [[ " $2 " == *" $1 "* ]]; }

test_start "fish_dot_completion_version"
out="$(completes 'dot ver')$(completes 'dot --ver')"
assert_true "has version '$out' && has --version '$out'" "offers the version subcommand and --version"

test_start "fish_dot_completion_mcp_flags"
out="$(completes 'dot mcp -')"
assert_true "has --strict '$out' && has -s '$out' && has --json '$out' && has -j '$out'" \
  "mcp completes --strict/-s and --json/-j"

test_start "fish_dot_completion_attest_flags"
out="$(completes 'dot attest -')"
assert_true "has --write '$out' && has -w '$out'" "attest completes --write/-w"

test_start "fish_dot_completion_restore_flags"
out="$(completes 'dot restore -')"
assert_true "has --latest '$out' && has -L '$out' && has --git '$out' && has -g '$out' && has --diff '$out' && has -d '$out' && has --dry-run '$out' && has -n '$out'" \
  "restore completes --latest/-L, --git/-g, --diff/-d and --dry-run/-n"

test_start "fish_dot_completion_flags_are_scoped"
out="$(completes 'dot restore -')"
assert_false "has --strict '$out'" "mcp's --strict is not offered for restore"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
