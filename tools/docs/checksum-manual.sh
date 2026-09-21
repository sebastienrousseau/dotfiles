#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Emit checksums for the public manual assets, never build intermediates.
# Usage: bash tools/docs/checksum-manual.sh BUILD_DIR [--fast]
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 || ($# -eq 2 && $2 != --fast) ]]; then
  printf 'Usage: %s BUILD_DIR [--fast]\n' "$0" >&2
  exit 2
fi
cd "$1"

assets=(
  dotfiles.epub
  dotfiles.html
  dotfiles.html.gz
  dotfiles.txt
  dotfiles.txt.gz
  dotfiles-md.tar.gz
  html.tar.gz
  search-index.json
)
if [[ ${2:-} != --fast ]]; then
  assets+=(dotfiles.pdf)
fi

# Fail before emitting a partial manifest; links and empty outputs are not
# successful builds. Fast mode deliberately excludes any stale local PDF.
for asset in "${assets[@]}"; do
  if [[ ! -f "$asset" || ! -s "$asset" || -L "$asset" ]]; then
    printf 'Missing, empty, or linked manual asset: %s\n' "$asset" >&2
    exit 1
  fi
done

# Choose once. A failed hash operation must not append a second implementation's
# output to a partial manifest and mask the original error.
if command -v sha256sum >/dev/null 2>&1; then
  sha256sum "${assets[@]}"
else
  shasum -a 256 "${assets[@]}"
fi
