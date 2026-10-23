#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# host_path.sh: a stand-in for the system bin directories with chosen
# tools taken out.
#
# Tests that need a tool to be missing put a stub directory in front of
# `/usr/bin:/bin`. On a CI runner those directories hold only the base
# system; on a workstation they may hold the very tool the test hides
# (pv, ufw, fzf, gum, niri, mise, hyperfine, dot...), and the "missing"
# case then runs the real one. host_path_without mirrors the system bin
# directories as symlinks minus the named tools, so the test sees the
# same base system everywhere.
#
# Bash 3.2 compatible (macOS /bin/bash).

# host_path_without <dir> <tool>...: fill <dir> with links to every entry
# of /usr/bin, /bin, /usr/sbin and /sbin except <tool>..., and print <dir>
# for use in PATH. An earlier directory wins a name, as on a real PATH.
# <dir> must not exist yet: the function deletes inside it, so an unset
# variable turning "$WORK/sys" into "/sys" is refused, not emptied.
host_path_without() {
  local dir="$1" src t
  shift
  [[ "$dir" == */* && ! -e "$dir" ]] || {
    printf 'host_path_without: %s must be a new directory\n' "$dir" >&2
    return 1
  }
  mkdir -p "$dir"
  # One ln per directory: names already linked fail quietly and keep the
  # earlier directory's entry. A merged /usr makes /bin all duplicates.
  for src in /usr/bin /bin /usr/sbin /sbin; do
    [[ -d "$src" ]] || continue
    ln -s "$src"/* "$dir"/ 2>/dev/null || true
  done
  for t in "$@"; do
    rm -f "$dir/$t"
  done
  printf '%s\n' "$dir"
}
