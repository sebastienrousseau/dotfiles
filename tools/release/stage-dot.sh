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
# stage_tree SRC DEST: the libraries, scripts, bundled plugins (P2.1),
# security data, docs and the defaults the CLI reads at run time.
stage_tree() {
  cp -R "$1/lib/dot" "$2/lib/"
  cp -R "$1/scripts" "$1/plugins" "$1/security" "$1/docs" "$2/"
  mkdir -p "$2/defaults"
  cp "$1/defaults/.chezmoidata.toml" "$2/defaults/"
  cp -R "$1/defaults/.chezmoidata" "$1/defaults/.chezmoitemplates" "$1/defaults/dot_claude" "$2/defaults/"
  cp -R "$1/defaults/dot_config/dotfiles" "$2/defaults/dot_config/"
}
stage_tree "$repo_root" "$dest"

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
# stage_entry_smoke DEST: --help never reaches a plugin's entry (P2.1), so
# run one for real, in a throwaway HOME; a bundle without plugins/ fails.
stage_entry_smoke() {
  local home
  home="$(mktemp -d)"
  HOME="$home" DOTFILES_NONINTERACTIVE=1 NO_COLOR=1 DOTFILES_SHOW_LOGO=0 \
    "$1/bin/dot" fleet status </dev/null >/dev/null
  rm -rf "$home"
}
stage_entry_smoke "$dest"
