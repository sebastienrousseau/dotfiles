#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Sourced by scripts/verify-release-versions and scripts/version-sync.sh.
# The installer digest README.md documents for the v<version> download, in
# one place: scripts/verify-release-versions checks it and
# scripts/version-sync.sh writes it, so the two cannot disagree. Once the
# v<version> tag exists the published installer is install.sh at the tag, so
# a fix to install.sh between releases does not change the digest users check
# the download against. Before the tag (a release PR) it is install.sh as it
# stands. A shallow clone without the tag cannot tell the two apart.
#
# Bash 3.2 compatible (macOS /bin/bash).

[[ -n "${_DOT_INSTALLER_DIGEST_LOADED:-}" ]] && return 0
_DOT_INSTALLER_DIGEST_LOADED=1

# dot_installer_source <root> <version>: tag, tree, or unknown (a shallow
# clone of <root> without the v<version> tag). A <root> that is not the top
# of a git checkout is a tree.
dot_installer_source() {
  local root
  root="$(cd "$1" && pwd -P)"
  if [[ "$(git -C "$root" rev-parse --show-toplevel 2>/dev/null)" != "$root" ]]; then
    echo tree
  elif git -C "$root" rev-parse -q --verify "refs/tags/v$2" >/dev/null 2>&1; then
    echo tag
  elif [[ "$(git -C "$root" rev-parse --is-shallow-repository 2>/dev/null)" == true ]]; then
    echo unknown
  else
    echo tree
  fi
}

# _dot_sha256: the SHA-256 of standard input; nothing when neither tool exists.
_dot_sha256() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  fi
}

# dot_installer_digest <root> <version>: the SHA-256 of the installer
# published as v<version>; nothing when the source is unknown or there is no
# install.sh to hash.
dot_installer_digest() {
  case "$(dot_installer_source "$1" "$2")" in
    tag) git -C "$1" show "v$2:install.sh" | _dot_sha256 ;;
    tree) [[ ! -f "$1/install.sh" ]] || _dot_sha256 <"$1/install.sh" ;;
  esac
}
