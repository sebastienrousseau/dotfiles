#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Build the web manual (doc.dotfiles.io/manual/) with ssg and the vendored
# Lucid theme in docs/manual-site/themes/lucid.
#
# Usage: tools/docs/build-manual-site.sh [--out DIR] [--base-path /manual/]
#
# Needs ssg >= 0.0.63 on PATH (or SSG=/path/to/ssg) and python3.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$REPO_ROOT/_build/manual-site"
BASE_PATH="/manual/"
SITE_URL="https://doc.dotfiles.io"
MIN_SSG="0.0.63"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)
      OUT="$2"
      shift 2
      ;;
    --base-path)
      BASE_PATH="$2"
      shift 2
      ;;
    -h | --help)
      sed -n '4,9p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "build-manual-site: unknown argument: $1" >&2
      exit 64
      ;;
  esac
done
[[ "$BASE_PATH" == /*/ || "$BASE_PATH" == / ]] || {
  echo "build-manual-site: --base-path must start and end with '/'" >&2
  exit 64
}

SSG="${SSG:-ssg}"
command -v "$SSG" >/dev/null 2>&1 || {
  echo "build-manual-site: ssg not found (install: cargo install ssg --locked, or set SSG=)" >&2
  exit 127
}
version="$("$SSG" --version | awk '{print $2}')"
if [[ "$(printf '%s\n%s\n' "$MIN_SSG" "$version" | sort -V | head -n 1)" != "$MIN_SSG" ]]; then
  echo "build-manual-site: ssg $version is older than $MIN_SSG" >&2
  exit 1
fi

work="$(mktemp -d "${TMPDIR:-/tmp}/manual-site.XXXXXX")"
trap 'rm -rf "$work"' EXIT

python3 "$REPO_ROOT/tools/docs/build-manual-site.py" prepare \
  "$REPO_ROOT/docs/manual" "$work/content" "$BASE_PATH"

cat >"$work/ssg.toml" <<EOF
site_name = ".dotfiles Manual"
site_title = ".dotfiles Manual"
site_description = "The .dotfiles manual: a trusted agent workstation for macOS, Linux, WSL and PowerShell."
base_url = "${SITE_URL}${BASE_PATH}"
language = "en-GB"
content_dir = "$work/content"
template_dir = "$REPO_ROOT/docs/manual-site/themes/lucid/_layouts"
output_dir = "$work/out"
EOF

"$SSG" build -f "$work/ssg.toml" --quiet

python3 "$REPO_ROOT/tools/docs/build-manual-site.py" finalize "$work/out" "$BASE_PATH"

rm -rf "$OUT"
mkdir -p "$(dirname "$OUT")"
mv "$work/out" "$OUT"
echo "manual: built with ssg $version into $OUT"
