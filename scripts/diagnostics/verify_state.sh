#!/usr/bin/env bash
# MIT License
# Copyright (c) 2026 Sebastien Rousseau
# See LICENSE file for details.

# Script: verify_state.sh
# Description: Final verification of the dotfiles environment state.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"

ui_logo_dot "Dot Verify • State"

Errors=0

check_file() {
  if [[ ! -f "$1" ]]; then
    ui_error "Missing file: $1"
    Errors=$((Errors + 1))
  else
    ui_success "Found file: $1"
  fi
}

check_alias_in_config() {
  if ! grep -q "$1" "$HOME/.config/shell/aliases.sh"; then
    ui_error "Missing alias definition '$1' in built config"
    Errors=$((Errors + 1))
  else
    ui_success "Verified alias: $1"
  fi
}

# 1. Verify Docs
ui_section "Docs"
check_file ".chezmoitemplates/aliases/security/README.md"
check_file ".chezmoitemplates/aliases/legal/README.md"

# 2. Verify Scripts
ui_section "Scripts"
check_file "scripts/security/lock-configs.sh"
check_file "scripts/tools/detect-collisions.py"
check_file "scripts/tests/test-aliases.sh"

# 3. Verify Generated Config Content (Key Features)
# Security
ui_section "Aliases"
check_alias_in_config "lock-configs"
check_alias_in_config "unlock-configs"
check_alias_in_config "enable-signing"
# Legal
check_alias_in_config "scan-licenses"
check_alias_in_config "add-headers"

# 4. Verify Workflows
ui_section "Workflows"
check_file ".github/workflows/security-release.yml"

if [[ $Errors -eq 0 ]]; then
  ui_success "Verification Passed! All systems nominal."
  exit 0
else
  ui_error "Verification Failed with $Errors errors."
  exit 1
fi
