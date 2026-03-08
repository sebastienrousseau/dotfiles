#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../dot/lib/ui.sh"
# shellcheck source=../dot/lib/platform.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../dot/lib/platform.sh"

ui_init
ui_header "DNS-over-HTTPS"

if [ "${DOTFILES_DOH:-}" != "1" ]; then
  ui_warn "DoH" "disabled by default"
  ui_info "Re-run" "DOTFILES_DOH=1"
  exit 1
fi

case "$(dot_platform_id)" in
  linux | wsl)
    if command -v resolvectl >/dev/null; then
      ui_info "Enabling" "systemd-resolved DoH (Cloudflare)"
      sudo resolvectl dns-over-https on
      sudo resolvectl dns 1.1.1.1 1.0.0.1
    else
      ui_err "systemd-resolved" "not detected"
      exit 1
    fi
    ;;
  macos)
    ui_info "Configure" "DoH in your browser"
    exit 0
    ;;
  *)
    ui_err "Unsupported OS" "DoH config"
    exit 1
    ;;
esac
