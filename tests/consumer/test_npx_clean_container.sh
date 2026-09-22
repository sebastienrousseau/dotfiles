#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
set -euo pipefail

# Explicit container lane only: native integration runners need not have Docker.
# No home/repository/token/socket bind mounts enter this clean consumer container.
# This is a real package fetch + installer execution, not `npx --help` or a mock.
image="${DOT_NPX_TEST_IMAGE:-node@sha256:0e0ff40c39bc087845bfb27465a0df4ea419520094bc35842ff83dd8cbe6f9b6}"
version="${1:-0.2.522}"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 2
docker run --rm --security-opt no-new-privileges --env DOT_TEST_VERSION="$version" \
  "$image" bash -euo pipefail -c '
    apt-get update -qq
    apt-get install -y --no-install-recommends ca-certificates curl git unzip
    test ! -e /root/.dotfiles
    export DOTFILES_NONINTERACTIVE=1 DOTFILES_SILENT=1
    npx --yes --package="@sebastienrousseau/dotfiles@$DOT_TEST_VERSION" \
      dotfiles-install "v$DOT_TEST_VERSION" --minimal --force --silent
    test -d /root/.dotfiles/.git
    test "$(git -C /root/.dotfiles describe --tags --exact-match HEAD)" = "v$DOT_TEST_VERSION"
    test -x /root/.local/bin/dot
    /root/.local/bin/dot version | grep -F "$DOT_TEST_VERSION"
    /root/.local/bin/dot --help >/dev/null
    echo "PASS: real npm package, pinned source, minimal apply and installed CLI"
  '
