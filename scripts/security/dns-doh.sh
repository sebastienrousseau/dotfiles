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

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in --dry-run | -n) DRY_RUN=1 ;; esac
done
_run_cmd() {
  if [[ "$DRY_RUN" -eq 1 ]]; then ui_info "[dry-run]" "$*"; else "$@"; fi
}

ui_init
ui_header "DNS-over-HTTPS"

if [[ "$DRY_RUN" -eq 1 ]]; then
  ui_info "Mode" "dry-run (no changes will be made)"
elif [ "${DOTFILES_DOH:-}" != "1" ]; then
  ui_warn "DoH" "disabled by default"
  ui_info "Re-run" "DOTFILES_DOH=1"
  exit 1
fi

case "$(dot_platform_id)" in
  linux | wsl)
    if command -v resolvectl >/dev/null; then
      ui_info "Enabling" "systemd-resolved DoH (Cloudflare)"
      _run_cmd sudo resolvectl dns-over-https on
      _run_cmd sudo resolvectl dns 1.1.1.1 1.0.0.1
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
