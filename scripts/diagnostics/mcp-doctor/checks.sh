#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck shell=bash
# Policy checks of dot mcp doctor, one function per rule. Sourced by
# scripts/diagnostics/mcp-doctor.sh; uses its log_* helpers and policy globals
# (MCP_CONFIG, ALLOWED_LAUNCHERS, REQUIRE_*, ...).

# Configured MCP server count
_mcp_check_servers() {
  SERVER_COUNT="$(jq '.mcpServers | keys | length' "$MCP_CONFIG" 2>/dev/null || echo 0)"
  if [[ "$SERVER_COUNT" -gt 0 ]]; then
    log_success "MCP servers" "$SERVER_COUNT configured"
  else
    log_fail "MCP servers" "none configured"
  fi
}

# The filesystem server must not be given a blocked path
_mcp_check_blocked_paths() {
  if jq -e --argjson blocked "$BLOCKED_PATHS" '.mcpServers.filesystem.args[]? as $arg | $blocked[] | select(. == $arg)' "$MCP_CONFIG" >/dev/null 2>&1; then
    log_warn "Filesystem scope" "too broad (use a project-scoped directory)"
  else
    log_success "Filesystem scope" "not globally broad"
  fi
}

_mcp_check_launchers() {
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
}

_mcp_check_risky_args() {
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
}

# Servers the policy forbids in the default profile
_mcp_check_default_servers() {
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
}

# Every server's transport is on the trusted list
_mcp_check_transports() {
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
}

_mcp_check_https() {
  # HTTPS for remote transports. Both http and streamable-http carry the
  # session over the network; streamable-http is always held to HTTPS,
  # and requireHttpsForHttpTransports extends the rule to plain http.
  # One verdict, so a success line never sits beside a failure.
  https_transports='["streamable-http"]'
  [[ "$REQUIRE_HTTPS_FOR_HTTP" -eq 1 ]] && https_transports='["http","streamable-http"]'
  insecure_http_servers="$(jq -r --argjson ts "$https_transports" '
      .mcpServers
      | to_entries[]?
      | (.value.transport // "") as $t
      | select($t | IN($ts[]))
      | select((.value.url // "") | startswith("https://") | not)
      | "\(.key)\t\($t)"
    ' "$MCP_CONFIG" 2>/dev/null || true)"
  if [[ -n "$insecure_http_servers" ]]; then
    while IFS=$'\t' read -r item transport; do
      [[ -z "$item" ]] && continue
      log_warn "Transport security" "$item $transport transport must use HTTPS"
    done <<<"$insecure_http_servers"
  elif [[ "$REQUIRE_HTTPS_FOR_HTTP" -eq 1 ]]; then
    log_success "Transport security" "HTTP transports are HTTPS"
  fi
}

_mcp_check_auth_profiles() {
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
}

# OAuth2 for http/streamable-http servers when the policy requires it
_mcp_check_oauth() {
  if [[ "$REQUIRE_OAUTH_FOR_HTTP" -eq 1 ]]; then
    non_oauth_http_servers="$(jq -r --argjson registry "$APPROVED_REGISTRY" '
        .mcpServers
        | to_entries[]?
        | .key as $name
        | select((.value.transport // "") | IN("http", "streamable-http"))
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
}

# Every ${VAR} placeholder a server declares is set
_mcp_check_env_placeholders() {
  env_vars="$(
    {
      jq -r '.mcpServers | to_entries[]? | (.value.env // {}) | to_entries[]?.value' "$MCP_CONFIG"
      jq -r '.mcpServers | to_entries[]? | (.value.args // [])[]?' "$MCP_CONFIG"
    } | sed -n 's/^\${\([A-Z0-9_][A-Z0-9_]*\)}$/\1/p' | sort -u
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
}

# Token env vars named by each server are set
_mcp_check_tokens() {
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
}

# npx launchers should pin a version
_mcp_check_unpinned_npx() {
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
}

# Servers must match the approved package lock
_mcp_check_package_lock() {
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
}

# Servers must have a registry entry
_mcp_check_registry() {
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
      while IFS=$'\t' read -r server _transport _command _pkg _url; do
        [[ -z "${server:-}" ]] && continue
        log_warn "Registry policy" "$server is missing or diverges from the tracked MCP registry"
      done <<<"$registry_mismatches"
    else
      log_success "Registry policy" "all active servers match the tracked MCP registry"
    fi
  fi
}
