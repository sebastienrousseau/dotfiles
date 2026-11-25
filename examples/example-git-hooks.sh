#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

printf 'Hook installer: %s\n' "$repo_root/scripts/git-hooks/install.sh"
printf 'Pre-push gate: %s\n' "$repo_root/scripts/git-hooks/pre-push"
