#!/usr/bin/env bash
# Dotfiles CLI - Security Commands
# backup, encrypt-check, firewall, telemetry, dns-doh, lock-screen, usb-safety

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"

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

# Dispatch
case "${1:-}" in
  backup) shift; cmd_backup "$@" ;;
  encrypt-check) shift; cmd_encrypt_check "$@" ;;
  firewall) shift; cmd_firewall "$@" ;;
  telemetry) shift; cmd_telemetry "$@" ;;
  dns-doh) shift; cmd_dns_doh "$@" ;;
  lock-screen) shift; cmd_lock_screen "$@" ;;
  usb-safety) shift; cmd_usb_safety "$@" ;;
  *) echo "Unknown security command: ${1:-}" >&2; exit 1 ;;
esac
