#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Fail when a chezmoi run_* script installs something that is not pinned.
#
# run_* scripts execute on `chezmoi apply`, so whatever they fetch runs with
# the user's privileges on every machine. Each install must name a version:
#   - no `@latest` (go install, mise use, npm);
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

# check_line <file> <n> <line>: the rules above, on one non-comment line.
check_line() {
  local file="$1" n="$2" line="$3"
  case "$line" in
    *@latest*) report "$file" "$n" "$line" "names @latest; pin an exact version" ;;
  esac
  if [[ "$line" =~ cargo[[:space:]]+install([[:space:]]|$) && ! "$line" =~ --list ]]; then
    [[ "$line" == *--locked* ]] || report "$file" "$n" "$line" "cargo install without --locked"
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
