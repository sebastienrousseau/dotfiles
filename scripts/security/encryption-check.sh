#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
# shellcheck source=../dot/lib/ui.sh
source "$REPO_ROOT/scripts/dot/lib/ui.sh"

ui_logo_dot "Dot Encryption • Check"

case "$(uname -s)" in
  Darwin)
    if command -v fdesetup >/dev/null; then
      status=$(fdesetup status || true)
      ui_info "$status"
      echo "$status" | grep -qi "FileVault is On" && exit 0
      ui_warn "FileVault appears to be off."
      exit 1
    else
      ui_error "fdesetup not found."
      exit 1
    fi
    ;;
  Linux)
    if command -v lsblk >/dev/null; then
      lsblk_output=$(lsblk -f)
      if command -v rg >/dev/null; then
        if echo "$lsblk_output" | rg -i "crypto|luks" >/dev/null; then
          ui_success "Encrypted block device detected (LUKS)."
          exit 0
        fi
      else
        if echo "$lsblk_output" | grep -Ei "crypto|luks" >/dev/null; then
          ui_success "Encrypted block device detected (LUKS)."
          exit 0
        fi
      fi
      ui_warn "No LUKS/crypto volume detected."
      exit 1
    fi
    ;;
  *)
    ui_error "Unsupported OS for encryption check."
    exit 1
    ;;
esac
