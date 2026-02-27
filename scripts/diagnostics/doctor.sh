#!/usr/bin/env bash
# Copyright (c) 2015-2026 . All rights reserved.
## Dotfiles Doctor.
##
## Diagnoses dotfiles environment health by checking dependencies, paths,
## and configuration integrity. Reports errors, warnings, and suggests
## remediation steps.
##
## # Usage
## dot doctor
##
## # Dependencies
## - chezmoi: Dotfiles manager (required)
## - starship: Prompt (optional)
## - rg, bat: Modern CLI tools (optional)
##
## # Platform Notes
## - macOS: Checks Homebrew-installed tools
## - Linux: Checks apt/nix-installed tools
## - WSL: Checks Windows interop paths
##
## # Exit Codes
## - 0: All checks passed (may have warnings)
## - 1: Critical errors detected
##
## # Idempotency
## Safe to run repeatedly. Read-only checks.
##
## MIT License - Copyright (c) 2026 

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"
# shellcheck source=../dot/lib/platform.sh
source "$SCRIPT_DIR/../dot/lib/platform.sh"

ui_init
ui_header "Dotfiles Doctor"
echo ""

Errors=0
Warnings=0

log_success() { ui_ok "$1" "${2:-}"; }
log_fail() {
  ui_err "$1" "${2:-}"
  Errors=$((Errors + 1))
}
log_warn() {
  ui_warn "$1" "${2:-}"
  Warnings=$((Warnings + 1))
}

log_info() { ui_info "$1" "${2:-}"; }

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

# 3. Platform Abstraction
echo ""
ui_header "Platform"
platform_id="$(dot_platform_id)"
log_success "Runtime platform" "$platform_id"
log_success "Host platform" "$(dot_host_os)"

if [[ "$platform_id" == "wsl" ]]; then
  if command -v wslpath >/dev/null 2>&1; then
    log_success "WSL bridge" "wslpath available"
  else
    log_warn "WSL bridge" "wslpath missing (path conversion degraded)"
  fi

  if [[ "$PWD" == /mnt/* ]]; then
    log_warn "WSL filesystem" "running under /mnt can cause major IO latency"
  else
    log_success "WSL filesystem" "running on Linux filesystem"
  fi
fi

# 4. Check Chezmoi State
echo ""
ui_header "Chezmoi State"
if chezmoi verify &>/dev/null; then
  log_success "Chezmoi state" "synchronized"
else
  log_fail "Chezmoi state" "drifted (run 'dot drift')"
fi

# 5. Check Critical Files
echo ""
ui_header "Critical Files"
if [[ -f "$HOME/.zshrc" ]]; then
  log_success ".zshrc" "present"
else
  log_fail ".zshrc" "missing"
fi

# 6. Check for Broken Symlinks (Ghost Links)
echo ""
ui_header "Broken Symlinks"
broken_links=0
checked_roots=0
for root in "$HOME/.config" "$HOME/.local/bin" "$HOME/.local/share" "$HOME/.ssh"; do
  [[ -d "$root" ]] || continue
  checked_roots=$((checked_roots + 1))
  while IFS= read -r -d '' link; do
    if [[ ! -e "$link" ]]; then
      log_warn "Broken symlink" "$link -> $(readlink "$link")"
      broken_links=$((broken_links + 1))
    fi
  done < <(find "$root" -maxdepth 3 -type l -print0 2>/dev/null)
done

if [[ $checked_roots -eq 0 ]]; then
  log_info "Broken symlink scan" "no standard roots found"
fi

if [[ $broken_links -eq 0 ]]; then
  log_success "Broken symlinks" "none"
else
  log_warn "Broken symlinks" "$broken_links detected"
fi

# 7. Check dot command resolution
echo ""
ui_header "CLI Resolution"
if command -v dot >/dev/null 2>&1; then
  dot_path="$(command -v dot)"
  if [[ "$dot_path" == "$HOME/.local/bin/dot" ]]; then
    log_success "dot command" "$dot_path"
  else
    log_warn "dot command" "$dot_path (expected $HOME/.local/bin/dot)"
  fi
else
  log_fail "dot command" "not found in PATH"
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
