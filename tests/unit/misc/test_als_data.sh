#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1091
# Tests for the als command list (als_data.txt.tmpl): which comment an alias
# takes as its description.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

TMPL="$REPO_ROOT/defaults/dot_config/shell/als_data.txt.tmpl"

if ! command -v chezmoi >/dev/null 2>&1; then
  echo "SKIP: chezmoi is needed to render the template"
  echo "RESULTS:0:0:0"
  exit 0
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/als-data-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/src/.chezmoitemplates/aliases/demo" "$WORK/cz"
: >"$WORK/cz/chezmoi.toml"

cat >"$WORK/src/.chezmoitemplates/aliases/demo/demo.aliases.sh" <<'EOF'
# shellcheck shell=bash
set_demo_aliases() {
  # A note about the code below, not about any alias.
  _demo_helpers
  alias stray='stray_cmd'

  # Above its alias.
  alias above='above_cmd'

  # Above an if: still this alias's description.
  if true; then
    alias guarded='guarded_cmd'
  fi

  alias inline='inline_cmd' # Inline wins.
}
EOF

# desc_of <alias>: the description the rendered list gives <alias>.
desc_of() {
  sed $'s/\x1b\\[[0-9;]*m//g' "$WORK/out.txt" |
    awk -v name="$1" -F'[|]SEP[|]' '$3 == name { sub(/^.* — /, "", $1); sub(/ +$/, "", $1); print $1 }'
}

env -i HOME="$WORK/cz" PATH="$PATH" chezmoi --config "$WORK/cz/chezmoi.toml" \
  --source "$WORK/src" --persistent-state "$WORK/cz/state" \
  execute-template <"$TMPL" >"$WORK/out.txt" 2>"$WORK/err.txt"
render_status=$?

test_start "als_data_renders"
assert_equals "0" "$render_status" "template renders: $(cat "$WORK/err.txt")"

test_start "als_data_comment_does_not_cross_code"
assert_equals "Shell command" "$(desc_of stray)" "a comment above other code is not the alias's description"

test_start "als_data_comment_above_alias"
assert_equals "Above its alias." "$(desc_of above)" "the comment directly above an alias describes it"

test_start "als_data_comment_above_control_line"
assert_equals "Above an if: still this alias's description." "$(desc_of guarded)" \
  "a comment survives the if that wraps its alias"

test_start "als_data_inline_comment"
assert_equals "Inline wins." "$(desc_of inline)" "an inline comment describes its alias"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
