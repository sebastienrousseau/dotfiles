#!/usr/bin/env bash
# MIT License
# Copyright (c) 2026 Sebastien Rousseau
# See LICENSE file for details.

# Script: doctor.sh
# Description: Diagnostics tool for the dotfiles environment.
# Checks dependencies, paths, and configuration integrity.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"

ui_init
ui_header "Dotfiles Doctor"
echo ""

Errors=0
Warnings=0

log_success() { ui_ok "$1" "${2:-}"; }
log_fail() { ui_err "$1" "${2:-}"; Errors=$((Errors + 1)); }
log_warn() { ui_warn "$1" "${2:-}"; Warnings=$((Warnings + 1)); }

# 1. Check Dependencies
ui_header "Core Dependencies"
for cmd in git curl chezmoi starship rg bat; do
  if command -v "$cmd" &>/dev/null; then
    log_success "$cmd" "$(command -v "$cmd")"
  else
    log_fail "$cmd" "Missing"
  fi
done

echo ""
ui_header "Optional AI CLIs"
for cmd in claude gemini sgpt ollama opencode aider; do
  if command -v "$cmd" &>/dev/null; then
    log_success "$cmd" "$(command -v "$cmd")"
  else
    log_warn "$cmd" "optional"
  fi
done

# 2. Check XDG Compliance
echo ""
ui_header "Environment"
if [[ -z "${XDG_CONFIG_HOME:-}" ]]; then
  log_warn "XDG_CONFIG_HOME" "Defaulting to ~/.config"
else
  log_success "XDG_CONFIG_HOME" "$XDG_CONFIG_HOME"
fi

if [[ -z "${PIPX_HOME:-}" ]]; then
  log_warn "PIPX_HOME" "Check paths configuration"
else
  log_success "PIPX_HOME" "$PIPX_HOME"
fi

# 3. Check Chezmoi State
echo ""
ui_header "Chezmoi State"
if chezmoi verify &>/dev/null; then
  log_success "Chezmoi state" "synchronized"
else
  log_fail "Chezmoi state" "drifted (run 'dot drift')"
fi

# 4. Check Critical Files
echo ""
ui_header "Critical Files"
if [[ -f "$HOME/.zshrc" ]]; then
  log_success ".zshrc" "present"
else
  log_fail ".zshrc" "missing"
fi

# 5. Check for Broken Symlinks (Ghost Links)
echo ""
ui_header "Broken Symlinks"
broken_links=0
while IFS= read -r -d '' link; do
  if [[ ! -e "$link" ]]; then
    log_warn "Broken symlink" "$link -> $(readlink "$link")"
    broken_links=$((broken_links + 1))
  fi
done < <(find "$HOME" -maxdepth 3 -type l -print0 2>/dev/null)

if [[ $broken_links -eq 0 ]]; then
  log_success "Broken symlinks" "none"
else
  log_warn "Broken symlinks" "$broken_links detected"
fi

# Summary
echo ""
ui_header "Summary"
if [[ $Errors -eq 0 ]]; then
  if [[ $Warnings -eq 0 ]]; then
    ui_ok "All systems healthy"
  else
    ui_warn "System healthy" "$Warnings warnings"
  fi
else
  ui_err "Issues found" "$Errors errors, $Warnings warnings"
  echo "Run 'dot heal' to attempt auto-repair."
  exit 1
fi
