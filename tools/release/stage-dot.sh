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
cp -R "$repo_root/plugins" "$dest/"
cp -R "$repo_root/security" "$dest/"
cp -R "$repo_root/docs" "$dest/"
mkdir -p "$dest/defaults"
cp "$repo_root/defaults/.chezmoidata.toml" "$dest/defaults/"
cp -R "$repo_root/defaults/.chezmoidata" "$dest/defaults/"
cp -R "$repo_root/defaults/.chezmoitemplates" "$dest/defaults/"
cp -R "$repo_root/defaults/dot_config/dotfiles" "$dest/defaults/dot_config/"
cp -R "$repo_root/defaults/dot_claude" "$dest/defaults/"

# The man page is a BUILD PRODUCT of the command registry in bin/dot,
# generated here so a staged tree never ships a page that drifted from
# the CLI it wraps. The completions are generated from the plugin
# manifests and committed (CI fails when one is stale), so the staged
# tree takes the committed files through `dot cli completion show`.
bash "$repo_root/tools/docs/generate-manpage.sh" --output "$dest/share/man/man1/dot.1" >/dev/null
for shell in zsh bash fish; do
  case "$shell" in
    zsh) target="$dest/share/zsh/site-functions/_dot" ;;
    bash) target="$dest/share/bash-completion/completions/dot" ;;
    fish) target="$dest/share/fish/vendor_completions.d/dot.fish" ;;
  esac
  CHEZMOI_SOURCE_DIR="$repo_root" DOTFILES_NONINTERACTIVE=1 NO_COLOR=1 \
    bash "$repo_root/bin/dot" cli completion show "$shell" >"$target"
done

chmod 0755 "$dest/bin/dot" "$dest"/bin/dot-* "$dest/scripts/uninstall.sh"

# A staged archive must be operational without a source checkout.
DOTFILES_NONINTERACTIVE=1 NO_COLOR=1 "$dest/bin/dot" version >/dev/null
DOTFILES_NONINTERACTIVE=1 NO_COLOR=1 "$dest/bin/dot" help >/dev/null
# One spelling per domain (ADR-020), so a retired name cannot fail the stage.
for command in apply doctor "doctor status" "doctor perf show" "tool list" theme fleet "cli list" "agent context" tool; do
  # shellcheck disable=SC2086 # a spelling is words
  DOTFILES_NONINTERACTIVE=1 NO_COLOR=1 "$dest/bin/dot" $command --help >/dev/null
done
# --help never reaches a plugin's entry (P2.1), so run one for real, in a
# throwaway HOME: a bundle without plugins/ fails here.
smoke_home="$(mktemp -d)"
HOME="$smoke_home" DOTFILES_NONINTERACTIVE=1 NO_COLOR=1 DOTFILES_SHOW_LOGO=0 \
  "$dest/bin/dot" fleet status </dev/null >/dev/null
rm -rf "$smoke_home"
