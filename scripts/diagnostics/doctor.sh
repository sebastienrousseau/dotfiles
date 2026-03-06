#!/usr/bin/env bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
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
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../dot/lib/ui.sh"
# shellcheck source=../dot/lib/platform.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../dot/lib/platform.sh"

ui_init
ui_header "Dotfiles Doctor"
echo ""

Errors=0
Warnings=0
AI_DEBUG=0

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --ai) AI_DEBUG=1 ;;
  esac
done

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

# Helper to check command (mise-aware)
check_cmd() {
  local cmd="$1"
  if command -v "$cmd" &>/dev/null; then
    return 0
  fi
  # Fallback: check if installed via mise
  if command -v mise &>/dev/null; then
    # Search for common names or aqua names
    if mise ls --installed 2>/dev/null | grep -qE "($cmd|aqua:.*$cmd)"; then
      return 0
    fi
  fi
  return 1
}

get_cmd_path() {
  local cmd="$1"
  if command -v "$cmd" &>/dev/null; then
    command -v "$cmd"
  elif command -v mise &>/dev/null; then
    # Try to find the actual install path with better precision
    local bin_path
    bin_path=$(mise bin-paths 2>/dev/null | grep -E "/$cmd(/|$)" | head -n 1)
    if [ -n "$bin_path" ]; then
      echo "$bin_path/$cmd"
    else
      echo "$cmd"
    fi
  else
    echo "$cmd"
  fi
}

# 1. Check Dependencies
if command -v gum >/dev/null 2>&1; then
  gum style --foreground 212 --border-foreground 212 --border double --align center --width 50 "Dotfiles Doctor"
  echo ""
fi

ui_header "Core Shells"
for cmd in zsh fish nu starship; do
  if command -v gum >/dev/null 2>&1; then
    gum spin --spinner dot --title "Checking $cmd..." -- sleep 0.1
  fi
  if check_cmd "$cmd"; then
    log_success "$cmd" "$(get_cmd_path "$cmd")"
  else
    if [[ "$cmd" == "nu" || "$cmd" == "fish" ]]; then
      log_warn "$cmd" "Optional but recommended for 2026 stack"
    else
      log_fail "$cmd" "Missing"
    fi
  fi
done

echo ""
ui_header "Modern CLI Tools"
# Extend PATH to include common non-standard install locations
export PATH="$HOME/.atuin/bin:$HOME/.local/bin:$PATH"
for cmd in rg bat chezmoi fzf zoxide atuin yazi zellij; do
  if check_cmd "$cmd"; then
    log_success "$cmd" "$(get_cmd_path "$cmd")"
  elif [[ "$cmd" == "bat" ]] && check_cmd "batcat"; then
    log_success "$cmd" "$(get_cmd_path "batcat") (batcat)"
  else
    log_fail "$cmd" "Missing"
  fi
done

echo ""
ui_header "The 2026 Frontier"
for cmd in pueue wasmtime nix sops age; do
  if check_cmd "$cmd"; then
    log_success "$cmd" "$(get_cmd_path "$cmd")"
  else
    if [[ "$cmd" == "nix" ]]; then
      log_warn "$cmd" "Frontier tool missing (run: curl -L https://nixos.org/nix/install | sh)"
    else
      log_warn "$cmd" "Frontier tool missing"
    fi
  fi
done

if check_cmd pueue; then
  if "$(get_cmd_path pueue)" status >/dev/null 2>&1; then
    log_success "pueue daemon" "running"
  else
    log_warn "pueue daemon" "not running (run 'pueued -d')"
  fi
fi

echo ""
ui_header "Optional AI CLIs"
for cmd in claude gemini sgpt ollama opencode aider kiro-cli; do
  if check_cmd "$cmd"; then
    log_success "$cmd" "$(get_cmd_path "$cmd")"
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
    # Skip known false positives (e.g., Chrome lock files in backups)
    [[ "$link" == *"google-chrome-backup"* ]] && continue

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

# 7. Ghost Path Linter (Portability check)
echo ""
ui_header "Ghost Path Linter"
ghost_paths=0
if [[ -d "$HOME/.config" ]]; then
  # Scan for hardcoded home directory literals, ignoring known false positives
  ghost_lines=$(grep -rIE '"/home/(linuxbrew)?[^$]|/Users/[^$]' "$HOME/.config" |
    grep -v "linuxbrew" |
    grep -v "/mozilla/firefox" |
    grep -v "/google-chrome" |
    grep -v "/chromium" |
    grep -v "/chezmoi/chezmoi.toml" |
    grep -v "/bun/" |
    grep -v "/noctalia/" |
    grep -v -- "-backup/" ||
    true)
  if [[ -n "$ghost_lines" ]]; then
    ghost_paths=$(echo "$ghost_lines" | wc -l)
    log_warn "Ghost paths" "$ghost_paths hardcoded literals found in ~/.config"
    if [[ "$ghost_paths" -lt 5 ]]; then
      echo "    ${ghost_lines//$'\n'/$'\n'    }"
    fi
  else
    log_success "Portability" "No hardcoded home paths found in ~/.config"
  fi
fi

# 8. Check dot command resolution
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
ui_header "Performance Audit"
if command -v hyperfine >/dev/null 2>&1; then
  if bash "$SCRIPT_DIR/../tests/performance/bench.sh"; then
    log_success "Startup latency" "Within 50ms threshold"
  else
    log_fail "Startup latency" "Threshold exceeded"
  fi
else
  log_warn "hyperfine" "missing (performance audit skipped)"
fi

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

  if [[ $AI_DEBUG -eq 1 ]]; then
    ui_header "AI Problem Analysis"
    doctor_report=$(~/.local/bin/dot doctor | grep -E "(\[FAIL\]|\[WARN\]|✗|⚠)")

    ai_prompt="The dotfiles diagnostic 'dot doctor' found the following issues:
---
$doctor_report
---
Suggest specific shell commands to fix these issues according to our architectural standards."

    # Use the bridge
    dot cl --pattern hardener "$ai_prompt"
  else
    echo "Run 'dot heal' to attempt auto-repair."
  fi
  exit 1
fi
