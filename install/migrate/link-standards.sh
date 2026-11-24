#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# Links ~/Code's standard files into the standards clone.
#
# Usage: link-standards.sh CLONE CODE
#
# The standards repository is the canonical source of AGENTS.md and its
# siblings. With a clone at CLONE (standards_repo in .chezmoidata.toml),
# each CODE/<file> becomes a symlink to CLONE/<file>: an edit in ~/Code is
# then a change in the clone, and nothing copies over it. A missing file,
# a copy identical to the clone's, or a link elsewhere is replaced by the
# link. A file that differs (edited in place) or a directory is kept and
# named; `standards-sync --pull` adopts such an edit into the clone. Without
# a clone it does nothing, and chezmoi installs plain copies instead. It
# never stops the apply.
# defaults/run_onchange_after_35-link-standards.sh.tmpl runs it.

set -euo pipefail

FILES=(AGENTS.md GEMINI.md PR-TEMPLATE.md README-TEMPLATE.md REPO-STANDARD.md)

# link_one SRC DST: make DST a symlink to SRC unless that would lose an edit.
link_one() {
  local src="$1" dst="$2"
  if [[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]; then
    return 0
  fi
  if [[ -L "$dst" || ! -e "$dst" ]] || { [[ -f "$dst" ]] && cmp -s "$src" "$dst"; }; then
    ln -sfn "$src" "$dst"
    echo "dot: linked ${dst} to ${src}"
    return 0
  fi
  echo "dot: kept ${dst}: it differs from ${src}; run 'standards-sync --pull' to adopt it into the clone, or remove it to link it" >&2
}

clone="${1:?usage: link-standards.sh CLONE CODE}"
code="${2:?usage: link-standards.sh CLONE CODE}"
[[ -d "$clone" && -d "$code" ]] || exit 0

for f in "${FILES[@]}"; do
  [[ -f "$clone/$f" ]] || continue
  link_one "$clone/$f" "$code/$f" || true
done
exit 0
