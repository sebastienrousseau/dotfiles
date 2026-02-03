#!/usr/bin/env bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
# SPDX-License-Identifier: MIT
#
# Shared installer functions for binary downloads with SHA256 verification.
# Source this file after logging.sh.

set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_DOTFILES_INSTALLERS_LOADED:-}" ]]; then
    return 0
fi
_DOTFILES_INSTALLERS_LOADED=1

# Resolve sudo command (empty string if already root)
resolve_sudo() {
    if [ "$(id -u)" -ne 0 ]; then
        if command -v sudo >/dev/null; then
            echo "sudo"
        else
            die "This script requires root privileges or sudo for system installs."
        fi
    fi
}

# Compute SHA256 checksum of a file
sha256_file() {
    local file="$1"
    if command -v sha256sum >/dev/null; then
        sha256sum "$file" | awk '{print $1}'
    elif command -v shasum >/dev/null; then
        shasum -a 256 "$file" | awk '{print $1}'
    else
        die "sha256sum or shasum is required for verified downloads."
    fi
}

# Download a file and verify its SHA256 checksum against a checksum file
download_and_verify_sha256() {
    local url="$1"
    local checksum_url="$2"
    local dest="$3"

    curl -fsSL -o "$dest" "$url"
    curl -fsSL -o "${dest}.sha256" "$checksum_url"

    local expected actual
    expected="$(awk '{print $1}' "${dest}.sha256")"
    actual="$(sha256_file "$dest")"
    if [ -z "$expected" ] || [ "$expected" != "$actual" ]; then
        die "Checksum verification failed for $dest."
    fi
}

# Fetch GitHub release JSON for a repo/tag
github_release_json() {
    local repo="$1"
    local tag="${2:-latest}"
    local auth_header=()
    if [ -n "${GITHUB_TOKEN:-}" ]; then
        auth_header=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
    fi
    if [ "$tag" = "latest" ]; then
        curl -fsSL "${auth_header[@]}" "https://api.github.com/repos/$repo/releases/latest"
    else
        curl -fsSL "${auth_header[@]}" "https://api.github.com/repos/$repo/releases/tags/$tag"
    fi
}

# Resolve the download URL for a GitHub release asset
github_asset_url() {
    local repo="$1"
    local suffix="$2"
    local tag="${3:-latest}"
    local url
    url="$(github_release_json "$repo" "$tag" 2>/dev/null | grep -oE "https://[^\"]+${suffix}" | head -n1)"
    if [ -n "$url" ]; then
        echo "$url"
        return 0
    fi
    if [ "$tag" = "latest" ]; then
        echo "https://github.com/${repo}/releases/latest/download/${suffix}"
    else
        echo "https://github.com/${repo}/releases/download/${tag}/${suffix}"
    fi
}

# Fail if a version tag is unpinned (latest/nightly)
warn_unpinned() {
    local name="$1"
    local tag="$2"
    local var_name="$3"
    if [ "$tag" = "latest" ] || [ "$tag" = "nightly" ]; then
        die "${name} uses moving tag '${tag}'. Pin by setting ${var_name}."
    fi
}

# Download, verify, extract a tarball and install one binary
install_from_tarball() {
    local url="$1"
    local checksum_url="$2"
    local bin_name="$3"
    local install_dir="$4"

    local tmp_dir
    tmp_dir="$(mktemp -d)"
    download_and_verify_sha256 "$url" "$checksum_url" "$tmp_dir/archive.tar.gz"
    tar -xzf "$tmp_dir/archive.tar.gz" -C "$tmp_dir"

    local bin_path
    bin_path="$tmp_dir/$bin_name"
    if [ ! -f "$bin_path" ]; then
        bin_path="$(find "$tmp_dir" -type f -name "$bin_name" -perm -u+x 2>/dev/null | head -n1)"
    fi
    if [ -z "$bin_path" ] || [ ! -f "$bin_path" ]; then
        rm -rf "$tmp_dir"
        die "Expected binary $bin_name not found in archive."
    fi
    mkdir -p "$install_dir"
    install -m 0755 "$bin_path" "$install_dir/$bin_name"
    rm -rf "$tmp_dir"
}

# Download, verify, extract a tarball using a multi-file checksums.txt
install_from_tarball_checksums() {
    local url="$1"
    local checksums_url="$2"
    local bin_name="$3"
    local install_dir="$4"

    local tmp_dir
    tmp_dir="$(mktemp -d)"
    curl -fsSL -o "$tmp_dir/archive.tar.gz" "$url"
    curl -fsSL -o "$tmp_dir/checksums.txt" "$checksums_url"

    local expected actual
    expected="$(awk -v f="$(basename "$url")" '$2==f {print $1}' "$tmp_dir/checksums.txt")"
    actual="$(sha256_file "$tmp_dir/archive.tar.gz")"
    if [ -z "$expected" ] || [ "$expected" != "$actual" ]; then
        rm -rf "$tmp_dir"
        die "Checksum verification failed for $bin_name."
    fi
    tar xf "$tmp_dir/archive.tar.gz" -C "$tmp_dir"

    local bin_path
    bin_path="$(find "$tmp_dir" -type f -name "$bin_name" -perm -u+x 2>/dev/null | head -n1)"
    if [ -z "$bin_path" ]; then
        bin_path="$tmp_dir/$bin_name"
    fi
    if [ ! -f "$bin_path" ]; then
        rm -rf "$tmp_dir"
        die "Expected binary $bin_name not found in archive."
    fi
    mkdir -p "$install_dir"
    install -m 0755 "$bin_path" "$install_dir/$bin_name"
    rm -rf "$tmp_dir"
}

# Download and verify a zip archive, extract and install binaries
install_from_zip() {
    local url="$1"
    local checksum_url="$2"
    local install_dir="$3"
    shift 3
    local bin_names=("$@")

    local tmp_dir
    tmp_dir="$(mktemp -d)"
    curl -fsSL -o "$tmp_dir/archive.zip" "$url"
    curl -fsSL -o "$tmp_dir/archive.zip.sha256" "$checksum_url"

    local expected actual
    expected="$(awk '{print $1}' "$tmp_dir/archive.zip.sha256")"
    actual="$(sha256_file "$tmp_dir/archive.zip")"
    if [ -z "$expected" ] || [ "$expected" != "$actual" ]; then
        rm -rf "$tmp_dir"
        die "Checksum verification failed for zip archive."
    fi
    unzip -o "$tmp_dir/archive.zip" -d "$tmp_dir"
    mkdir -p "$install_dir"

    local bin_name bin_path
    for bin_name in "${bin_names[@]}"; do
        bin_path="$(find "$tmp_dir" -type f -name "$bin_name" -perm -u+x 2>/dev/null | head -n1)"
        if [ -n "$bin_path" ]; then
            install -m 0755 "$bin_path" "$install_dir/$bin_name"
        else
            log_warn "$bin_name not found in zip archive."
        fi
    done
    rm -rf "$tmp_dir"
}

# Resolve architecture to a target triple fragment
resolve_arch() {
    local arch
    arch="$(uname -m)"
    case "$arch" in
        x86_64 | amd64) echo "x86_64" ;;
        aarch64 | arm64) echo "aarch64" ;;
        *) die "Unsupported architecture: $arch" ;;
    esac
}
