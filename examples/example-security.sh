#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Example: Security operations and hardening scripts
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

printf 'Firewall: %s\n' "$repo_root/scripts/security/firewall.sh"
printf 'DNS DoH: %s\n' "$repo_root/scripts/security/dns-doh.sh"
printf 'Encryption check: %s\n' "$repo_root/scripts/security/encryption-check.sh"
printf 'Enforce policies: %s\n' "$repo_root/scripts/security/enforce-policies.sh"
printf 'Lock configs: %s\n' "$repo_root/scripts/security/lock-configs.sh"
printf 'Lock screen: %s\n' "$repo_root/scripts/security/lock-screen.sh"
printf 'Manage secrets: %s\n' "$repo_root/scripts/security/manage-secrets.sh"
printf 'SSH certificates: %s\n' "$repo_root/scripts/security/ssh-cert.sh"
printf 'Telemetry kill: %s\n' "$repo_root/scripts/security/telemetry-kill.sh"
printf 'USB safety: %s\n' "$repo_root/scripts/security/usb-safety.sh"
printf 'Backup: %s\n' "$repo_root/scripts/security/backup.sh"

# Validate all security scripts have valid syntax
for script in "$repo_root"/scripts/security/*.sh; do
  bash -n "$script" || { printf 'FAIL: %s\n' "$script" >&2; exit 1; }
done
printf 'All %d security scripts pass syntax check.\n' "$(find "$repo_root/scripts/security" -name "*.sh" | wc -l | tr -d ' ')"
