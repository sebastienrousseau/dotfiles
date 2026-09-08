#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
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
dest_name="$(basename "$dest")"
# Refuse anything that does not look like a staging/libexec directory:
# this script rm -rf's its destination. Accepted basenames are the
# release layout (dot, dot-<version>), the bundle name, and the
# `make install` libexec name (dotfiles, i.e. $(PREFIX)/lib/dotfiles).
[[ "$dest" != / && "$dest" != . && -n "$dest" &&
  ("$dest_name" == "dot" || "$dest_name" == dot-* || "$dest_name" == "bundle" || "$dest_name" == "dotfiles") ]] || {
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
cp "$repo_root/tools/release/Makefile.dist" "$dest/Makefile"
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

# Man page and completions are BUILD PRODUCTS of the command registry
# in bin/dot — generated here rather than copied, so a staged tree can
# never ship a page or completion that drifted from the CLI it wraps.
# (The committed copies under share/ exist for chezmoi-deployed users
# and are drift-checked against these same generators in CI.)
bash "$repo_root/tools/docs/generate-manpage.sh" --output "$dest/share/man/man1/dot.1" >/dev/null
for shell in zsh bash fish; do
  case "$shell" in
    zsh) target="$dest/share/zsh/site-functions/_dot" ;;
    bash) target="$dest/share/bash-completion/completions/dot" ;;
    fish) target="$dest/share/fish/vendor_completions.d/dot.fish" ;;
  esac
  CHEZMOI_SOURCE_DIR="$repo_root" DOTFILES_NONINTERACTIVE=1 NO_COLOR=1 \
    bash "$repo_root/bin/dot" completion "$shell" >"$target"
done

chmod 0755 "$dest/bin/dot" "$dest"/bin/dot-* "$dest/scripts/uninstall.sh"

# A staged archive must be operational without a source checkout.
DOTFILES_NONINTERACTIVE=1 NO_COLOR=1 "$dest/bin/dot" version >/dev/null
DOTFILES_NONINTERACTIVE=1 NO_COLOR=1 "$dest/bin/dot" help >/dev/null
for command in apply doctor health perf tools theme fleet registry agents env; do
  DOTFILES_NONINTERACTIVE=1 NO_COLOR=1 "$dest/bin/dot" "$command" --help >/dev/null
done
