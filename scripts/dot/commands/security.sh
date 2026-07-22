#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Dotfiles CLI - Security Commands
# backup, encrypt-check, firewall, telemetry, dns-doh, lock-screen, usb-safety

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../lib/dot/utils.sh
source "$SCRIPT_DIR/../../../lib/dot/utils.sh"

dot_ui_command_banner "Security" "${1:-}"

usage() {
  cat <<'EOF'
Usage: security.sh <command> [args...]

Commands:
  backup, encrypt-check, firewall, telemetry, dns-doh, lock-screen,
  usb-safety, policy
EOF
}

cmd_backup() {
  run_script "scripts/security/backup.sh" "Backup script" "$@"
}

cmd_encrypt_check() {
  run_script "scripts/security/encryption-check.sh" "Encryption check script" "$@"
}

cmd_firewall() {
  run_script "scripts/security/firewall.sh" "Firewall script" "$@"
}

cmd_telemetry() {
  run_script "scripts/security/telemetry-kill.sh" "Telemetry script" "$@"
}

cmd_dns_doh() {
  run_script "scripts/security/dns-doh.sh" "DNS DoH script" "$@"
}

cmd_lock_screen() {
  run_script "scripts/security/lock-screen.sh" "Lock screen script" "$@"
}

cmd_usb_safety() {
  run_script "scripts/security/usb-safety.sh" "USB safety script" "$@"
}

cmd_policy() {
  run_script "scripts/security/enforce-policies.sh" "Policy enforcement script" "$@"
}

# Dispatch
case "${1:-}" in
  --help | -h | help)
    usage
    ;;
  "")
    usage
    exit 1
    ;;
  backup)
    shift
    cmd_backup "$@"
    ;;
  encrypt-check)
    shift
    cmd_encrypt_check "$@"
    ;;
  firewall)
    shift
    cmd_firewall "$@"
    ;;
  telemetry)
    shift
    cmd_telemetry "$@"
    ;;
  dns-doh)
    shift
    cmd_dns_doh "$@"
    ;;
  lock-screen)
    shift
    cmd_lock_screen "$@"
    ;;
  usb-safety)
    shift
    cmd_usb_safety "$@"
    ;;
  policy)
    shift
    cmd_policy "$@"
    ;;
  *)
    echo "Unknown security command: ${1:-}" >&2
    exit 1
    ;;
esac
