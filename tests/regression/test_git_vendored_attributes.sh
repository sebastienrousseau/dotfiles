#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# Regression: the global eol=lf attributes made CRLF files in lazy.nvim
# plugin checkouts look modified, so `dot upgrade` failed with "You have
# local changes" (nvim-lint, copilot.lua).
# Regression for: da89db44
# Why: third-party checkouts must keep upstream line endings untouched.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

_va_tmp="$(mktemp -d -t dotfiles-vattr.XXXXXX)"
trap 'rm -rf "$_va_tmp"' EXIT
export HOME="$_va_tmp/home"
export XDG_CONFIG_HOME="$HOME/.config"
export GIT_CONFIG_NOSYSTEM=1
unset GIT_CONFIG_GLOBAL
mkdir -p "$HOME/.config/git"

_va_chezmoi="$(command -v chezmoi 2>/dev/null || true)"
if [[ -z "$_va_chezmoi" ]]; then
  echo "  (skip) chezmoi not available"
  echo "RESULTS:0:0:0"
  exit 0
fi

# Render the real gitconfig and install the git files it references.
printf '{}\n' >"$_va_tmp/chezmoi.json"
"$_va_chezmoi" --config "$_va_tmp/chezmoi.json" --source "$REPO_ROOT/defaults" \
  --destination "$HOME" --cache "$_va_tmp/cache" \
  --persistent-state "$_va_tmp/state.boltdb" \
  execute-template <"$REPO_ROOT/defaults/dot_gitconfig.tmpl" >"$HOME/.gitconfig" 2>"$_va_tmp/render.err"
for f in attributes config-vendored attributes-vendored; do
  [[ -f "$REPO_ROOT/defaults/dot_config/git/$f" ]] &&
    cp "$REPO_ROOT/defaults/dot_config/git/$f" "$HOME/.config/git/$f"
done

# A repo with a .lua file committed with CRLF, as nvim-lint ships one.
_va_mkrepo() {
  mkdir -p "$1" && git -C "$1" init -q &&
    git -C "$1" -c core.attributesFile=/dev/null -c user.name=t -c user.email=t@t \
      -c commit.gpgsign=false commit -q --allow-empty -m init &&
    printf 'a\r\nb\r\n' >"$1/spec.lua" &&
    git -C "$1" -c core.attributesFile=/dev/null add spec.lua &&
    git -C "$1" -c core.attributesFile=/dev/null -c user.name=t -c user.email=t@t \
      -c commit.gpgsign=false commit -q -m crlf
}
# Back-date the file so its stat no longer matches the index: git then
# re-reads the content through the attributes instead of trusting a
# stat-clean entry, which only happens by chance within the racy window.
_va_dirty() {
  touch -t 200001010000 "$1/spec.lua"
  git -C "$1" status --porcelain -- spec.lua
}

_va_plugin="$HOME/.local/share/nvim/lazy/some-plugin"
_va_other="$HOME/src/project"
_va_mkrepo "$_va_plugin"
_va_mkrepo "$_va_other"

test_start "vattr_gitconfig_renders"
assert_file_exists "$HOME/.gitconfig" "gitconfig template renders"

test_start "vattr_lazy_plugin_crlf_clean"
assert_empty "$(_va_dirty "$_va_plugin")" "CRLF file in a lazy.nvim checkout is not reported as modified"

test_start "vattr_own_repos_keep_lf_policy"
assert_not_empty "$(_va_dirty "$_va_other")" "global eol=lf policy still applies outside plugin checkouts"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
