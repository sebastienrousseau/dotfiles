#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
# shellcheck source=../dot/lib/ui.sh
source "$REPO_ROOT/scripts/dot/lib/ui.sh"

ui_logo_dot "Dot Firewall • Security"

if [[ "${DOTFILES_FIREWALL:-}" != "1" ]]; then
  ui_warn "Firewall script is disabled by default."
  ui_info "Re-run with DOTFILES_FIREWALL=1 to apply."
  exit 1
fi

case "$(uname -s)" in
  Darwin)
    ui_info "Enabling macOS firewall..."
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned on
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsignedapp on
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
    ;;
  Linux)
    if command -v ufw >/dev/null; then
      ui_info "Enabling UFW..."
      sudo ufw default deny incoming
      sudo ufw default allow outgoing
      sudo ufw allow OpenSSH
      sudo ufw --force enable
    else
      ui_error "ufw not installed. Install ufw and re-run."
      exit 1
    fi
    ;;
  *)
    ui_error "Unsupported OS for firewall setup."
    exit 1
    ;;
esac
