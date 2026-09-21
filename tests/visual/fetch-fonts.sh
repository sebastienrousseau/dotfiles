#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
set -euo pipefail
destination="${1:?Usage: fetch-fonts.sh NEW_DESTINATION}"
[[ ! -e "$destination" ]] || {
  echo 'Refusing to overwrite an existing directory' >&2
  exit 1
}
mkdir -m 700 "$destination"
base=https://raw.githubusercontent.com/ryanoasis/nerd-fonts/fa7b859994228a9c8759f99c55a8d31ee92a1b5e/patched-fonts/JetBrainsMono/Ligatures
for weight in Regular Bold; do
  curl --proto '=https' --tlsv1.2 --fail --location --silent --show-error \
    --max-time 90 --retry 2 "$base/$weight/JetBrainsMonoNerdFontMono-$weight.ttf" \
    -o "$destination/JetBrainsMonoNerdFontMono-$weight.ttf"
done
manifest="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/fonts.sha256"
if command -v sha256sum >/dev/null 2>&1; then
  (cd "$destination" && sha256sum -c "$manifest")
else
  (cd "$destination" && shasum -a 256 -c "$manifest")
fi
