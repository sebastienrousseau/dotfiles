#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
# shellcheck source=../dot/lib/ui.sh
source "$REPO_ROOT/scripts/dot/lib/ui.sh"

ui_logo_dot "Dot DNS • DoH"

if [[ "${DOTFILES_DOH:-}" != "1" ]]; then
  ui_warn "DoH script is disabled by default."
  ui_info "Re-run with DOTFILES_DOH=1 to apply."
  exit 1
fi

case "$(uname -s)" in
  Linux)
    if command -v resolvectl >/dev/null; then
      ui_info "Enabling DNS-over-HTTPS with systemd-resolved (Cloudflare)..."
      sudo resolvectl dns-over-https on
      sudo resolvectl dns 1.1.1.1 1.0.0.1
    else
      ui_error "systemd-resolved not detected."
      exit 1
    fi
    ;;
  Darwin)
    ui_info "Configure DoH in your browser (system-wide DoH requires profiles)."
    exit 0
    ;;
  *)
    ui_error "Unsupported OS for DoH config."
    exit 1
    ;;
esac
