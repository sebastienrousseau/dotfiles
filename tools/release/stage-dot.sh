#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau

set -euo pipefail

usage() {
  printf 'Usage: %s DESTINATION\n' "$(basename "$0")"
}

[[ $# -eq 1 ]] || {
  usage >&2
  exit 2
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
dest="$1"
[[ "$dest" != / && -n "$dest" ]] || {
  printf 'Refusing unsafe destination: %s\n' "$dest" >&2
  exit 2
}

rm -rf "$dest"
mkdir -p "$dest"/{bin,lib,share/man/man1,share/zsh/site-functions,share/bash-completion/completions,share/fish/vendor_completions.d}

cp "$repo_root/bin/dot" "$dest/bin/"
for file in "$repo_root"/bin/dot-*; do
  [[ -f "$file" ]] && cp "$file" "$dest/bin/"
done
cp "$repo_root/bin/dot.ps1" "$dest/bin/"
cp -R "$repo_root/lib/dot" "$dest/lib/"
cp -R "$repo_root/scripts" "$dest/"
cp -R "$repo_root/security" "$dest/"
cp -R "$repo_root/docs" "$dest/"
mkdir -p "$dest/defaults"
cp "$repo_root/defaults/.chezmoidata.toml" "$dest/defaults/"
cp -R "$repo_root/defaults/.chezmoidata" "$dest/defaults/"
cp -R "$repo_root/defaults/.chezmoitemplates" "$dest/defaults/"
cp -R "$repo_root/defaults/dot_config/dotfiles" "$dest/defaults/dot_config/"
cp -R "$repo_root/defaults/dot_claude" "$dest/defaults/"

cp "$repo_root/share/man/man1/dot.1" "$dest/share/man/man1/"
cp "$repo_root/share/completions/zsh/_dot" "$dest/share/zsh/site-functions/_dot"
cp "$repo_root/defaults/dot_local/share/bash-completion/completions/dot" "$dest/share/bash-completion/completions/dot"
cp "$repo_root/defaults/dot_config/fish/functions/dot.fish" "$dest/share/fish/vendor_completions.d/dot.fish"

chmod 0755 "$dest/bin/dot" "$dest"/bin/dot-* "$dest/scripts/uninstall.sh"

# A staged archive must be operational without a source checkout.
DOTFILES_NONINTERACTIVE=1 NO_COLOR=1 "$dest/bin/dot" version >/dev/null
DOTFILES_NONINTERACTIVE=1 NO_COLOR=1 "$dest/bin/dot" help >/dev/null
for command in apply doctor health perf tools theme fleet registry agents env; do
  DOTFILES_NONINTERACTIVE=1 NO_COLOR=1 "$dest/bin/dot" "$command" --help >/dev/null
done
