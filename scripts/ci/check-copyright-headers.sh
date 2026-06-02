#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Compat shim: the canonical script moved to tools/ci/ during the repo reorg.
# Pinned reusable workflows on master still reference the old path;
# this delegates so they keep working until the next pin bump.
set -euo pipefail
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/tools/ci/check-copyright-headers.sh" "$@"
