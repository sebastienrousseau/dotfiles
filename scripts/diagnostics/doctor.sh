#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
## Dotfiles Doctor.
##
## Diagnoses dotfiles environment health by checking dependencies, paths,
## and configuration integrity. Reports errors, warnings, and suggests
## remediation steps.
##
## # Usage
## dot doctor
##
## # Exit Codes
## - 0: All checks passed (may have warnings)
## - 1: Critical errors detected
##
## # Idempotency
## Safe to run repeatedly. Read-only checks.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../dot/lib/ui.sh"
# shellcheck source=../dot/lib/platform.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../dot/lib/platform.sh"
# shellcheck source=../dot/lib/log.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../dot/lib/log.sh"
export DOT_COMMAND="doctor"

ui_init

# Extend PATH to include common non-standard install locations
export PATH="$HOME/.atuin/bin:$HOME/.local/bin:$PATH"

Errors=0
Warnings=0
AI_DEBUG=0

for arg in "$@"; do
  case "$arg" in
    --ai) AI_DEBUG=1 ;;
  esac
done

# --- Output helpers (delegate to shared ui.sh) ---
_ok() { ui_ok "$1" "${2:-}"; }
_fail() {
  ui_err "$1" "${2:-}"
  Errors=$((Errors + 1))
}
_warn() {
  ui_warn "$1" "${2:-}"
  Warnings=$((Warnings + 1))
}
_section() {
  echo ""
  ui_section "$1"
}

pretty_path() {
  local value="${1:-}"
  if [[ -n "$value" ]]; then
    printf '%s' "${value/#$HOME/\~}"
  fi
}

tool_source() {
  local path="${1:-}"
  if [[ "$path" == "$HOME/.local/share/mise/"* ]]; then
    echo "mise"
  elif [[ "$path" == /usr/bin/* || "$path" == /bin/* || "$path" == /usr/sbin/* || "$path" == /sbin/* ]]; then
    echo "system"
  else
    echo "custom"
  fi
}

check_cmd() {
  local cmd="$1"
  if command -v "$cmd" &>/dev/null; then return 0; fi
  if command -v mise &>/dev/null; then
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

# --- Header ---
ui_header "Dotfiles Doctor"

# --- Core Shells ---
_section "Core Shells"
for cmd in zsh fish starship; do
  if check_cmd "$cmd"; then
    cmd_path="$(get_cmd_path "$cmd")"
    _ok "$cmd" "$(pretty_path "$cmd_path") ($(tool_source "$cmd_path"))"
  elif [[ "$cmd" == "fish" ]]; then
    _warn "$cmd" "optional"
  else
    _fail "$cmd" "missing"
  fi
done

if check_cmd "nu"; then
  cmd_path="$(get_cmd_path "nu")"
  _ok "nu" "$(pretty_path "$cmd_path") ($(tool_source "$cmd_path"))"
elif check_cmd "nushell"; then
  cmd_path="$(get_cmd_path "nushell")"
  _ok "nu" "$(pretty_path "$cmd_path") ($(tool_source "$cmd_path"))"
else
  _warn "nu" "optional"
fi

# --- Modern CLI Tools ---
_section "Modern CLI Tools"
for cmd in rg bat chezmoi fzf zoxide atuin yazi zellij; do
  if check_cmd "$cmd"; then
    _ok "$cmd" "$(pretty_path "$(get_cmd_path "$cmd")")"
  elif [[ "$cmd" == "bat" ]] && check_cmd "batcat"; then
    _ok "$cmd" "$(pretty_path "$(get_cmd_path "batcat")") (batcat)"
  else
    _fail "$cmd" "missing"
  fi
done

# --- Infrastructure ---
_section "Infrastructure"
for cmd in pueue wasmtime nix sops age hyperfine; do
  if check_cmd "$cmd"; then
    _ok "$cmd" "$(pretty_path "$(get_cmd_path "$cmd")")"
  elif [[ "$cmd" == "nix" ]]; then
    _ok "$cmd" "optional (not installed)"
  else
    _fail "$cmd" "missing"
  fi
done

if check_cmd pueue; then
  if "$(get_cmd_path pueue)" status >/dev/null 2>&1; then
    _ok "pueue daemon" "running"
  elif command -v pueued >/dev/null 2>&1 && pueued -d >/dev/null 2>&1 && "$(get_cmd_path pueue)" status >/dev/null 2>&1; then
    _ok "pueue daemon" "started"
  else
    _warn "pueue daemon" "not running (pueued -d)"
  fi
fi

# --- AI CLIs ---
_section "AI CLIs"
for cmd in claude gemini sgpt ollama opencode aider kiro-cli; do
  if check_cmd "$cmd"; then
    _ok "$cmd" "$(pretty_path "$(get_cmd_path "$cmd")")"
  else
    _warn "$cmd" "optional"
  fi
done

# --- Environment ---
_section "Environment"
if [[ -n "${XDG_CONFIG_HOME:-}" ]]; then
  _ok "XDG_CONFIG_HOME" "$(pretty_path "$XDG_CONFIG_HOME")"
else
  _warn "XDG_CONFIG_HOME" "defaulting to ~/.config"
fi

# Validate XDG paths are absolute
for var in XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME; do
  val="${!var:-}"
  if [[ -n "$val" ]] && [[ "$val" != /* ]]; then
    _warn "$var" "not absolute: $val"
  fi
done

if [[ -n "${PIPX_HOME:-}" ]]; then
  _ok "PIPX_HOME" "$(pretty_path "$PIPX_HOME")"
else
  _warn "PIPX_HOME" "not set"
fi

# --- Platform ---
_section "Platform"
platform_id="$(dot_platform_id)"
host_os="$(dot_host_os)"
kernel="$(uname -sr)"
arch="$(uname -m)"
hostname_value="$(hostname 2>/dev/null || true)"
session_type="${XDG_SESSION_TYPE:-unknown}"
desktop_env="${XDG_CURRENT_DESKTOP:-unknown}"
if uptime -p >/dev/null 2>&1; then
  uptime_human="$(uptime -p 2>/dev/null | sed 's/^up //')"
else
  # macOS/BSD fallback output does not support "-p".
  uptime_human="$(uptime 2>/dev/null | sed -E 's/^.* up ([^,]+(, [^,]+){0,2}), [0-9]+ users?.*$/\1/' || true)"
fi

if [[ -r /etc/os-release ]]; then
  distro_pretty="$(
    # shellcheck disable=SC1091
    . /etc/os-release
    echo "${PRETTY_NAME:-$ID}"
  )"
else
  distro_pretty="$host_os"
fi

_ok "Runtime" "$platform_id"
_ok "Host OS" "$host_os"
_ok "Distro" "$distro_pretty"
_ok "Kernel" "$kernel"
_ok "Architecture" "$arch"
_ok "Hostname" "$hostname_value"
_ok "Desktop" "$desktop_env"
_ok "Session" "$session_type"
if [[ -n "${uptime_human:-}" ]]; then
  _ok "Uptime" "$uptime_human"
fi

if [[ "$platform_id" == "wsl" ]]; then
  if command -v wslpath >/dev/null 2>&1; then
    _ok "WSL bridge" "wslpath available"
  else
    _warn "WSL bridge" "wslpath missing"
  fi
  if [[ "$PWD" == /mnt/* ]]; then
    _warn "WSL filesystem" "/mnt causes IO latency"
  else
    _ok "WSL filesystem" "native"
  fi
fi

# --- State ---
_section "State"
if chezmoi verify &>/dev/null; then
  _ok "chezmoi" "synchronized"
else
  _fail "chezmoi" "drifted (run dot drift)"
fi

if [[ -f "$HOME/.zshrc" ]]; then
  _ok ".zshrc" "present"
else
  _fail ".zshrc" "missing"
fi

if command -v dot >/dev/null 2>&1; then
  dot_path="$(command -v dot)"
  if [[ "$dot_path" == "$HOME/.local/bin/dot" ]]; then
    _ok "dot" "$(pretty_path "$dot_path")"
  else
    _warn "dot" "$(pretty_path "$dot_path") (expected ~/.local/bin/dot)"
  fi
else
  _fail "dot" "not found in PATH"
fi

# --- Topgrade Integration ---
_section "Topgrade Integration"

if command -v antigravity >/dev/null 2>&1; then
  ag_path="$(command -v antigravity)"
  if [[ "$ag_path" == "$HOME/.local/bin/antigravity" ]]; then
    _ok "antigravity wrapper" "$(pretty_path "$ag_path")"
  else
    _warn "antigravity wrapper" "$(pretty_path "$ag_path") (expected ~/.local/bin/antigravity)"
  fi
else
  _warn "antigravity" "optional"
fi

if [[ -f "$HOME/.config/fish/fish_plugins" ]]; then
  if grep -qx "jorgebucaran/fisher" "$HOME/.config/fish/fish_plugins"; then
    _ok "fish_plugins" "contains jorgebucaran/fisher"
  else
    _warn "fish_plugins" "present but missing jorgebucaran/fisher"
  fi
else
  _fail "fish_plugins" "missing (~/.config/fish/fish_plugins)"
fi

if command -v cargo-install-update >/dev/null 2>&1; then
  _ok "cargo-install-update" "$(pretty_path "$(command -v cargo-install-update)")"
else
  _warn "cargo-install-update" "missing (install: cargo install cargo-update)"
fi

# --- Symlinks ---
broken_links=0
for root in "$HOME/.config" "$HOME/.local/bin" "$HOME/.local/share" "$HOME/.ssh"; do
  [[ -d "$root" ]] || continue
  while IFS= read -r -d '' link; do
    [[ "$link" == *"google-chrome-backup"* ]] && continue
    [[ -e "$link" ]] || broken_links=$((broken_links + 1))
  done < <(find "$root" -maxdepth 3 -type l -print0 2>/dev/null)
done

if [[ $broken_links -eq 0 ]]; then
  _ok "symlinks" "none broken"
else
  _warn "symlinks" "$broken_links broken"
fi

# --- Portability ---
ghost_paths=0
if command -v chezmoi >/dev/null 2>&1; then
  while IFS= read -r managed_path; do
    [[ "$managed_path" == "$HOME/.config/"* ]] || continue
    [[ -f "$managed_path" ]] || continue
    grep -Iq . "$managed_path" 2>/dev/null || continue

    match_count=$(
      grep -nE '"/home/(linuxbrew)?[^$]|/Users/[^$]' "$managed_path" 2>/dev/null |
        grep -v "linuxbrew" |
        grep -v "/mozilla/firefox" |
        grep -v "/google-chrome" |
        grep -v "/chromium" |
        grep -v "/chezmoi/chezmoi.toml" |
        grep -v "/bun/" |
        grep -v "/.bun/" |
        grep -v "/noctalia/" |
        grep -c -v -- "-backup/" ||
        true
    )

    ghost_paths=$((ghost_paths + ${match_count:-0}))
  done < <(chezmoi managed --path-style=absolute 2>/dev/null || true)

  if [[ $ghost_paths -gt 0 ]]; then
    _warn "portability" "$ghost_paths hardcoded paths in managed ~/.config files"
  else
    _ok "portability" "no hardcoded paths in managed ~/.config files"
  fi
else
  _warn "portability" "chezmoi not found (scan skipped)"
fi

# --- Performance ---
_section "Performance"

# Check shell cache freshness — stale caches force runtime regeneration
stale_caches=0
stale_tools=""
cache_base="${XDG_CACHE_HOME:-$HOME/.cache}"
for tool in mise starship zoxide atuin fzf direnv; do
  tool_bin="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$tool_bin" ]] || continue
  for shell_dir in zsh bash fish; do
    case "$shell_dir" in
      fish) cache_file="$cache_base/$shell_dir/${tool}-init.fish" ;;
      *) cache_file="$cache_base/$shell_dir/${tool}-init.$shell_dir" ;;
    esac
    if [[ ! -f "$cache_file" ]] || [[ "$tool_bin" -nt "$cache_file" ]]; then
      stale_caches=$((stale_caches + 1))
      # Track unique tool names for the summary
      case "$stale_tools" in
        *"$tool"*) ;;
        *) stale_tools="${stale_tools:+$stale_tools, }$tool" ;;
      esac
      break # one stale shell is enough to flag the tool
    fi
  done
done

if [[ $stale_caches -eq 0 ]]; then
  _ok "shell caches" "fresh"
else
  _warn "shell caches" "stale ($stale_tools) — run dot prewarm"
fi

if command -v hyperfine >/dev/null 2>&1; then
  if bash "$SCRIPT_DIR/../../tests/performance/bench.sh" 2>/dev/null; then
    _ok "startup latency" "within target thresholds"
  else
    _warn "startup latency" "threshold exceeded (run dot prewarm)"
  fi
else
  _warn "hyperfine" "missing (benchmark skipped)"
fi

# --- Summary ---
dot_log info "doctor_complete" "errors=$Errors" "warnings=$Warnings"
dot_metric "doctor_errors" "$Errors" "count"
dot_metric "doctor_warnings" "$Warnings" "count"
echo ""
if [[ $Errors -eq 0 ]]; then
  if [[ $Warnings -eq 0 ]]; then
    ui_ok "Healthy" "All checks passed."
  else
    ui_ok "Healthy" "$Warnings warning(s)."
  fi
else
  ui_err "$Errors error(s)" "$Warnings warning(s). Run 'dot heal' to repair."

  if [[ $AI_DEBUG -eq 1 ]]; then
    _section "AI Problem Analysis"
    doctor_report=$(~/.local/bin/dot doctor | grep -E "(✗|⚠)")
    ai_prompt="The dotfiles diagnostic 'dot doctor' found the following issues:
---
$doctor_report
---
Suggest specific shell commands to fix these issues according to our architectural standards."
    dot cl --pattern hardener "$ai_prompt"
  fi
  exit 1
fi
echo ""
