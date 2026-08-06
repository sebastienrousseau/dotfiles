#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Sourced by installer and provisioning scripts; inherits set -euo pipefail

[[ "${_DOT_VERIFIED_DOWNLOAD_LOADED:-0}" == "1" ]] && return 0
_DOT_VERIFIED_DOWNLOAD_LOADED=1

_dot_sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    printf 'SHA-256 verifier not found (need sha256sum or shasum)\n' >&2
    return 127
  fi
}

_dot_installer_manifest() {
  if [[ -n "${DOTFILES_INSTALLER_MANIFEST:-}" ]]; then
    printf '%s\n' "$DOTFILES_INSTALLER_MANIFEST"
    return
  fi
  local lib_dir
  lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  printf '%s/security/remote-installers.sha256\n' "$(cd "$lib_dir/../.." && pwd)"
}

download_verified_script() (
  local url="$1"
  local destination="$2"
  local max_bytes="${3:-524288}"
  local user_agent="${4:-dotfiles-verified-bootstrap/1}"
  local manifest expected actual size

  [[ "$url" == https://* ]] || {
    printf 'Refusing non-HTTPS installer URL: %s\n' "$url" >&2
    return 2
  }
  manifest="$(_dot_installer_manifest)"
  [[ -r "$manifest" ]] || {
    printf 'Installer checksum manifest not readable: %s\n' "$manifest" >&2
    return 2
  }
  expected="$(awk -v url="$url" '$2 == url {print $1; exit}' "$manifest")"
  [[ "$expected" =~ ^[0-9a-f]{64}$ ]] || {
    printf 'Installer URL is not checksum-pinned: %s\n' "$url" >&2
    return 2
  }

  umask 077
  if ! curl --proto '=https' --tlsv1.2 -fsSL -A "$user_agent" -o "$destination" "$url"; then
    rm -f "$destination"
    return 1
  fi
  size="$(wc -c <"$destination" | tr -d ' ')"
  if ((size == 0 || size > max_bytes)); then
    printf 'Installer size outside allowed range: %s bytes (%s)\n' "$size" "$url" >&2
    rm -f "$destination"
    return 1
  fi
  actual="$(_dot_sha256_file "$destination")" || {
    rm -f "$destination"
    return 1
  }
  if [[ "$actual" != "$expected" ]]; then
    printf 'Installer checksum mismatch: %s\nExpected: %s\nActual:   %s\n' "$url" "$expected" "$actual" >&2
    rm -f "$destination"
    return 1
  fi
  if ! head -n 1 "$destination" | grep -q '^#!'; then
    printf 'Verified artifact is not an executable script: %s\n' "$url" >&2
    rm -f "$destination"
    return 1
  fi
)

download_verified_asset() (
  local url="$1"
  local checksum_url="$2"
  local asset_name="$3"
  local destination="$4"
  local max_bytes="${5:-104857600}"
  local checksum_file expected actual size

  [[ "$url" == https://* && "$checksum_url" == https://* ]] || {
    printf 'Refusing non-HTTPS release asset URL\n' >&2
    return 2
  }
  [[ "$asset_name" != */* && -n "$asset_name" ]] || {
    printf 'Invalid release asset name: %s\n' "$asset_name" >&2
    return 2
  }

  checksum_file="$(mktemp -t dot-checksums.XXXXXX)"
  trap 'rm -f "$checksum_file"' EXIT
  umask 077
  if ! curl --proto '=https' --tlsv1.2 -fsSL -o "$checksum_file" "$checksum_url"; then
    rm -f "$destination"
    return 1
  fi
  if (($(wc -c <"$checksum_file" | tr -d '[:space:]') > 2097152)); then
    printf 'Checksum manifest exceeds the 2 MiB safety limit\n' >&2
    rm -f "$destination"
    return 1
  fi
  expected="$(awk -v asset="$asset_name" '{ name=$2; sub(/^\*/, "", name); if (name == asset) print $1 }' "$checksum_file")"
  [[ "$expected" =~ ^[0-9a-f]{64}$ ]] || {
    printf 'Release asset is absent or ambiguous in checksum manifest: %s\n' "$asset_name" >&2
    rm -f "$destination"
    return 1
  }
  if ! curl --proto '=https' --tlsv1.2 -fsSL -o "$destination" "$url"; then
    rm -f "$destination"
    return 1
  fi
  size="$(wc -c <"$destination" | tr -d '[:space:]')"
  if ((size == 0 || size > max_bytes)); then
    printf 'Release asset size outside allowed range: %s bytes (%s)\n' "$size" "$url" >&2
    rm -f "$destination"
    return 1
  fi
  actual="$(_dot_sha256_file "$destination")" || {
    rm -f "$destination"
    return 1
  }
  if [[ "$actual" != "$expected" ]]; then
    printf 'Release asset checksum mismatch: %s\n' "$asset_name" >&2
    rm -f "$destination"
    return 1
  fi
)
