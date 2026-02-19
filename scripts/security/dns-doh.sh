#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"

ui_init
ui_header "DNS-over-HTTPS"

if [ "${DOTFILES_DOH:-}" != "1" ]; then
  ui_warn "DoH" "disabled by default"
  ui_info "Re-run" "DOTFILES_DOH=1"
  exit 1
fi

case "$(uname -s)" in
  Linux)
    if command -v resolvectl >/dev/null; then
      ui_info "Enabling" "systemd-resolved DoH (Cloudflare)"
      sudo resolvectl dns-over-https on
      sudo resolvectl dns 1.1.1.1 1.0.0.1
    else
      ui_err "systemd-resolved" "not detected"
      exit 1
    fi
    ;;
  Darwin)
    ui_info "Configure" "DoH in your browser"
    exit 0
    ;;
  *)
    ui_err "Unsupported OS" "DoH config"
    exit 1
    ;;
esac
