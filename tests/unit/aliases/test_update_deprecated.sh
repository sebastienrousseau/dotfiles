#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# One update path: the `update` and `upd` forwarders went in 0.2.538, and
# `chezmoi apply` deletes the old update script and topgrade config from
# machines that still have them.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-update-dep.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

test_start "no_shell_defines_update_or_upd"
# Source every alias file as the shell does; neither name may come back to
# shadow `dot update`.
defined="$(bash -c 'for f in "$1"/defaults/.chezmoitemplates/aliases/*/*.aliases.sh; do
  source "$f"; done >/dev/null 2>&1; declare -F update upd; alias update upd 2>/dev/null' _ "$REPO_ROOT")"
assert_equals "" "$defined" "update and upd are gone (removed in 0.2.538)"

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
