#!/usr/bin/env bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"
# shellcheck source=../dot/lib/platform.sh
source "$SCRIPT_DIR/../dot/lib/platform.sh"

ui_init
ui_header "Encryption Check"

case "$(dot_platform_id)" in
  macos)
    if command -v fdesetup >/dev/null; then
      status=$(fdesetup status || true)
      echo "$status"
      echo "$status" | grep -qi "FileVault is On" && {
        ui_ok "FileVault" "On"
        exit 0
      }
      ui_warn "FileVault" "appears to be off"
      exit 1
    else
      ui_err "fdesetup" "not found"
      exit 1
    fi
    ;;
  linux | wsl)
    if command -v lsblk >/dev/null; then
      lsblk_output=$(lsblk -f)
      if command -v rg >/dev/null; then
        if echo "$lsblk_output" | rg -i "crypto|luks" >/dev/null; then
          ui_ok "LUKS" "encrypted block device detected"
          exit 0
        fi
      else
        if echo "$lsblk_output" | grep -Ei "crypto|luks" >/dev/null; then
          ui_ok "LUKS" "encrypted block device detected"
          exit 0
        fi
      fi
      ui_warn "LUKS" "no crypto volume detected"
      exit 1
    fi
    ;;
  *)
    ui_err "Unsupported OS" "encryption check"
    exit 1
    ;;
esac
