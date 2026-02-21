#!/usr/bin/env bash
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
source "$SCRIPT_DIR/../dot/lib/ui.sh"

ui_init
ui_header "Firewall"

if [ "${DOTFILES_FIREWALL:-}" != "1" ]; then
  ui_warn "Firewall" "disabled by default"
  ui_info "Re-run" "DOTFILES_FIREWALL=1"
  exit 1
fi

case "$(uname -s)" in
  Darwin)
    ui_info "Enabling" "macOS firewall"
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned on
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsignedapp on
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
    ;;
  Linux)
    if command -v ufw >/dev/null; then
      ui_info "Enabling" "UFW"
      sudo ufw default deny incoming
      sudo ufw default allow outgoing
      sudo ufw allow OpenSSH
      sudo ufw --force enable
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
