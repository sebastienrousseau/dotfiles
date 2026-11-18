#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# chezmoi applies every ignore file in the source root, and the tests that
# check what stays out of $HOME render only .chezmoiignore.tmpl. A second
# ignore file (there was a plain .chezmoiignore) changes what chezmoi
# ignores without any test seeing it. What chezmoi ignores for the real
# source must equal what .chezmoiignore.tmpl alone ignores.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

if ! command -v chezmoi >/dev/null 2>&1; then
  echo "SKIP: chezmoi not installed"
  echo "RESULTS:0:0:0"
  exit 0
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-ignore-single.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/home"
printf '{}\n' >"$WORK/chezmoi.json"
cp -R "$REPO_ROOT/defaults" "$WORK/only-tmpl"
find "$WORK/only-tmpl" -maxdepth 1 -name '.chezmoiignore*' ! -name '.chezmoiignore.tmpl' -exec rm -f {} +

# ignored <source> <os>: the sorted entries chezmoi ignores for that OS.
ignored() {
  HOME="$WORK/home" chezmoi --config "$WORK/chezmoi.json" --source "$1" --destination "$WORK/home" \
    --cache "$WORK/cache" --persistent-state "$WORK/state.boltdb" \
    --override-data "{\"chezmoi\":{\"os\":\"$2\"}}" ignored 2>&1 | sort
}

for os in darwin linux windows; do
  test_start "chezmoiignore_tmpl_is_the_only_ignore_source_on_$os"
  real="$(ignored "$REPO_ROOT/defaults" "$os")"
  assert_not_empty "$real" "chezmoi ignores something on $os"
  assert_equals "$(ignored "$WORK/only-tmpl" "$os")" "$real" \
    ".chezmoiignore.tmpl alone gives the ignore set chezmoi uses on $os"
done

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
