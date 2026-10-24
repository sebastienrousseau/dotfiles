#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck shell=bash
# pinned_dot DIR VERSION: build a dispatcher in DIR that resolves names as
# release VERSION would, and print its path. Tests of deprecated names use
# it so they keep passing when the release under test reaches the names'
# `until` release.
#
# bin/dot is copied (it follows symlinks back to its own tree); lib/ and
# scripts/ are the real ones, linked, except lib/dot/names.sh, which is a
# shim that sets VERSION and sources the real file. bin/dot sources
# names.sh after it sets its own VERSION, so the shim wins.
pinned_dot() {
  local dir="$1" version="$2" root="${REPO_ROOT:?}" entry
  mkdir -p "$dir/bin" "$dir/lib/dot"
  cp "$root/bin/dot" "$dir/bin/dot"
  ln -sfn "$root/scripts" "$dir/scripts"
  for entry in "$root"/lib/*; do
    [[ "${entry##*/}" == dot ]] || ln -sfn "$entry" "$dir/lib/${entry##*/}"
  done
  for entry in "$root"/lib/dot/*; do
    ln -sfn "$entry" "$dir/lib/dot/${entry##*/}"
  done
  pin_names "$dir/lib/dot" "$version"
  printf '%s\n' "$dir/bin/dot"
}

# pin_names LIBDOT VERSION: replace LIBDOT/names.sh with a shim that sets
# VERSION and sources the real names.sh, which reads the command table
# from the tree bin/dot runs in ($_DOT_SRC), and pin that table too.
pin_names() {
  rm -f "$1/names.sh"
  printf 'VERSION=%q\n# shellcheck disable=SC1090\nsource %q\n' \
    "$2" "${REPO_ROOT:?}/lib/dot/names.sh" >"$1/names.sh"
  pin_table "$1/data" "$2"
}

# pin_table DATA VERSION: make DATA a copy of the command table as release
# VERSION had it. A name removed at a later release (its `until`) was still
# deprecated then.
pin_table() {
  local src="${REPO_ROOT:?}/lib/dot/data"
  rm -rf "$1"
  mkdir -p "$1"
  cp "$src"/* "$1/"
  awk -F'|' -v OFS='|' -v pin="$2" '
    function key(v, p) { split(v, p, "."); return sprintf("%06d%06d%06d", p[1], p[2], p[3]) }
    $1 == "alias" && $3 == "removed" && $5 != "" && key($5) > key(pin) { $3 = "deprecated" }
    { print }' "$src/commands.txt" >"$1/commands.txt"
}
