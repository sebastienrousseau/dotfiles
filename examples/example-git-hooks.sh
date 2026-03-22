#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

printf 'Hook installer: %s\n' "$repo_root/scripts/git-hooks/install.sh"
printf 'Pre-push gate: %s\n' "$repo_root/scripts/git-hooks/pre-push"
