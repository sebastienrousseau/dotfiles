#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# Compatibility wrapper. The canonical name for this gate is
# `scripts/verify-release-versions` (the name the repository standard
# uses); this path is kept so existing callers — the `version-consistency`
# pre-commit hook, older docs, muscle memory — keep working.
#
# Do not add logic here. Edit scripts/verify-release-versions.
set -euo pipefail
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts/verify-release-versions" "$@"
