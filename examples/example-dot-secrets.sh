#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# Example: Encrypted secrets and SSH material
#
# Provider-agnostic secret storage, age-encrypted files and SSH certificates.
#
# Backing module: scripts/dot/commands/secrets.sh
# Feature matrix: docs/reference/FEATURE-MATRIX.md
#
# Runnable and side-effect free: every command below is read-only or a help
# render, and HOME is redirected into a throwaway directory first, so
# scripts/qa/validate-examples.sh can execute this on a real workstation.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dot="$repo_root/bin/dot"

sandbox="$(mktemp -d -t dot-example.XXXXXX)"
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/.config" "$sandbox/.local/share" "$sandbox/.local/state" \
  "$sandbox/.cache" "$sandbox/bin"
ln -sfn "$repo_root" "$sandbox/.dotfiles"
printf '#!/usr/bin/env bash\nexit 0\n' >"$sandbox/bin/chezmoi"
chmod +x "$sandbox/bin/chezmoi"

export HOME="$sandbox" \
  XDG_CONFIG_HOME="$sandbox/.config" \
  XDG_DATA_HOME="$sandbox/.local/share" \
  XDG_STATE_HOME="$sandbox/.local/state" \
  XDG_CACHE_HOME="$sandbox/.cache" \
  CHEZMOI_SOURCE_DIR="$repo_root" \
  PATH="$sandbox/bin:$PATH" \
  NO_COLOR=1 DOTFILES_SHOW_LOGO=0 DOTFILES_NO_TUI=1 \
  DOTFILES_NONINTERACTIVE=1 EDITOR=true PAGER=cat

printf '=== Encrypted secrets and SSH material ===\n\n'

# The commands this group provides. Each is shown with the one-line summary
# the CLI itself carries, so this example cannot drift from the registry.
for cmd in secrets secrets-init secrets-create ssh-key ssh-cert; do
  summary="$( (bash "$dot" help "$cmd" 2>/dev/null || true) |
    sed -n 's/.*Summary *//p' | head -1 || true)"
  printf '  dot %-22s %s\n' "$cmd" "${summary:-(see dot help all)}"
done

printf '\n--- live output ---\n\n'
bash "$dot" secrets provider || true
bash "$dot" secrets list 2>&1 | head -3 || true

printf '\nEncrypted secrets and SSH material example complete.\n'
