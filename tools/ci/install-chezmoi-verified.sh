#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Install a pinned Chezmoi release with checksum verification.
#
# The archive must match a SHA-256 pinned in this file (or CHEZMOI_SHA256,
# for a version not listed yet). The release's own checksums file is only a
# cross-check: it comes from the same place as the archive, so a replaced
# release would carry a matching one.
set -euo pipefail

VERSION="${1:-}"
BIN_DIR="${2:-$HOME/.local/bin}"

# chezmoi_pinned_sha256 <asset>: the reviewed SHA-256 of a release archive.
# Source: https://github.com/twpayne/chezmoi/releases/download/v2.73.3/chezmoi_2.73.3_checksums.txt
# (read 2026-10-08; matches the GitHub API asset digests). To add a release,
# copy its lines for these six archives from that file.
chezmoi_pinned_sha256() {
  case "$1" in
    chezmoi_2.73.3_linux_amd64.tar.gz) echo 6e5827598cbfc02d132b04f95b5ea10efb5b79230e2a4a0e52df4af144a8ee9f ;;
    chezmoi_2.73.3_linux_arm64.tar.gz) echo c9e6a6e71eb5291018e161a8426d7c313cd2e8553c2ca4029511fec2a33bc28c ;;
    chezmoi_2.73.3_darwin_amd64.tar.gz) echo d865487d6669243c948ee5542087bd95f4ad4ecb5a1311b85cf19f557694fe03 ;;
    chezmoi_2.73.3_darwin_arm64.tar.gz) echo ec2d0005f369c912ee9891a26c30d65dc0eda51708f06948e5f7a43db69e1aa7 ;;
    chezmoi_2.73.3_windows_amd64.zip) echo e74f9948a9ac6a5d8b0c0896a9ea129a766d92e38b50b70ee1fa1dc077755d6e ;;
    chezmoi_2.73.3_windows_arm64.zip) echo b49732852bb2f387dcb9379d742c3a6c3a908173a59e7981fd4da1572ca5ae7b ;;
    *) echo "${CHEZMOI_SHA256:-}" ;;
  esac
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# release_asset: the archive name for this OS and CPU. Git Bash on a Windows
# runner (uname MINGW64_NT-*) gets the zip that holds chezmoi.exe.
release_asset() {
  local os arch ext="tar.gz"
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  case "$os" in
    linux | darwin) ;;
    mingw* | msys* | cygwin*) os="windows" ext="zip" ;;
    *)
      echo "Unsupported OS: $os" >&2
      return 1
      ;;
  esac
  arch="$(uname -m)"
  case "$arch" in
    x86_64 | amd64) arch="amd64" ;;
    arm64 | aarch64) arch="arm64" ;;
    *)
      # chezmoi ships amd64 + arm64 builds only. Other architectures
      # (ppc64le, s390x, riscv64, armv7) would need a source build.
      echo "Unsupported architecture: $arch (only x86_64/amd64 and arm64/aarch64 are supported)" >&2
      echo "See https://github.com/twpayne/chezmoi/releases for the full asset list." >&2
      return 1
      ;;
  esac
  printf 'chezmoi_%s_%s_%s.%s\n' "$VERSION" "$os" "$arch" "$ext"
}

fetch() { curl --proto '=https' --tlsv1.2 -fsSL -o "$1" "$2"; }

# cross_check <dir> <base-url> <asset> <pin>: the release's checksums file
# (new or old name), when there is one, must not list another hash.
cross_check() {
  local published
  fetch "$1/checksums.txt" "$2/chezmoi_${VERSION}_checksums.txt" ||
    fetch "$1/checksums.txt" "$2/checksums.txt" || return 0
  published="$(awk -v f="$3" '$2 == f { print $1; exit }' "$1/checksums.txt")"
  if [[ -n "$published" && "$published" != "$4" ]]; then
    echo "Release checksums file disagrees with the pinned SHA-256 for $3" >&2
    return 1
  fi
}

# install_binary <dir> <asset>: extract chezmoi (or chezmoi.exe) into BIN_DIR.
install_binary() {
  mkdir -p "$BIN_DIR"
  if [[ "$2" == *.zip ]]; then
    unzip -q -o "$1/$2" chezmoi.exe -d "$1"
    install -m 755 "$1/chezmoi.exe" "$BIN_DIR/chezmoi.exe"
  else
    tar -xzf "$1/$2" -C "$1" chezmoi
    install -m 755 "$1/chezmoi" "$BIN_DIR/chezmoi"
  fi
}

main() {
  local asset base_url pinned actual
  if [[ -z "$VERSION" ]]; then
    echo "Usage: $0 <chezmoi-version> [bin-dir]" >&2
    return 1
  fi
  asset="$(release_asset)"
  base_url="https://github.com/twpayne/chezmoi/releases/download/v${VERSION}"
  pinned="$(chezmoi_pinned_sha256 "$asset")"
  if [[ ! "$pinned" =~ ^[0-9a-f]{64}$ ]]; then
    echo "No pinned SHA-256 for $asset." >&2
    echo "Add it to chezmoi_pinned_sha256 in $0, or export CHEZMOI_SHA256 from" >&2
    echo "$base_url/chezmoi_${VERSION}_checksums.txt after reviewing the release." >&2
    return 1
  fi
  TMP_DIR="$(umask 077 && mktemp -d)"
  trap 'rm -rf "$TMP_DIR"' EXIT
  fetch "$TMP_DIR/$asset" "$base_url/$asset"
  actual="$(sha256_of "$TMP_DIR/$asset")"
  if [[ "$actual" != "$pinned" ]]; then
    printf 'Checksum verification failed for %s\n  pinned: %s\n  actual: %s\n' "$asset" "$pinned" "$actual" >&2
    return 1
  fi
  cross_check "$TMP_DIR" "$base_url" "$asset" "$pinned"
  install_binary "$TMP_DIR" "$asset"
}

main
