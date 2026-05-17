#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Compat shim: the canonical script moved to tools/ci/ in v0.2.503.
# Pinned reusable workflows on master still reference the old path;
# this delegates so they keep working until the next pin bump.
set -euo pipefail
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/tools/ci/guard-gitleaks-checkout.sh" "$@"
