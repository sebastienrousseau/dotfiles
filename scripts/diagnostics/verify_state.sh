#!/usr/bin/env bash
# MIT License
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# See LICENSE file for details.

# Script: verify_state.sh
# Description: Final verification of the dotfiles environment state.

set -euo pipefail

echo " Starting Final Environment Verification..."

Errors=0
ALIASES_CONFIG="$HOME/.config/shell/aliases.sh"
AliasesConfigReported=0

check_file() {
  if [[ ! -f "$1" ]]; then
    echo " Missing file: $1"
    Errors=$((Errors + 1))
  else
    echo " Found file: $1"
  fi
}

check_alias_in_config() {
  if [[ ! -f "$ALIASES_CONFIG" ]]; then
    if [[ "$AliasesConfigReported" -eq 0 ]]; then
      echo " Missing aliases config: $ALIASES_CONFIG"
      Errors=$((Errors + 1))
      AliasesConfigReported=1
    fi
  elif ! grep -q "$1" "$ALIASES_CONFIG"; then
    echo " Missing alias definition '$1' in built config"
    Errors=$((Errors + 1))
  else
    echo " Verified alias: $1"
  fi
}

# 1. Verify Docs
# Post-Phase-4b (v0.2.503): chezmoi source is under the subdir
# named in .chezmoiroot (typically "defaults/"). Paths without the
# prefix silently return "missing" from any CWD other than
# ~/.dotfiles/defaults/.
check_file "defaults/.chezmoitemplates/aliases/security/README.md"
check_file "defaults/.chezmoitemplates/aliases/legal/README.md"

# 2. Verify Scripts
check_file "scripts/security/lock-configs.sh"
check_file "scripts/tools/detect-collisions.py"
check_file "tests/test-aliases.sh"

# 3. Verify Generated Config Content (Key Features)
# Security
check_alias_in_config "lock-configs"
check_alias_in_config "unlock-configs"
check_alias_in_config "enable-signing"
# Legal
check_alias_in_config "scan-licenses"
check_alias_in_config "add-headers"

# 4. Verify Workflows
check_file ".github/workflows/security-release.yml"

if [[ $Errors -eq 0 ]]; then
  echo " Verification Passed! All systems nominal."
  exit 0
else
  echo "️  Verification Failed with $Errors errors."
  exit 1
fi
