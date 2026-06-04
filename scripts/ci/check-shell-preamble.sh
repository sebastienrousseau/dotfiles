#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Compat shim: the canonical script moved to tools/ci/ during the repo reorg.
# Pinned reusable workflows on master still reference the old path;
# this delegates so they keep working until the next pin bump.
set -euo pipefail
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/tools/ci/check-shell-preamble.sh" "$@"
