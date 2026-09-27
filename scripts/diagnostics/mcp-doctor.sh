#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
## MCP configuration diagnostics and hardening checks.
##
## Validates MCP (Model Context Protocol) server configurations for security
## policy compliance: launcher allowlist, filesystem scope, token requirements.
##
## # Usage
## dot mcp [--strict|-s] [--json|-j]
##
## # Options
## --strict, -s: Treat policy warnings as errors (for CI enforcement)
## --json, -j: Emit a machine-readable summary
##
## # Dependencies
## - jq: JSON parsing (optional but recommended)
##
## # Checks Performed
## | Check | Description |
## |-------|-------------|
## | Launcher policy | Only npx/node/uvx allowed |
## | Filesystem scope | No broad access (/, /home, /Users) |
## | Arg policy | No wildcards or --unsafe flags |
## | Token check | Required tokens set (GITHUB_TOKEN, BRAVE_API_KEY) |
## | Env placeholders | All ${VAR} references resolved |
##
## # Exit Codes
## - 0: All checks passed
## - 1: Errors found (or warnings in strict mode)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/dot/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../lib/dot/ui.sh"
# shellcheck source-path=SCRIPTDIR source=mcp-doctor/checks.sh
source "$SCRIPT_DIR/mcp-doctor/checks.sh"

# Parse arguments
STRICT_MODE=0
JSON_MODE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict | -s)
      STRICT_MODE=1
      shift
      ;;
    --json | -j)
      JSON_MODE=1
      shift
      ;;
    *) shift ;;
  esac
done

Errors=0
Warnings=0
SUMMARY_STATUS="healthy"
CONFIG_OK=0
JSON_VALID=0
SERVER_COUNT=0
POLICY_WARN_ON_UNPINNED_NPX=0
REQUIRE_APPROVED_PACKAGE_LOCK=0
REQUIRE_REGISTRY_ENTRY=0
REQUIRE_HTTPS_FOR_HTTP=0
REQUIRE_OAUTH_FOR_HTTP=0
ALLOWED_LAUNCHERS='["npx","node","uvx"]'
TRUSTED_TRANSPORTS='["stdio"]'
BLOCKED_PATHS='["/","/home","/Users"]'
BLOCKED_ARG_PATTERNS='["^--allow-.*","^--unsafe$","^\\\\*$"]'
FORBIDDEN_DEFAULT_SERVERS='[]'
REQUIRED_ENV_RULES='{}'
APPROVED_PACKAGE_LOCK='{}'
APPROVED_REGISTRY='{}'

log_success() {
  if [[ "$JSON_MODE" -ne 1 ]]; then
    ui_ok "$1" "${2:-}"
  fi
  return 0
}
log_fail() {
  if [[ "$JSON_MODE" -ne 1 ]]; then
    ui_err "$1" "${2:-}"
  fi
  Errors=$((Errors + 1))
  return 0
}
log_warn() {
  if [[ "$JSON_MODE" -ne 1 ]]; then
    ui_warn "$1" "${2:-}"
  fi
  Warnings=$((Warnings + 1))
  # In strict mode, warnings become errors
  [[ "$STRICT_MODE" -eq 1 ]] && Errors=$((Errors + 1))
  return 0
}

MCP_CONFIG="${MCP_CONFIG:-$HOME/.config/claude/mcp_servers.json}"
# Fall back to the chezmoi source copies of mcp_servers.json
_mcp_find_config() {
  local cand
  [[ -f "$MCP_CONFIG" ]] && return 0
  for cand in "$HOME/.dotfiles/defaults/dot_config/claude/mcp_servers.json" \
    "$HOME/.dotfiles/dot_config/claude/mcp_servers.json"; do
    if [[ -f "$cand" ]]; then
      MCP_CONFIG="$cand"
      return 0
    fi
  done
  # Not found: the Config File section reports it.
  return 0
}

# Read the policy, package lock and registry (defaults above when absent)
# _mcp_json_ok <file>: jq is available and <file> exists and parses.
_mcp_json_ok() {
  command -v jq >/dev/null 2>&1 && [[ -f "$1" ]] && jq empty "$1" >/dev/null 2>&1 # mutation: ignore equivalent: jq empty fails on a missing file too
}

# _mcp_policy_flag <key>: 1 when the policy's default profile sets <key> to
# true, else 0.
_mcp_policy_flag() {
  if [[ "$(jq -r ".profiles[.defaultProfile].$1 // false" "$MCP_POLICY_CONFIG")" == "true" ]]; then
    echo 1
  else
    echo 0
  fi
}

_mcp_load_policy() {
  if _mcp_json_ok "$MCP_POLICY_CONFIG"; then
    ALLOWED_LAUNCHERS="$(jq -c '.profiles[.defaultProfile].allowedLaunchers // ["npx","node","uvx"]' "$MCP_POLICY_CONFIG")"
    BLOCKED_PATHS="$(jq -c '.profiles[.defaultProfile].blockedFilesystemRoots // ["/","/home","/Users"]' "$MCP_POLICY_CONFIG")"
    BLOCKED_ARG_PATTERNS="$(jq -c '.profiles[.defaultProfile].blockedArgPatterns // ["^--allow-.*","^--unsafe$","^\\\\*$"]' "$MCP_POLICY_CONFIG")"
    FORBIDDEN_DEFAULT_SERVERS="$(jq -c '.profiles[.defaultProfile].forbidNetworkServersByDefault // []' "$MCP_POLICY_CONFIG")"
    REQUIRED_ENV_RULES="$(jq -c '.profiles[.defaultProfile].requiredEnvByServer // {}' "$MCP_POLICY_CONFIG")"
    TRUSTED_TRANSPORTS="$(jq -c '.profiles[.defaultProfile].trustedTransports // ["stdio"]' "$MCP_POLICY_CONFIG")"
    POLICY_WARN_ON_UNPINNED_NPX="$(_mcp_policy_flag warnOnUnpinnedNpx)"
    REQUIRE_APPROVED_PACKAGE_LOCK="$(_mcp_policy_flag requireApprovedPackageLock)"
    REQUIRE_REGISTRY_ENTRY="$(_mcp_policy_flag requireRegistryEntry)"
    REQUIRE_HTTPS_FOR_HTTP="$(_mcp_policy_flag requireHttpsForHttpTransports)"
    REQUIRE_OAUTH_FOR_HTTP="$(_mcp_policy_flag requireOauthForHttpTransports)"
  fi

  if _mcp_json_ok "$MCP_LOCK_CONFIG"; then
    APPROVED_PACKAGE_LOCK="$(jq -c '.packages // {}' "$MCP_LOCK_CONFIG")"
  fi

  if _mcp_json_ok "$MCP_REGISTRY_CONFIG"; then
    APPROVED_REGISTRY="$(jq -c '.servers // {}' "$MCP_REGISTRY_CONFIG")"
  fi
}

# Config File section: which files were found and parse
# _mcp_section <title>: a section header (human output only).
_mcp_section() {
  if [[ "$JSON_MODE" -ne 1 ]]; then
    echo ""
    ui_header "$1"
  fi
}

# _mcp_policy_file <label> <path> <required 0|1> <what strict-local expects>
_mcp_policy_file() {
  if [[ -f "$2" ]]; then
    log_success "$1" "$2"
  elif [[ "$3" -eq 1 ]]; then
    log_warn "$1" "not found (strict-local expects a tracked $4)"
  else
    log_success "$1" "not required"
  fi
}

_mcp_show_config_files() {
  [[ "$JSON_MODE" -ne 1 ]] && ui_header "Config File"
  if [[ -f "$MCP_CONFIG" ]]; then
    CONFIG_OK=1
    log_success "MCP config" "$MCP_CONFIG"
  else
    log_fail "MCP config" "not found (expected $MCP_CONFIG)"
  fi

  _mcp_section "Policy"
  if [[ -f "$MCP_POLICY_CONFIG" ]]; then
    log_success "Policy config" "$MCP_POLICY_CONFIG"
  else
    log_warn "Policy config" "not found (using built-in defaults)"
  fi

  _mcp_section "Supply Chain"
  _mcp_policy_file "Package lock" "$MCP_LOCK_CONFIG" "$REQUIRE_APPROVED_PACKAGE_LOCK" "lock file"
  _mcp_policy_file "Registry" "$MCP_REGISTRY_CONFIG" "$REQUIRE_REGISTRY_ENTRY" "registry file"
}

# _mcp_card_expect <label> <jq value> <warning>: show the card field's
# value, or warn when the filter yields nothing.
_mcp_card_expect() {
  local value
  value="$(jq -r "$2" "$MCP_SERVER_CARD")"
  if [[ -n "$value" ]]; then
    log_success "$1" "$value"
  else
    log_warn "$1" "$3"
  fi
}

_mcp_check_server_card() {
  MCP_SERVER_CARD="${MCP_SERVER_CARD:-$REPO_ROOT/.well-known/mcp/server-card.json}"
  _mcp_section "Server Card (SEP-1649)"
  if [[ ! -f "$MCP_SERVER_CARD" ]]; then
    log_warn "Server card" "not found (expected $MCP_SERVER_CARD)"
    return 0
  fi
  if ! _mcp_json_ok "$MCP_SERVER_CARD"; then
    log_fail "Server card" "invalid JSON"
    return 0
  fi
  log_success "Server card" "$MCP_SERVER_CARD"
  _mcp_card_expect "Card version" '.cardVersion // empty' "missing cardVersion field"
  _mcp_card_expect "Card name" '.name // empty' "missing name field"
  _mcp_card_expect "Card capabilities" 'if .capabilities then "present" else empty end' "missing capabilities block"
  _mcp_card_expect "Card transport" 'if .transport then "present" else empty end' "missing transport block"
}

# Server Checks section: the policy checks when the config parses
_mcp_check_config() {
  _mcp_section "Validation"
  if command -v jq >/dev/null 2>&1; then
    if [[ -f "$MCP_CONFIG" ]] && jq empty "$MCP_CONFIG" >/dev/null 2>&1; then
      log_success "JSON syntax" "valid"
      JSON_VALID=1
    else
      log_fail "JSON syntax" "invalid"
    fi

    if [[ "$JSON_VALID" -eq 1 ]]; then
      _mcp_check_servers
      _mcp_check_blocked_paths
      _mcp_check_launchers
      _mcp_check_risky_args
      _mcp_check_default_servers
      _mcp_check_transports
      _mcp_check_https
      _mcp_check_auth_profiles
      _mcp_check_oauth
      _mcp_check_env_placeholders
      _mcp_check_tokens
      _mcp_check_unpinned_npx
      _mcp_check_package_lock
      _mcp_check_registry
    fi
  else
    log_warn "jq" "not installed, running limited checks"
    if grep -q '"mcpServers"' "$MCP_CONFIG" 2>/dev/null; then
      log_success "mcpServers key" "present"
    else
      log_fail "mcpServers key" "missing"
    fi
  fi
}

_mcp_summary_status() {
  if [[ "$Errors" -eq 0 ]]; then
    if [[ "$Warnings" -eq 0 ]]; then
      SUMMARY_STATUS="healthy"
    else
      if [[ "$STRICT_MODE" -eq 1 ]]; then
        SUMMARY_STATUS="failed"
      else
        SUMMARY_STATUS="warning"
      fi
    fi
  else
    SUMMARY_STATUS="failed"
  fi
}

_mcp_report_json() {
  if [[ "$JSON_MODE" -eq 1 ]]; then
    jq -n \
      --arg status "$SUMMARY_STATUS" \
      --arg config "$MCP_CONFIG" \
      --arg policy "$MCP_POLICY_CONFIG" \
      --argjson strict "$STRICT_MODE" \
      --argjson server_count "$SERVER_COUNT" \
      --argjson errors "$Errors" \
      --argjson warnings "$Warnings" \
      --argjson config_ok "$CONFIG_OK" \
      --argjson json_valid "$JSON_VALID" \
      '{
      status: $status,
      strict: ($strict == 1),
      config_path: $config,
      policy_path: $policy,
      server_count: $server_count,
      checks: {
        config_present: ($config_ok == 1),
        json_valid: ($json_valid == 1)
      },
      summary: {
        errors: $errors,
        warnings: $warnings
      }
    }'
  else
    echo ""
    ui_header "Summary"
  fi
}

_mcp_report_text() {
  if [[ "$Errors" -ne 0 ]]; then
    [[ "$JSON_MODE" -eq 1 ]] || ui_err "MCP issues found" "$Errors errors, $Warnings warnings"
    exit 1
  fi
  if [[ "$Warnings" -eq 0 ]]; then
    [[ "$JSON_MODE" -eq 1 ]] || ui_ok "MCP configuration healthy"
    return 0
  fi
  # Warnings without errors: under --strict log_warn counts every warning as
  # an error too, so this is only reached in the default mode.
  [[ "$JSON_MODE" -eq 1 ]] || ui_warn "MCP configuration healthy" "$Warnings warnings"
  return 0
}

_mcp_find_config

REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
MCP_POLICY_CONFIG="${MCP_POLICY_CONFIG:-$REPO_ROOT/defaults/dot_config/dotfiles/mcp-policy.json}"
MCP_LOCK_CONFIG="${MCP_LOCK_CONFIG:-$REPO_ROOT/defaults/dot_config/dotfiles/mcp-lock.json}"
MCP_REGISTRY_CONFIG="${MCP_REGISTRY_CONFIG:-$REPO_ROOT/defaults/dot_config/dotfiles/mcp-registry.json}"

if [[ "$JSON_MODE" -ne 1 ]]; then
  ui_init
  ui_dot_banner "AI and Agents"
  ui_header "MCP Doctor"
  echo ""
fi

_mcp_load_policy

_mcp_show_config_files

_mcp_check_server_card

_mcp_check_config

_mcp_summary_status

_mcp_report_json

_mcp_report_text
