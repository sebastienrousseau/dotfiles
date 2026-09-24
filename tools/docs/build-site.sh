#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Build doc.dotfiles.io with ssg and the vendored Lucid theme
# (docs/site/themes/lucid): the documentation pages listed in docs/_toc.yml,
# the landing page from docs/index.md, and the manual under /manual/.
#
# Usage: tools/docs/build-site.sh [--out DIR]
#
# Needs ssg >= 0.0.63 on PATH (or SSG=/path/to/ssg) and python3.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$REPO_ROOT/_build/site"
SITE_URL="https://doc.dotfiles.io"
MIN_SSG="0.0.63"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)
      [[ $# -ge 2 ]] || {
        echo "build-site: --out needs a directory" >&2
        exit 64
      }
      OUT="$2"
      shift 2
      ;;
    -h | --help)
      sed -n '4,10p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "build-site: unknown argument: $1" >&2
      exit 64
      ;;
  esac
done

SSG="${SSG:-ssg}"
command -v "$SSG" >/dev/null 2>&1 || {
  echo "build-site: ssg not found (install: cargo install ssg --locked, or set SSG=)" >&2
  exit 127
}
version="$("$SSG" --version | awk '{print $2}')"
if [[ "$(printf '%s\n%s\n' "$MIN_SSG" "$version" | sort -V | head -n 1)" != "$MIN_SSG" ]]; then
  echo "build-site: ssg $version is older than $MIN_SSG" >&2
  exit 1
fi

work="$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-site.XXXXXX")"
trap 'rm -rf "$work"' EXIT

builder="$REPO_ROOT/tools/docs/build-manual-site.py"
python3 "$builder" prepare-site "$REPO_ROOT/docs" "$work/content"

cat >"$work/ssg.toml" <<EOF
site_name = ".dotfiles"
site_title = ".dotfiles — cross-platform, signed dotfiles"
site_description = "Cross-platform, signed, local-first dotfiles for macOS, Linux, WSL and PowerShell."
base_url = "${SITE_URL}/"
language = "en-GB"
content_dir = "$work/content"
template_dir = "$REPO_ROOT/docs/site/themes/lucid/_layouts"
output_dir = "$work/out"
EOF
"$SSG" build -f "$work/ssg.toml" --quiet

# The manual is its own ssg build (its own contents and pager) published
# under /manual/ of the same site.
bash "$REPO_ROOT/tools/docs/build-manual-site.sh" --out "$work/out/manual"

# Heading ids, then one link check across the whole site: docs pages,
# the landing page and the manual.
python3 "$builder" finalize "$work/out" "/"
cp "$REPO_ROOT/docs/CNAME" "$work/out/CNAME"

rm -rf "$OUT"
mkdir -p "$(dirname "$OUT")"
mv "$work/out" "$OUT"
echo "site: built with ssg $version into $OUT"
