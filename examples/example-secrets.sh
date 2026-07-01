#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Example: Encrypted secrets (age) management
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# --- dot secrets commands (age-encrypted; never committed in plaintext) ---
printf 'Initialise the age keypair:       dot secrets-init\n'
printf 'Create a new encrypted secret:    dot secrets-create\n'
printf 'Edit encrypted secrets in $EDITOR: dot secrets\n'
printf 'Verify encryption is in place:    dot encrypt-check\n'

# --- Underlying secrets scripts (repo source of truth) ---
printf 'Secrets manager:   %s\n' "$repo_root/scripts/security/manage-secrets.sh"
printf 'Secrets provider:  %s\n' "$repo_root/scripts/lib/secrets_provider.sh"

# Secrets are decrypted on-demand; the provider abstracts keychain / gpg /
# age backends so shells and scripts read secrets without plaintext on disk.
printf 'Backends: macOS Keychain, gpg, age (auto-detected by the provider).\n'

printf 'Secrets example complete.\n'
