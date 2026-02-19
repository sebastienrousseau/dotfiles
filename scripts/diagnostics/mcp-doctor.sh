#!/usr/bin/env bash
# MCP configuration diagnostics and hardening checks.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"

ui_init
ui_header "MCP Doctor"
echo ""

Errors=0
Warnings=0

log_success() { ui_ok "$1" "${2:-}"; }
log_fail() { ui_err "$1" "${2:-}"; Errors=$((Errors + 1)); }
log_warn() { ui_warn "$1" "${2:-}"; Warnings=$((Warnings + 1)); }

MCP_CONFIG="${MCP_CONFIG:-$HOME/.config/claude/mcp_servers.json}"
if [[ ! -f "$MCP_CONFIG" && -f "$HOME/.dotfiles/dot_config/claude/mcp_servers.json" ]]; then
  MCP_CONFIG="$HOME/.dotfiles/dot_config/claude/mcp_servers.json"
fi

ui_header "Config File"
if [[ -f "$MCP_CONFIG" ]]; then
  log_success "MCP config" "$MCP_CONFIG"
else
  log_fail "MCP config" "not found (expected $MCP_CONFIG)"
fi

echo ""
ui_header "Validation"
if command -v jq >/dev/null 2>&1; then
  json_valid=0
  if [[ -f "$MCP_CONFIG" ]] && jq empty "$MCP_CONFIG" >/dev/null 2>&1; then
    log_success "JSON syntax" "valid"
    json_valid=1
  else
    log_fail "JSON syntax" "invalid"
  fi

  if [[ "$json_valid" -eq 1 ]]; then
    server_count="$(jq '.mcpServers | keys | length' "$MCP_CONFIG" 2>/dev/null || echo 0)"
    if [[ "$server_count" -gt 0 ]]; then
      log_success "MCP servers" "$server_count configured"
    else
      log_fail "MCP servers" "none configured"
    fi

    if jq -e '.mcpServers.filesystem.args[]? | select(. == "/" or . == "/home" or . == "/Users")' "$MCP_CONFIG" >/dev/null 2>&1; then
      log_warn "Filesystem scope" "too broad (use a project-scoped directory)"
    else
      log_success "Filesystem scope" "not globally broad"
    fi

    # MCP operational policy: allow known launchers only.
    unknown_launchers="$(jq -r '.mcpServers | to_entries[]? | select(.value.command != "npx" and .value.command != "node" and .value.command != "uvx") | "\(.key):\(.value.command)"' "$MCP_CONFIG" 2>/dev/null || true)"
    if [[ -n "$unknown_launchers" ]]; then
      while IFS= read -r item; do
        [[ -z "$item" ]] && continue
        log_warn "Launcher policy" "review non-standard command $item"
      done <<<"$unknown_launchers"
    else
      log_success "Launcher policy" "all server launchers are allowlisted (npx/node/uvx)"
    fi

    # MCP policy: flag wildcard/potentially risky args for review.
    risky_args="$(jq -r '.mcpServers | to_entries[]? | .key as $name | (.value.args // [])[]? | select(test("^--allow-.*|^--unsafe|^\\*$")) | "\($name):\(.)"' "$MCP_CONFIG" 2>/dev/null || true)"
    if [[ -n "$risky_args" ]]; then
      while IFS= read -r item; do
        [[ -z "$item" ]] && continue
        log_warn "Arg policy" "review risky argument $item"
      done <<<"$risky_args"
    else
      log_success "Arg policy" "no high-risk wildcard/unsafe args found"
    fi

    env_vars="$(jq -r '.mcpServers | to_entries[]? | (.value.env // {}) | to_entries[]?.value' "$MCP_CONFIG" | sed -n 's/^\${\([A-Z0-9_]\+\)}$/\1/p' | sort -u)"
    if [[ -z "$env_vars" ]]; then
      log_warn "Server env placeholders" "none found"
    else
      missing=0
      while IFS= read -r key; do
        [[ -z "$key" ]] && continue
        if [[ -z "${!key:-}" ]]; then
          log_warn "Env variable" "$key is not set"
          missing=$((missing + 1))
        fi
      done <<<"$env_vars"
      if [[ "$missing" -eq 0 ]]; then
        log_success "Env variables" "all referenced placeholders are set"
      fi
    fi

    # Common required secrets for known MCP servers.
    if jq -e '.mcpServers.github' "$MCP_CONFIG" >/dev/null 2>&1; then
      if [[ -n "${GITHUB_TOKEN:-}" ]]; then
        log_success "Token check" "GITHUB_TOKEN is set for github MCP server"
      else
        log_warn "Token check" "GITHUB_TOKEN missing for github MCP server"
      fi
    fi
    if jq -e '.mcpServers["brave-search"]' "$MCP_CONFIG" >/dev/null 2>&1; then
      if [[ -n "${BRAVE_API_KEY:-}" ]]; then
        log_success "Token check" "BRAVE_API_KEY is set for brave-search MCP server"
      else
        log_warn "Token check" "BRAVE_API_KEY missing for brave-search MCP server"
      fi
    fi
  fi
else
  log_warn "jq" "not installed, running limited checks"
  if grep -q '"mcpServers"' "$MCP_CONFIG" 2>/dev/null; then
    log_success "mcpServers key" "present"
  else
    log_fail "mcpServers key" "missing"
  fi
fi

echo ""
ui_header "Summary"
if [[ "$Errors" -eq 0 ]]; then
  if [[ "$Warnings" -eq 0 ]]; then
    ui_ok "MCP configuration healthy"
  else
    ui_warn "MCP configuration healthy" "$Warnings warnings"
  fi
else
  ui_err "MCP issues found" "$Errors errors, $Warnings warnings"
  exit 1
fi
