#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Fail when a chezmoi run_* script installs something that is not pinned.
#
# run_* scripts execute on `chezmoi apply`, so whatever they fetch runs with
# the user's privileges on every machine. Each install must name a version:
#   - no `@latest` (go install, mise use, npm);
#   - `npm install -g` only of packages that name an exact version
#     (a global npm package lives in one Node version's directory and is
#     better declared as an `npm:` pin in mise's conf.d);
#   - `cargo install` always with --locked (and a --version from the data);
#   - `git clone` only with --no-checkout, followed by a checkout of a
#     pinned commit, never the default branch as it is today.
# Tools that `dot upgrade` refreshes through mise float on purpose (D3); they
# are configured in mise's conf.d, not installed here.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
failed=0

# report <file> <line-number> <text> <reason>
report() {
  printf '%s:%s: %s\n    -> %s\n' "${1#"$repo_root"/}" "$2" "$3" "$4" >&2
  failed=1
}

# npm_global_unpinned <line>: 0 when the line runs a global npm install
# (`npm install|i|add` with -g/--global) of a package with no exact version:
# a bare name, a range, or a variable the checker cannot see into.
npm_global_unpinned() {
  local word words q="[\"']"
  local pinned="^${q}?(@[^/@]+/)?[^@\"']+@v?[0-9]+(\\.[0-9]+)*${q}?\$"
  [[ "$1" =~ (^|[[:space:]])(-g|--global)([[:space:]]|$) ]] || return 1
  [[ "$1" =~ npm[[:space:]]+(install|i|add)[[:space:]]+([^|&;<>]*) ]] || return 1
  read -ra words <<<"${BASH_REMATCH[2]}"
  for word in "${words[@]}"; do
    case "$word" in
      -* | [0-9]) ;;
      *) [[ "$word" =~ $pinned ]] || return 0 ;;
    esac
  done
  return 1
}

# check_line <file> <n> <line>: the rules above, on one non-comment line.
check_line() {
  local file="$1" n="$2" line="$3"
  case "$line" in
    *@latest*) report "$file" "$n" "$line" "names @latest; pin an exact version" ;;
  esac
  if [[ "$line" =~ cargo[[:space:]]+install([[:space:]]|$) && ! "$line" =~ --list ]]; then
    [[ "$line" == *--locked* ]] || report "$file" "$n" "$line" "cargo install without --locked"
  fi
  if npm_global_unpinned "$line"; then
    report "$file" "$n" "$line" "npm install -g without an exact version; pin it as npm:<pkg> in mise conf.d"
  fi
  if [[ "$line" =~ git[[:space:]]+clone([[:space:]]|$) && "$line" != *--no-checkout* ]]; then
    report "$file" "$n" "$line" "git clone of a moving branch; clone --no-checkout, then check out a pinned commit"
  fi
}

while IFS= read -r file; do
  n=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    n=$((n + 1))
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    check_line "$file" "$n" "$line"
  done <"$file"
done < <(find "$repo_root/install" "$repo_root/defaults" -type f -name 'run_*' 2>/dev/null | LC_ALL=C sort)

if [[ "$failed" -ne 0 ]]; then
  printf 'Unpinned installs in run_* scripts (see above).\n' >&2
fi
exit "$failed"
