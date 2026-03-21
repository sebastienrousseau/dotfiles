#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
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
# shellcheck source=../dot/lib/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../dot/lib/ui.sh"

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
}
log_fail() {
  if [[ "$JSON_MODE" -ne 1 ]]; then
    ui_err "$1" "${2:-}"
  fi
  Errors=$((Errors + 1))
}
log_warn() {
  if [[ "$JSON_MODE" -ne 1 ]]; then
    ui_warn "$1" "${2:-}"
  fi
  Warnings=$((Warnings + 1))
  # In strict mode, warnings become errors
  [[ "$STRICT_MODE" -eq 1 ]] && Errors=$((Errors + 1))
}

MCP_CONFIG="${MCP_CONFIG:-$HOME/.config/claude/mcp_servers.json}"
if [[ ! -f "$MCP_CONFIG" && -f "$HOME/.dotfiles/dot_config/claude/mcp_servers.json" ]]; then
  MCP_CONFIG="$HOME/.dotfiles/dot_config/claude/mcp_servers.json"
fi

REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
MCP_POLICY_CONFIG="${MCP_POLICY_CONFIG:-$REPO_ROOT/dot_config/dotfiles/mcp-policy.json}"
MCP_LOCK_CONFIG="${MCP_LOCK_CONFIG:-$REPO_ROOT/dot_config/dotfiles/mcp-lock.json}"
MCP_REGISTRY_CONFIG="${MCP_REGISTRY_CONFIG:-$REPO_ROOT/dot_config/dotfiles/mcp-registry.json}"

if [[ "$JSON_MODE" -ne 1 ]]; then
  ui_init
  ui_dot_banner "AI and Agents"
  ui_header "MCP Doctor"
  echo ""
fi

if command -v jq >/dev/null 2>&1 && [[ -f "$MCP_POLICY_CONFIG" ]] && jq empty "$MCP_POLICY_CONFIG" >/dev/null 2>&1; then
  ALLOWED_LAUNCHERS="$(jq -c '.profiles[.defaultProfile].allowedLaunchers // ["npx","node","uvx"]' "$MCP_POLICY_CONFIG")"
  BLOCKED_PATHS="$(jq -c '.profiles[.defaultProfile].blockedFilesystemRoots // ["/","/home","/Users"]' "$MCP_POLICY_CONFIG")"
  BLOCKED_ARG_PATTERNS="$(jq -c '.profiles[.defaultProfile].blockedArgPatterns // ["^--allow-.*","^--unsafe$","^\\\\*$"]' "$MCP_POLICY_CONFIG")"
  FORBIDDEN_DEFAULT_SERVERS="$(jq -c '.profiles[.defaultProfile].forbidNetworkServersByDefault // []' "$MCP_POLICY_CONFIG")"
  REQUIRED_ENV_RULES="$(jq -c '.profiles[.defaultProfile].requiredEnvByServer // {}' "$MCP_POLICY_CONFIG")"
  TRUSTED_TRANSPORTS="$(jq -c '.profiles[.defaultProfile].trustedTransports // ["stdio"]' "$MCP_POLICY_CONFIG")"
  if [[ "$(jq -r '.profiles[.defaultProfile].warnOnUnpinnedNpx // false' "$MCP_POLICY_CONFIG")" == "true" ]]; then
    POLICY_WARN_ON_UNPINNED_NPX=1
  fi
  if [[ "$(jq -r '.profiles[.defaultProfile].requireApprovedPackageLock // false' "$MCP_POLICY_CONFIG")" == "true" ]]; then
    REQUIRE_APPROVED_PACKAGE_LOCK=1
  fi
  if [[ "$(jq -r '.profiles[.defaultProfile].requireRegistryEntry // false' "$MCP_POLICY_CONFIG")" == "true" ]]; then
    REQUIRE_REGISTRY_ENTRY=1
  fi
  if [[ "$(jq -r '.profiles[.defaultProfile].requireHttpsForHttpTransports // false' "$MCP_POLICY_CONFIG")" == "true" ]]; then
    REQUIRE_HTTPS_FOR_HTTP=1
  fi
  if [[ "$(jq -r '.profiles[.defaultProfile].requireOauthForHttpTransports // false' "$MCP_POLICY_CONFIG")" == "true" ]]; then
    REQUIRE_OAUTH_FOR_HTTP=1
  fi
fi

if command -v jq >/dev/null 2>&1 && [[ -f "$MCP_LOCK_CONFIG" ]] && jq empty "$MCP_LOCK_CONFIG" >/dev/null 2>&1; then
  APPROVED_PACKAGE_LOCK="$(jq -c '.packages // {}' "$MCP_LOCK_CONFIG")"
fi

if command -v jq >/dev/null 2>&1 && [[ -f "$MCP_REGISTRY_CONFIG" ]] && jq empty "$MCP_REGISTRY_CONFIG" >/dev/null 2>&1; then
  APPROVED_REGISTRY="$(jq -c '.servers // {}' "$MCP_REGISTRY_CONFIG")"
fi

[[ "$JSON_MODE" -ne 1 ]] && ui_header "Config File"
if [[ -f "$MCP_CONFIG" ]]; then
  CONFIG_OK=1
  log_success "MCP config" "$MCP_CONFIG"
else
  log_fail "MCP config" "not found (expected $MCP_CONFIG)"
fi

if [[ "$JSON_MODE" -ne 1 ]]; then
  echo ""
  ui_header "Policy"
fi
if [[ -f "$MCP_POLICY_CONFIG" ]]; then
  log_success "Policy config" "$MCP_POLICY_CONFIG"
else
  log_warn "Policy config" "not found (using built-in defaults)"
fi

if [[ "$JSON_MODE" -ne 1 ]]; then
  echo ""
  ui_header "Supply Chain"
fi
if [[ -f "$MCP_LOCK_CONFIG" ]]; then
  log_success "Package lock" "$MCP_LOCK_CONFIG"
else
  if [[ "$REQUIRE_APPROVED_PACKAGE_LOCK" -eq 1 ]]; then
    log_warn "Package lock" "not found (strict-local expects a tracked lock file)"
  else
    log_success "Package lock" "not required"
  fi
fi
if [[ -f "$MCP_REGISTRY_CONFIG" ]]; then
  log_success "Registry" "$MCP_REGISTRY_CONFIG"
else
  if [[ "$REQUIRE_REGISTRY_ENTRY" -eq 1 ]]; then
    log_warn "Registry" "not found (strict-local expects a tracked registry file)"
  else
    log_success "Registry" "not required"
  fi
fi

MCP_SERVER_CARD="${MCP_SERVER_CARD:-$REPO_ROOT/.well-known/mcp/server-card.json}"
if [[ "$JSON_MODE" -ne 1 ]]; then
  echo ""
  ui_header "Server Card (SEP-1649)"
fi
if [[ -f "$MCP_SERVER_CARD" ]]; then
  if command -v jq >/dev/null 2>&1 && jq empty "$MCP_SERVER_CARD" >/dev/null 2>&1; then
    log_success "Server card" "$MCP_SERVER_CARD"
    has_card_version="$(jq -r '.cardVersion // empty' "$MCP_SERVER_CARD")"
    has_card_name="$(jq -r '.name // empty' "$MCP_SERVER_CARD")"
    has_card_capabilities="$(jq -e '.capabilities' "$MCP_SERVER_CARD" >/dev/null 2>&1 && echo "yes" || echo "")"
    has_card_transport="$(jq -e '.transport' "$MCP_SERVER_CARD" >/dev/null 2>&1 && echo "yes" || echo "")"
    [[ -n "$has_card_version" ]] && log_success "Card version" "$has_card_version" || log_warn "Card version" "missing cardVersion field"
    [[ -n "$has_card_name" ]] && log_success "Card name" "$has_card_name" || log_warn "Card name" "missing name field"
    [[ -n "$has_card_capabilities" ]] && log_success "Card capabilities" "present" || log_warn "Card capabilities" "missing capabilities block"
    [[ -n "$has_card_transport" ]] && log_success "Card transport" "present" || log_warn "Card transport" "missing transport block"
  else
    log_fail "Server card" "invalid JSON"
  fi
else
  log_warn "Server card" "not found (expected $MCP_SERVER_CARD)"
fi

if [[ "$JSON_MODE" -ne 1 ]]; then
  echo ""
  ui_header "Validation"
fi
if command -v jq >/dev/null 2>&1; then
  if [[ -f "$MCP_CONFIG" ]] && jq empty "$MCP_CONFIG" >/dev/null 2>&1; then
    log_success "JSON syntax" "valid"
    JSON_VALID=1
  else
    log_fail "JSON syntax" "invalid"
  fi

  if [[ "$JSON_VALID" -eq 1 ]]; then
    SERVER_COUNT="$(jq '.mcpServers | keys | length' "$MCP_CONFIG" 2>/dev/null || echo 0)"
    if [[ "$SERVER_COUNT" -gt 0 ]]; then
      log_success "MCP servers" "$SERVER_COUNT configured"
    else
      log_fail "MCP servers" "none configured"
    fi

    if jq -e --argjson blocked "$BLOCKED_PATHS" '.mcpServers.filesystem.args[]? as $arg | $blocked[] | select(. == $arg)' "$MCP_CONFIG" >/dev/null 2>&1; then
      log_warn "Filesystem scope" "too broad (use a project-scoped directory)"
    else
      log_success "Filesystem scope" "not globally broad"
    fi

    # MCP operational policy: allow known launchers only.
    unknown_launchers="$(jq -r --argjson allowed "$ALLOWED_LAUNCHERS" '.mcpServers | to_entries[]? | select((.value.command as $cmd | [$allowed[] | select(. == $cmd)] | length) == 0) | "\(.key):\(.value.command)"' "$MCP_CONFIG" 2>/dev/null || true)"
    if [[ -n "$unknown_launchers" ]]; then
      while IFS= read -r item; do
        [[ -z "$item" ]] && continue
        log_warn "Launcher policy" "review non-standard command $item"
      done <<<"$unknown_launchers"
    else
      log_success "Launcher policy" "all server launchers are allowlisted (npx/node/uvx)"
    fi

    # MCP policy: flag wildcard/potentially risky args for review.
    risky_args="$(jq -r --argjson blocked "$BLOCKED_ARG_PATTERNS" '
      .mcpServers
      | to_entries[]?
      | .key as $name
      | (.value.args // [])[]?
      | . as $arg
      | select(any($blocked[]; . as $pattern | ($arg | test($pattern))))
      | "\($name):\($arg)"
    ' "$MCP_CONFIG" 2>/dev/null || true)"
    if [[ -n "$risky_args" ]]; then
      while IFS= read -r item; do
        [[ -z "$item" ]] && continue
        log_warn "Arg policy" "review risky argument $item"
      done <<<"$risky_args"
    else
      log_success "Arg policy" "no high-risk wildcard/unsafe args found"
    fi

    forbidden_default_servers="$(jq -r --argjson forbidden "$FORBIDDEN_DEFAULT_SERVERS" '
      .mcpServers
      | keys[]
      | . as $server
      | select(any($forbidden[]; . == $server))
    ' "$MCP_CONFIG" 2>/dev/null || true)"
    if [[ -n "$forbidden_default_servers" ]]; then
      while IFS= read -r item; do
        [[ -z "$item" ]] && continue
        log_warn "Default server policy" "$item enabled in strict-local profile"
      done <<<"$forbidden_default_servers"
    else
      log_success "Default server policy" "local-only default set"
    fi

    invalid_transports="$(jq -r --argjson trusted "$TRUSTED_TRANSPORTS" '
      .mcpServers
      | to_entries[]?
      | .key as $name
      | (.value.transport // "stdio") as $transport
      | select(([$trusted[] | select(. == $transport)] | length) == 0)
      | "\($name):\($transport)"
    ' "$MCP_CONFIG" 2>/dev/null || true)"
    if [[ -n "$invalid_transports" ]]; then
      while IFS= read -r item; do
        [[ -z "$item" ]] && continue
        log_warn "Transport policy" "review untrusted transport $item"
      done <<<"$invalid_transports"
    else
      log_success "Transport policy" "all servers use trusted transports"
    fi

    if [[ "$REQUIRE_HTTPS_FOR_HTTP" -eq 1 ]]; then
      insecure_http_servers="$(jq -r '
        .mcpServers
        | to_entries[]?
        | select((.value.transport // "") == "http")
        | select((.value.url // "") | startswith("https://") | not)
        | .key
      ' "$MCP_CONFIG" 2>/dev/null || true)"
      if [[ -n "$insecure_http_servers" ]]; then
        while IFS= read -r item; do
          [[ -z "$item" ]] && continue
          log_warn "Transport security" "$item uses non-HTTPS HTTP transport"
        done <<<"$insecure_http_servers"
      else
        log_success "Transport security" "HTTP transports are HTTPS"
      fi
    fi

    # Streamable-HTTP HTTPS validation
    insecure_streamable_servers="$(jq -r '
      .mcpServers
      | to_entries[]?
      | select((.value.transport // "") == "streamable-http")
      | select((.value.url // "") | startswith("https://") | not)
      | .key
    ' "$MCP_CONFIG" 2>/dev/null || true)"
    if [[ -n "$insecure_streamable_servers" ]]; then
      while IFS= read -r item; do
        [[ -z "$item" ]] && continue
        log_warn "Transport security" "$item streamable-http transport must use HTTPS"
      done <<<"$insecure_streamable_servers"
    fi

    # Auth Profiles validation
    if command -v jq >/dev/null 2>&1 && [[ -f "$MCP_POLICY_CONFIG" ]]; then
      declared_auth="$(jq -c '.profiles[.defaultProfile].authProfiles // []' "$MCP_POLICY_CONFIG" 2>/dev/null)"
      if [[ "$declared_auth" != "[]" ]]; then
        log_success "Auth profiles" "declared: $declared_auth"
        # Check transport/auth compatibility: streamable-http/http servers need more than "none"
        incompatible_auth="$(jq -r --argjson registry "$APPROVED_REGISTRY" --argjson allowed_auth "$declared_auth" '
          .mcpServers
          | to_entries[]?
          | .key as $name
          | (.value.transport // "stdio") as $t
          | select($t == "http" or $t == "streamable-http")
          | select($registry[$name].authProfile // "none" | IN($allowed_auth[]) | not)
          | "\($name):\($registry[$name].authProfile // "none")"
        ' "$MCP_CONFIG" 2>/dev/null || true)"
        if [[ -n "$incompatible_auth" ]]; then
          while IFS= read -r item; do
            [[ -z "$item" ]] && continue
            log_warn "Auth compatibility" "$item uses auth profile not in policy"
          done <<<"$incompatible_auth"
        else
          log_success "Auth compatibility" "all server auth profiles match policy"
        fi
      fi
    fi

    if [[ "$REQUIRE_OAUTH_FOR_HTTP" -eq 1 ]]; then
      non_oauth_http_servers="$(jq -r --argjson registry "$APPROVED_REGISTRY" '
        .mcpServers
        | to_entries[]?
        | .key as $name
        | select((.value.transport // "") == "http")
        | select(($registry[$name].auth // "") != "oauth2")
        | $name
      ' "$MCP_CONFIG" 2>/dev/null || true)"
      if [[ -n "$non_oauth_http_servers" ]]; then
        while IFS= read -r item; do
          [[ -z "$item" ]] && continue
          log_warn "Auth policy" "$item HTTP transport is not registered for OAuth2"
        done <<<"$non_oauth_http_servers"
      else
        log_success "Auth policy" "HTTP transports are registry-approved for OAuth2"
      fi
    fi

    env_vars="$(
      {
        jq -r '.mcpServers | to_entries[]? | (.value.env // {}) | to_entries[]?.value' "$MCP_CONFIG"
        jq -r '.mcpServers | to_entries[]? | (.value.args // [])[]?' "$MCP_CONFIG"
      } | sed -n 's/^\${\([A-Z0-9_]\+\)}$/\1/p' | sort -u
    )"
    if [[ -z "$env_vars" ]]; then
      log_success "Server env placeholders" "none declared"
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

    while IFS=$'\t' read -r server env_key; do
      [[ -z "${server:-}" ]] && continue
      if ! jq -e --arg server "$server" '.mcpServers[$server]' "$MCP_CONFIG" >/dev/null 2>&1; then
        continue
      fi
      if [[ -n "${!env_key:-}" ]]; then
        log_success "Token check" "$env_key is set for $server MCP server"
      else
        log_warn "Token check" "$env_key missing for $server MCP server"
      fi
    done < <(jq -r '
      to_entries[]
      | .key as $server
      | (.value // [])[]
      | [$server, .]
      | @tsv
    ' <<<"$REQUIRED_ENV_RULES" 2>/dev/null || true)

    if [[ "$POLICY_WARN_ON_UNPINNED_NPX" -eq 1 ]]; then
      unpinned_npx_servers="$(jq -r '
        .mcpServers
        | to_entries[]?
        | select(.value.command == "npx")
        | select((.value.args // []) | any(
            test("^[A-Za-z0-9@._/-]+$")
            and (startswith("-") | not)
            and (test("^(@[^/]+/[^@]+|[^@]+)@[^@]+$") | not)
          ))
        | .key
      ' "$MCP_CONFIG" 2>/dev/null || true)"
      if [[ -n "$unpinned_npx_servers" ]]; then
        while IFS= read -r item; do
          [[ -z "$item" ]] && continue
          log_warn "Package pinning" "$item uses unpinned npx package"
        done <<<"$unpinned_npx_servers"
      else
        log_success "Package pinning" "no unpinned npx packages found"
      fi
    fi

    if [[ "$REQUIRE_APPROVED_PACKAGE_LOCK" -eq 1 ]]; then
      approved_package_mismatches="$(jq -r --argjson approved "$APPROVED_PACKAGE_LOCK" '
        .mcpServers
        | to_entries[]?
        | .key as $server
        | .value.command as $command
        | ((.value.args // []) | map(select(test("^[A-Za-z0-9@._/-]+@[A-Za-z0-9._-]+$"))) | .[0] // "") as $pkg
        | select($command == "npx")
        | select(($approved[$server].package // "") != $pkg)
        | "\($server)\t\($pkg)\t\($approved[$server].package // "untracked")"
      ' "$MCP_CONFIG" 2>/dev/null || true)"
      if [[ -n "$approved_package_mismatches" ]]; then
        while IFS=$'\t' read -r server actual expected; do
          [[ -z "${server:-}" ]] && continue
          log_warn "Package lock" "$server uses $actual (approved: $expected)"
        done <<<"$approved_package_mismatches"
      else
        log_success "Package lock" "all active servers match approved package refs"
      fi
    fi

    if [[ "$REQUIRE_REGISTRY_ENTRY" -eq 1 ]]; then
      registry_mismatches="$(jq -r --argjson registry "$APPROVED_REGISTRY" '
        .mcpServers
        | to_entries[]?
        | .key as $server
        | (.value.command // "") as $command
        | (.value.transport // "stdio") as $transport
        | ((.value.args // []) | map(select(test("^[A-Za-z0-9@._/-]+@[A-Za-z0-9._-]+$"))) | .[0] // "") as $pkg
        | (.value.url // "") as $url
        | select(($registry[$server] | type) != "object"
            or ($registry[$server].transport // "stdio") != $transport
            or ($registry[$server].launcher // "") != $command
            or (($command == "npx") and (($registry[$server].package // "") != $pkg))
            or (($transport == "http") and (($registry[$server].url // "") != $url)))
        | "\($server)\t\($transport)\t\($command)\t\($pkg)\t\($url)"
      ' "$MCP_CONFIG" 2>/dev/null || true)"
      if [[ -n "$registry_mismatches" ]]; then
        while IFS=$'\t' read -r server _transport command pkg url; do
          [[ -z "${server:-}" ]] && continue
          log_warn "Registry policy" "$server is missing or diverges from the tracked MCP registry"
        done <<<"$registry_mismatches"
      else
        log_success "Registry policy" "all active servers match the tracked MCP registry"
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

if [[ "$Errors" -eq 0 ]]; then
  if [[ "$Warnings" -eq 0 ]]; then
    if [[ "$JSON_MODE" -ne 1 ]]; then
      ui_ok "MCP configuration healthy"
    fi
  else
    if [[ "$STRICT_MODE" -eq 1 ]]; then
      if [[ "$JSON_MODE" -ne 1 ]]; then
        ui_err "MCP issues found" "$Warnings policy warnings (strict mode)"
      fi
      exit 1
    else
      if [[ "$JSON_MODE" -ne 1 ]]; then
        ui_warn "MCP configuration healthy" "$Warnings warnings"
      fi
    fi
  fi
else
  if [[ "$JSON_MODE" -ne 1 ]]; then
    ui_err "MCP issues found" "$Errors errors, $Warnings warnings"
  fi
  exit 1
fi
