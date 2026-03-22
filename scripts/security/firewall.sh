#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
## Configure system firewall with secure defaults.
##
## Enables firewall with deny-by-default policy and minimal exceptions.
## Requires explicit opt-in via DOTFILES_FIREWALL=1 to prevent accidental
## lockouts.
##
## # Usage
## DOTFILES_FIREWALL=1 dot firewall
##
## # Dependencies
## - macOS: socketfilterfw (built-in)
## - Linux: ufw (Uncomplicated Firewall)
##
## # Platform Notes
## ### Platform: macOS
## - Enables Application Firewall via socketfilterfw
## - Enables stealth mode (no ICMP responses)
## - Allows signed applications
##
## ### Platform: Linux
## - Configures UFW with deny incoming / allow outgoing
## - Allows OpenSSH to prevent lockout
## - Requires ufw package installed
##
## # Security
## **Requires sudo.** All changes logged to dotfiles.log.
##
## # Side Effects
## - Modifies system firewall rules
## - May block existing connections
##
## # Idempotency
## Safe to run repeatedly. Applies same rules each time.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../dot/lib/ui.sh"
# shellcheck source=../dot/lib/platform.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../dot/lib/platform.sh"

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in --dry-run | -n) DRY_RUN=1 ;; esac
done
_run_cmd() {
  if [[ "$DRY_RUN" -eq 1 ]]; then ui_info "[dry-run]" "$*"; else "$@"; fi
}

ui_init
ui_header "Firewall"

if [[ "$DRY_RUN" -eq 1 ]]; then
  ui_info "Mode" "dry-run (no changes will be made)"
elif [ "${DOTFILES_FIREWALL:-}" != "1" ]; then
  ui_warn "Firewall" "disabled by default"
  ui_info "Re-run" "DOTFILES_FIREWALL=1"
  exit 1
fi

case "$(dot_platform_id)" in
  macos)
    ui_info "Enabling" "macOS firewall"
    _run_cmd sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
    _run_cmd sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned on
    _run_cmd sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsignedapp on
    _run_cmd sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
    ;;
  linux | wsl)
    if command -v ufw >/dev/null; then
      ui_info "Enabling" "UFW"
      _run_cmd sudo ufw default deny incoming
      _run_cmd sudo ufw default allow outgoing
      _run_cmd sudo ufw allow OpenSSH
      _run_cmd sudo ufw --force enable
    else
      ui_err "ufw" "not installed; re-run after install"
      exit 1
    fi
    ;;
  *)
    ui_err "Unsupported OS" "firewall setup"
    exit 1
    ;;
esac
