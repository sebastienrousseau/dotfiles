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
# Source: https://github.com/twpayne/chezmoi/releases/download/v2.72.2/chezmoi_2.72.2_checksums.txt
# (read 2026-10-08; matches the GitHub API asset digests). To add a release,
# copy its lines for these six archives from that file.
chezmoi_pinned_sha256() {
  case "$1" in
    chezmoi_2.72.2_linux_amd64.tar.gz) echo a2be1b8bcdf06c6f173e070bb3ddbcc52c50478fe9b57f6e6c63d15c7cff4f03 ;;
    chezmoi_2.72.2_linux_arm64.tar.gz) echo 499925fd10804b7c1a5dc4b4a275c8935261d02a4be0c18bbd41b7747810de67 ;;
    chezmoi_2.72.2_darwin_amd64.tar.gz) echo 08ad1ba33a73e68f7657ee226f72b5d800b5a947954b06e185e8591bd32b0063 ;;
    chezmoi_2.72.2_darwin_arm64.tar.gz) echo 2b0c7e57f3f2da44628fa9f6863b9bd41f0935cfd2416228aa9df6daab6690f5 ;;
    chezmoi_2.72.2_windows_amd64.zip) echo 5c2038736c485d4e3eaad4ac06ea1fe3c4b63d4d51e470547bf12737c02f37f6 ;;
    chezmoi_2.72.2_windows_arm64.zip) echo 831c6e354975bca78c93833db09af027d1e68171b306f3ab0a546f00ea809d2e ;;
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
