#!/usr/bin/env bash
# MIT License
# Copyright (c) 2026 Sebastien Rousseau
# See LICENSE file for details.

# Script: doctor.sh
# Description: Diagnostics tool for the dotfiles environment.
# Checks dependencies, paths, and configuration integrity.

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo " Dotfiles Doctor - System Diagnostics"
echo "-------------------------------------"

Errors=0
Warnings=0

log_success() { echo -e "${GREEN} $1${NC}"; }
log_fail() {
  echo -e "${RED} $1${NC}"
  Errors=$((Errors + 1))
}
log_warn() {
  echo -e "${YELLOW}️  $1${NC}"
  Warnings=$((Warnings + 1))
}

# 1. Check Dependencies
echo "Checking Core Dependencies..."
for cmd in git curl chezmoi starship rg bat; do
  if command -v "$cmd" &>/dev/null; then
    log_success "Found $cmd: $(command -v "$cmd")"
  else
    log_fail "Missing $cmd"
  fi
done

echo -e "\nChecking Optional AI CLIs..."
for cmd in claude gemini sgpt ollama opencode; do
  if command -v "$cmd" &>/dev/null; then
    log_success "Found $cmd: $(command -v "$cmd")"
  else
    log_warn "Missing $cmd (optional)"
  fi
done

# 2. Check XDG Compliance
echo -e "\nChecking Environment..."
if [[ -z "${XDG_CONFIG_HOME:-}" ]]; then
  log_warn "XDG_CONFIG_HOME is not set (Defaulting to ~/.config)"
else
  log_success "XDG_CONFIG_HOME=$XDG_CONFIG_HOME"
fi

if [[ -z "${PIPX_HOME:-}" ]]; then
  log_warn "PIPX_HOME is not set (Check paths configuration)"
else
  log_success "PIPX_HOME=$PIPX_HOME"
fi

# 3. Check Chezmoi State
echo -e "\nChecking Chezmoi State..."
if chezmoi verify &>/dev/null; then
  log_success "Chezmoi state is synchronized"
else
  log_fail "Chezmoi state has drifted (Run 'dot drift' to see details)"
fi

# 4. Check Critical Files
echo -e "\nChecking Critical Files..."
if [[ -f "$HOME/.zshrc" ]]; then
  log_success "Found .zshrc"
else
  log_fail "Missing .zshrc"
fi

# 5. Check for Broken Symlinks (Ghost Links)
echo -e "\nChecking for Broken Symlinks..."
broken_links=0
while IFS= read -r -d '' link; do
  if [[ ! -e "$link" ]]; then
    log_warn "Broken symlink: $link -> $(readlink "$link")"
    broken_links=$((broken_links + 1))
  fi
done < <(find "$HOME" -maxdepth 3 -type l -print0 2>/dev/null)

if [[ $broken_links -eq 0 ]]; then
  log_success "No broken symlinks found"
else
  log_warn "$broken_links broken symlink(s) detected"
fi

# Summary
echo -e "\n-------------------------------------"
if [[ $Errors -eq 0 ]]; then
  if [[ $Warnings -eq 0 ]]; then
    echo -e "${GREEN}All systems healthy! ${NC}"
  else
    echo -e "${YELLOW}System healthy with $Warnings warnings.${NC}"
  fi
else
  echo -e "${RED}Found $Errors errors and $Warnings warnings.${NC}"
  echo "Run 'dot heal' to attempt auto-repair."
  exit 1
fi
