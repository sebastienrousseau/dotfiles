#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# =============================================================================
# install-kcov-verified.sh — Build + install a pinned kcov release with
# SHA256-verified source download. Closes the CI plumbing gap from
# Slice 1 of #856's coverage roadmap.
#
# Why this script: Ubuntu 24.04 dropped `kcov` from the universe repo
# in late 2024. The previous coverage workflow's `apt-get install -y
# kcov` therefore fails on ubuntu-latest (which now resolves to
# 24.04). This script:
#
#   1. Installs the build-time apt deps documented in the upstream
#      INSTALL.md.
#   2. Downloads the kcov vN source tarball from GitHub.
#   3. Verifies the tarball SHA256 against an embedded pin (the same
#      defence-in-depth pattern install-chezmoi-verified.sh uses).
#   4. Builds with cmake + make and installs to a user-controlled
#      prefix so the workflow can cache the result.
#
# Usage:
#   install-kcov-verified.sh [PREFIX]
#
#   PREFIX defaults to $HOME/.local. The resulting binary lives at
#   $PREFIX/bin/kcov.
# =============================================================================

set -euo pipefail

KCOV_VERSION="${KCOV_VERSION:-43}"
# SHA256 of github.com/SimonKagstrom/kcov/archive/refs/tags/v43.tar.gz
# Bump this in lockstep with KCOV_VERSION.
KCOV_TARBALL_SHA256="${KCOV_TARBALL_SHA256:-4cbba86af11f72de0c7514e09d59c7927ed25df7cebdad087f6d3623213b95bf}"

PREFIX="${1:-$HOME/.local}"
BIN="$PREFIX/bin/kcov"

mkdir -p "$PREFIX/bin"

# Fast path — already cached at the right version.
if [[ -x "$BIN" ]]; then
  installed_version=$("$BIN" --version 2>/dev/null | head -1 | awk '{print $NF}' | sed 's/^v//')
  if [[ "$installed_version" == "$KCOV_VERSION" ]]; then
    echo "kcov v$KCOV_VERSION already installed at $BIN"
    "$BIN" --version
    exit 0
  fi
  echo "Cached kcov version ($installed_version) ≠ requested ($KCOV_VERSION) — rebuilding."
fi

# Install build-time dependencies. Ubuntu 24.04 ships libstdc++-13.
# (Upstream INSTALL.md says libstdc++-12 — the version suffix tracks
# the default g++ ABI; both work for kcov's build.)
if command -v apt-get >/dev/null 2>&1; then
  echo "Installing kcov build deps via apt..."
  sudo apt-get update -qq
  sudo apt-get install -y --no-install-recommends \
    binutils-dev build-essential cmake \
    libssl-dev libcurl4-openssl-dev libelf-dev libdw-dev \
    libstdc++-13-dev zlib1g-dev libiberty-dev \
    python3
else
  echo "::warning::apt-get not available — assuming build deps are pre-installed."
fi

# Download + verify the tarball.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

tarball="$work/kcov-v${KCOV_VERSION}.tar.gz"
url="https://github.com/SimonKagstrom/kcov/archive/refs/tags/v${KCOV_VERSION}.tar.gz"

echo "Fetching $url ..."
curl -fsSL --retry 3 -o "$tarball" "$url"

actual_sha=$(sha256sum "$tarball" | awk '{print $1}')
if [[ "$actual_sha" != "$KCOV_TARBALL_SHA256" ]]; then
  cat >&2 <<EOF
::error::kcov tarball SHA256 mismatch.
  expected: $KCOV_TARBALL_SHA256
  actual:   $actual_sha
Refusing to build untrusted source.
EOF
  exit 1
fi
echo "SHA256 verified: $actual_sha"

# Extract + build.
tar -C "$work" -xzf "$tarball"
src_dir="$work/kcov-${KCOV_VERSION}"
build_dir="$src_dir/build"
mkdir -p "$build_dir"
cd "$build_dir"

echo "Configuring kcov via cmake..."
cmake -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_BUILD_TYPE=Release ..

# Detect available cores portably.
if command -v nproc >/dev/null 2>&1; then
  jobs=$(nproc)
elif command -v sysctl >/dev/null 2>&1; then
  jobs=$(sysctl -n hw.ncpu 2>/dev/null || echo 1)
else
  jobs=1
fi

echo "Building kcov with -j$jobs ..."
make -j"$jobs"

echo "Installing to $PREFIX ..."
make install

echo "kcov v$KCOV_VERSION installed:"
"$BIN" --version
