#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck shell=bash
# pinned_dot DIR VERSION: build a dispatcher in DIR that resolves names as
# release VERSION would, and print its path. Tests of deprecated names use
# it so they keep passing when the release under test reaches the names'
# `until` release.
#
# bin/dot is copied (it follows symlinks back to its own tree); lib/,
# scripts/ and plugins/ are the real ones, linked, except lib/dot/names.sh,
# which is a shim that sets VERSION and sources the real file, and the
# route fragments (plugins/*/commands.txt, P2.1), which are pinned copies.
# bin/dot sources names.sh after it sets its own VERSION, so the shim wins.
pinned_dot() {
  local dir="$1" version="$2" root="${REPO_ROOT:?}" entry
  mkdir -p "$dir/bin" "$dir/lib/dot"
  cp "$root/bin/dot" "$dir/bin/dot"
  ln -sfn "$root/scripts" "$dir/scripts"
  pin_plugins "$dir/plugins" "$version"
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

# pin_records FILE VERSION: print FILE's records as release VERSION had
# them. A name removed at a later release (its `until`) was still
# deprecated then.
pin_records() {
  awk -F'|' -v OFS='|' -v pin="$2" '
    function key(v, p) { split(v, p, "."); return sprintf("%06d%06d%06d", p[1], p[2], p[3]) }
    $1 == "alias" && $3 == "removed" && $5 != "" && key($5) > key(pin) { $3 = "deprecated" }
    { print }' "$1"
}

# pin_table DATA VERSION: make DATA a copy of the data directory with the
# command table as release VERSION had it.
pin_table() {
  local src="${REPO_ROOT:?}/lib/dot/data"
  rm -rf "$1"
  mkdir -p "$1"
  cp "$src"/* "$1/"
  pin_records "$src/commands.txt" "$2" >"$1/commands.txt"
}

# pin_plugins DIR VERSION: make DIR the plugins tree, each plugin's files
# linked, its route fragment a copy as release VERSION had it.
pin_plugins() {
  local plugin entry
  rm -rf "$1"
  for plugin in "${REPO_ROOT:?}"/plugins/*/; do
    plugin="${plugin%/}"
    mkdir -p "$1/${plugin##*/}"
    for entry in "$plugin"/*; do
      [[ "${entry##*/}" == commands.txt ]] || ln -sfn "$entry" "$1/${plugin##*/}/${entry##*/}"
    done
    [[ ! -f "$plugin/commands.txt" ]] || pin_records "$plugin/commands.txt" "$2" >"$1/${plugin##*/}/commands.txt"
  done
}
