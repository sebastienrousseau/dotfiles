#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
## Dotfiles Doctor.
##
## Diagnoses dotfiles environment health by checking dependencies, paths,
## and configuration integrity. Reports errors, warnings, and suggests
## remediation steps.
##
## # Usage
## dot doctor [--json|-j] [--ai]
##
## --json renders the same probes as one JSON document (the shape and key
## names of `dot health --json`, plus `status` and `verdict`) instead of the
## text dashboard.
##
## # Exit Codes
## - 0: All checks passed (may have warnings)
## - 1: Critical errors detected
##
## # Idempotency
## Safe to run repeatedly. Read-only checks.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/dot/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../lib/dot/ui.sh"
# shellcheck source=../../lib/dot/platform.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../lib/dot/platform.sh"
# shellcheck source=../../lib/dot/log.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../lib/dot/log.sh"
# shellcheck source=../../lib/dot/utils.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../lib/dot/utils.sh" # check_cmd
# shellcheck source=doctor/platform.sh
source "$SCRIPT_DIR/doctor/platform.sh"
# shellcheck source=doctor/performance.sh
source "$SCRIPT_DIR/doctor/performance.sh"
export DOT_COMMAND="doctor"

ui_init

# Extend PATH to include common non-standard install locations, unless they
# are already on it: prepending ~/.local/bin a second time made doctor's own
# PATH check report a duplicate that the user's shell does not have.
for _doctor_dir in "$HOME/.local/bin" "$HOME/.atuin/bin"; do
  case ":$PATH:" in
    *":$_doctor_dir:"*) ;;
    *) PATH="$_doctor_dir:$PATH" ;;
  esac
done
export PATH

Errors=0
Warnings=0
Passed=0
Checks=0
Results=()
AI_DEBUG=0
JSON_OUTPUT=0

for arg in "$@"; do
  case "$arg" in
    --ai) AI_DEBUG=1 ;;
    --json | -j) JSON_OUTPUT=1 ;;
  esac
done

# JSON mode: the dashboard is written by dozens of direct printf/ui_* calls,
# so rather than guard each one, park the real stdout on fd 3 and send the
# text to /dev/null. Only the document at the end goes to fd 3.
if [[ $JSON_OUTPUT -eq 1 ]]; then
  exec 3>&1 1>/dev/null
fi

# --- Output helpers (delegate to shared ui.sh) ---
# _record <status> <name> <message> — collect one probe for --json. Same
# {check,status,message} rows health.sh emits; backslashes and quotes are
# escaped so the document stays valid whatever a probe puts in its message.
_record() {
  local status="$1" name="$2" message="${3:-}"
  name="${name//\\/\\\\}"
  name="${name//\"/\\\"}"
  message="${message//\\/\\\\}"
  message="${message//\"/\\\"}"
  Checks=$((Checks + 1))
  Results+=("{\"check\":\"${name}\",\"status\":\"${status}\",\"message\":\"${message}\"}")
}
_ok() {
  ui_ok "$1" "${2:-}"
  _record pass "$1" "${2:-}"
  Passed=$((Passed + 1))
}
_fail() {
  ui_err "$1" "${2:-}"
  _record fail "$1" "${2:-}"
  Errors=$((Errors + 1))
}
_warn() {
  ui_warn "$1" "${2:-}"
  _record warn "$1" "${2:-}"
  Warnings=$((Warnings + 1))
}

# _json_summary — the --json document. Keys follow `dot health --json`
# (total/passed/warnings/failures/results); status and verdict carry what
# the text dashboard says on its last line.
_json_summary() {
  local status verdict i=0
  if [[ $Errors -eq 0 ]]; then
    status="healthy"
    if [[ $Warnings -eq 0 ]]; then
      verdict="All checks passed."
    else
      verdict="$Warnings warning(s)."
    fi
  else
    status="unhealthy"
    verdict="$Errors error(s), $Warnings warning(s). Run 'dot heal' to repair."
  fi
  printf '{\n'
  printf '  "status": "%s",\n' "$status"
  printf '  "verdict": "%s",\n' "$verdict"
  printf '  "total": %d,\n' "$Checks"
  printf '  "passed": %d,\n' "$Passed"
  printf '  "warnings": %d,\n' "$Warnings"
  printf '  "failures": %d,\n' "$Errors"
  printf '  "results": [\n'
  local result
  for result in "${Results[@]+"${Results[@]}"}"; do
    if [[ $i -gt 0 ]]; then
      printf ',\n'
    fi
    printf '    %s' "$result"
    i=$((i + 1))
  done
  printf '\n  ]\n'
  printf '}\n'
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

# check_cmd() is provided by lib/dot/utils.sh — sourced above.

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
_doctor_header() {
  ui_header "Dotfiles Doctor"
}

# --- Core Shells ---
_doctor_core_shells() {
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
}

# --- Modern CLI Tools ---
_doctor_modern_cli_tools() {
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
}

# --- Infrastructure ---
_doctor_infrastructure() {
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
}

# --- AI CLIs ---
_doctor_ai_clis() {
  _section "AI CLIs"
  for cmd in codex claude copilot kimi agy sgpt ollama opencode aider kiro-cli; do
    if check_cmd "$cmd"; then
      _ok "$cmd" "$(pretty_path "$(get_cmd_path "$cmd")")"
    else
      ui_info "$cmd" "optional (not installed)"
    fi
  done
}

# --- Environment ---
_doctor_environment() {
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
}

# --- State ---
_doctor_state() {
  _section "State"
  # --exclude=always: a run_before_/run_after_ script (the macOS iCloud hook)
  # is "pending" on every apply by design, so plain `verify` exits 1 forever
  # on a fully synchronised machine. Files, dirs, symlinks and run_once/
  # run_onchange scripts still count.
  if chezmoi verify --exclude=always &>/dev/null; then
    _ok "chezmoi state" "synchronized"
  else
    _fail "chezmoi state" "drifted (run dot drift)"
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
}

# --- Pre-push audit bypass log (closes #871) ---
_doctor_pre_push_audit_bypass_log() {
  _section "Pre-Push Audit Bypass"

  bypass_log="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/audit-bypass.log"
  if [[ -s "$bypass_log" ]]; then
    # Count entries in the last 7 days (timestamps are ISO-8601 UTC).
    seven_days_ago=$(date -u -v-7d +%Y-%m-%dT00:00:00Z 2>/dev/null ||
      date -u -d '7 days ago' +%Y-%m-%dT00:00:00Z 2>/dev/null ||
      echo "1970-01-01T00:00:00Z")
    recent=$(awk -v cutoff="$seven_days_ago" '$1 >= cutoff' "$bypass_log" | wc -l | tr -d ' ')
    if ((recent > 0)); then
      _warn "audit bypass" "$recent push(es) bypassed in last 7 days — see $(pretty_path "$bypass_log")"
    else
      _ok "audit bypass" "log exists; no recent entries (last 7d)"
    fi
  else
    _ok "audit bypass" "clean — no pre-push audits bypassed"
  fi
}

# --- Atuin history-filter (closes #872) ---
_doctor_atuin_history_filter() {
  _section "Atuin History Filter"

  atuin_cfg="$HOME/.config/atuin/config.toml"
  if [[ ! -f "$atuin_cfg" ]]; then
    _warn "atuin config" "not found at $(pretty_path "$atuin_cfg")"
  else
    if grep -Eq "^history_filter[[:space:]]*=" "$atuin_cfg"; then
      pattern_count=$(awk '
      /^history_filter[[:space:]]*=[[:space:]]*\[/ { inside = 1; next }
      inside && /^\]/                              { inside = 0 }
      inside && /^[[:space:]]*"/                   { count++ }
      END                                          { print count + 0 }
    ' "$atuin_cfg")
      if ((pattern_count >= 10)); then
        _ok "history_filter" "$pattern_count patterns (chezmoi-managed)"
      else
        _warn "history_filter" "$pattern_count patterns (expected ≥10 from secrets-patterns.toml)"
      fi
    else
      _fail "history_filter" "no history_filter block in $(pretty_path "$atuin_cfg") — secrets may leak into shell history"
    fi
  fi
}

# --- Topgrade Integration ---
_doctor_topgrade_integration() {
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

  # Only meaningful when there is a cargo for topgrade to run it through; a
  # machine without a Rust toolchain has nothing to update, so warning about
  # the missing helper there is noise that never goes away.
  if command -v cargo-install-update >/dev/null 2>&1; then
    _ok "cargo-install-update" "$(pretty_path "$(command -v cargo-install-update)")"
  elif command -v cargo >/dev/null 2>&1; then
    _warn "cargo-install-update" "missing (install: cargo install cargo-update)"
  else
    _ok "cargo-install-update" "not needed (cargo not installed)"
  fi
}

# --- Symlinks ---
# _doctor_link_ok <link>: true for links that are not worth reporting: live
# ones, browser singleton/backup links, and links into ~/Library/Caches.
_doctor_link_ok() {
  local link="$1" name
  name="$(basename "$link")"
  [[ -e "$link" ]] && return 0
  [[ "$link" == *"google-chrome-backup"* ]] && return 0
  case "$name" in
    SingletonLock | SingletonCookie | SingletonSocket) return 0 ;;
  esac
  # A link into ~/Library/Caches dangling is macOS working as designed, not a
  # health problem: the OS purges that directory whenever it wants the space,
  # and the owning tool recreates its cache on next use. ~/.config/swiftpm/cache
  # -> ~/Library/Caches/org.swift.swiftpm is the usual one; it was "fixed" by
  # recreating the target earlier the same day and had broken again by evening,
  # which is the tell that it is not fixable, only re-reported.
  case "$(readlink "$link" 2>/dev/null)" in
    "$HOME/Library/Caches/"*) return 0 ;;
  esac
  return 1
}

_doctor_symlinks() {
  broken_links=0
  broken_list=""
  for root in "$HOME/.config" "$HOME/.local/bin" "$HOME/.local/share" "$HOME/.ssh"; do
    [[ -d "$root" ]] || continue
    while IFS= read -r -d '' link; do
      _doctor_link_ok "$link" && continue
      broken_links=$((broken_links + 1))
      broken_list="${broken_list:+$broken_list, }$(pretty_path "$link")"
    done < <(find "$root" -maxdepth 3 -type l -print0 2>/dev/null)
  done

  if [[ $broken_links -eq 0 ]]; then
    _ok "symlinks" "none broken"
  else
    # Name them. "1 broken" with no path meant hunting for it by hand, twice.
    _warn "symlinks" "$broken_links broken: $broken_list"
  fi
}

# --- Portability ---
_doctor_portability() {
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
}

# --- Summary ---
_doctor_summary() {
  dot_log info "doctor_complete" "errors=$Errors" "warnings=$Warnings"
  dot_metric "doctor_errors" "$Errors" "count"
  dot_metric "doctor_warnings" "$Warnings" "count"
  if [[ $JSON_OUTPUT -eq 1 ]]; then
    _json_summary >&3
  fi
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
      dot ai claude --style hardener "$ai_prompt"
    fi
    exit 1
  fi
  echo ""
}

# Sections in report order.
_doctor_main() {
  _doctor_header
  _doctor_core_shells
  _doctor_modern_cli_tools
  _doctor_infrastructure
  _doctor_ai_clis
  _doctor_environment
  _doctor_platform
  _doctor_os_specific_detection
  _doctor_state
  _doctor_pre_push_audit_bypass_log
  _doctor_atuin_history_filter
  _doctor_topgrade_integration
  _doctor_symlinks
  _doctor_portability
  _doctor_performance
  _doctor_summary
}

_doctor_main
