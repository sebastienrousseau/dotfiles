#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Example: Installation and uninstall scripts
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

printf 'Installer: %s\n' "$repo_root/install.sh"
printf 'Uninstaller: %s\n' "$repo_root/scripts/uninstall.sh"
printf 'Version sync: %s\n' "$repo_root/version-sync.sh"

# Validate syntax
bash -n "$repo_root/install.sh" || { printf 'FAIL: install.sh\n' >&2; exit 1; }
bash -n "$repo_root/scripts/uninstall.sh" || { printf 'FAIL: uninstall.sh\n' >&2; exit 1; }

# Verify installer has help
if bash "$repo_root/install.sh" --help 2>&1 | grep -q 'Usage'; then
  printf 'Installer --help: OK\n'
else
  printf 'Installer --help: MISSING\n' >&2
  exit 1
fi
