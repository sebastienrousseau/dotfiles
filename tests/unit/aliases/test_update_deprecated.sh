#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# One update path: `update` and `upd` forward to `dot update` with a
# warning until 0.2.538, and `chezmoi apply` deletes the old update script
# and topgrade config from machines that still have them.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

ALIASES="$REPO_ROOT/defaults/.chezmoitemplates/aliases/update/update.aliases.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-update-dep.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# forward NAME ARGS...: run NAME from the aliases with a fake `dot`; prints
# what dot received, then the warning.
forward() {
  bash -c 'source "$1"; shift; dot() { echo "dot $*"; }; "$@" 2>"$0"' \
    "$WORK/err" "$ALIASES" "$@"
}

test_start "update_and_upd_forward_to_dot_update"
assert_equals "dot update --yes --globals" "$(forward update --yes --globals)" "update passes its arguments on"
assert_file_contains "$WORK/err" "'update' is deprecated; use 'dot update' (it stops working in 0.2.538)" \
  "and says what replaces it"
assert_equals "dot update" "$(forward upd)" "upd runs dot update"
assert_file_contains "$WORK/err" "'upd' is deprecated" "and warns under its own name"

test_start "apply_removes_the_old_update_files"
if command -v chezmoi >/dev/null 2>&1; then
  mkdir -p "$WORK/src/dot_local/bin" "$WORK/src/dot_config" "$WORK/home/.local/bin" "$WORK/home/.config"
  cp "$REPO_ROOT/defaults/dot_local/bin/remove_update" "$WORK/src/dot_local/bin/"
  cp "$REPO_ROOT/defaults/dot_config/remove_topgrade.toml" "$WORK/src/dot_config/"
  echo old >"$WORK/home/.local/bin/update"
  echo old >"$WORK/home/.config/topgrade.toml"
  echo '{}' >"$WORK/chezmoi.json"
  HOME="$WORK/home" chezmoi --source "$WORK/src" --destination "$WORK/home" --config "$WORK/chezmoi.json" \
    --persistent-state "$WORK/state.boltdb" apply --no-tty >/dev/null 2>&1
  assert_file_not_exists "$WORK/home/.local/bin/update" "the old update script is deleted"
  assert_file_not_exists "$WORK/home/.config/topgrade.toml" "the topgrade config is deleted"
else
  printf "  - skipped: chezmoi not installed\n"
fi

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
