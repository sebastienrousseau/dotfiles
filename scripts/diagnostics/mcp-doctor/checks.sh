#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck shell=bash
# Sourced by mcp-doctor.sh; inherits set -euo pipefail
# Policy checks of dot mcp doctor, one function per rule. Sourced by
# scripts/diagnostics/mcp-doctor.sh; uses its log_* helpers and policy globals
# (MCP_CONFIG, ALLOWED_LAUNCHERS, REQUIRE_*, ...).

# jq definitions shared by the checks. Claude Code names a server's
# transport with `type`; `transport` is the older key some configs use.
MCP_JQ_DEFS='def mcp_transport: (.type // .transport // "stdio");'
# Installed-binary prefixes the policy allows besides allowedLaunchers
ALLOWED_LAUNCHER_PREFIXES='[]'

# Configured MCP server count
_mcp_check_servers() {
  SERVER_COUNT="$(jq '.mcpServers | keys | length' "$MCP_CONFIG" 2>/dev/null || echo 0)"
  if [[ "$SERVER_COUNT" -gt 0 ]]; then
    log_success "MCP servers" "$SERVER_COUNT configured"
  else
    log_fail "MCP servers" "none configured"
  fi
}

# No server may be given a blocked root, or a path above one. Every server's
# args are checked (a renamed filesystem server is still one), after
# expanding ~ / ${HOME} and --opt= prefixes and normalising . and .. the way
# realpath -m does, so /home/seb/.. and // are caught. An error, not a warning.
_mcp_check_blocked_paths() {
  local broad item
  broad="$(jq -r --argjson blocked "$BLOCKED_PATHS" --arg home "$HOME" '
      def norm: split("/")
        | reduce .[] as $s ([]; if $s == "" or $s == "." then . elif $s == ".." then .[:-1] else . + [$s] end)
        | "/" + join("/");
      def expand: sub("^-[^=]*="; "") | sub("^(~|\\$\\{HOME\\}|\\$HOME)(?=/|$)"; $home);
      ($blocked | map(norm)) as $roots
      | .mcpServers
      | to_entries[]?
      | .key as $name
      | (.value.args // [])[]?
      | strings
      | . as $arg
      | expand
      | select(startswith("/"))
      | norm as $p
      | select(any($roots[]; . == $p or $p == "/" or startswith($p + "/")))
      | "\($name):\($arg)"
    ' "$MCP_CONFIG" 2>/dev/null || true)"
  if [[ -n "$broad" ]]; then
    while IFS= read -r item; do
      [[ -z "$item" ]] && continue
      log_fail "Filesystem scope" "$item too broad (use a project-scoped directory)"
    done <<<"$broad"
  else
    log_success "Filesystem scope" "not globally broad"
  fi
}

# Shells and runtimes told to run code given on the command line: the
# config is then the program, and no package pin or lock covers it.
_mcp_check_inline_launchers() {
  local inline item how
  inline="$(jq -r '
      .mcpServers
      | to_entries[]?
      | .key as $name
      | ((.value.command // "") | split("/") | last) as $cmd
      | [(.value.args // [])[]? | strings] as $args
      | if ($cmd | test("^node(js)?$")) and any($args[]; test("^-[A-Za-z]*[ep][A-Za-z]*$|^--(eval|print)(=|$)")) then "\($name)\tnode -e"
        elif ($cmd | test("^(bash|dash|zsh|ksh|fish|sh)$|^python[0-9.]*$")) and any($args[]; test("^-[A-Za-z]*c[A-Za-z]*$")) then "\($name)\t\($cmd) -c"
        else empty end
    ' "$MCP_CONFIG" 2>/dev/null || true)"
  if [[ -n "$inline" ]]; then
    while IFS=$'\t' read -r item how; do
      [[ -z "$item" ]] && continue
      log_warn "Launcher policy" "$item runs inline code ($how)"
    done <<<"$inline"
  else
    log_success "Launcher policy" "no inline-code launchers"
  fi
}

_mcp_check_launchers() {
  # MCP operational policy: allow known launchers only, plus binaries that
  # install-servers.sh put under an allowlisted prefix (no . or .. segment,
  # so a prefix match cannot climb out of it).
  unknown_launchers="$(jq -r --argjson allowed "$ALLOWED_LAUNCHERS" --argjson prefixes "$ALLOWED_LAUNCHER_PREFIXES" '
      .mcpServers
      | to_entries[]?
      | (.value.command // "") as $cmd
      | select(([$allowed[] | select(. == $cmd)] | length) == 0)
      | select(any($prefixes[]; . as $p | $cmd | startswith($p) and (split("/") | any(. == ".." or . == ".") | not)) | not)
      | "\(.key):\(.value.command)"
    ' "$MCP_CONFIG" 2>/dev/null || true)"
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

# Servers the policy forbids in the default profile, found by key or by the
# package a server runs (a renamed github server is still the github server)
_mcp_check_default_servers() {
  local item via
  forbidden_default_servers="$(jq -r --argjson forbidden "$FORBIDDEN_DEFAULT_SERVERS" '
      def base: sub("^-[^=]*="; "") | sub("==.*$"; "") | sub("(?<=.)@[^@/]*$"; "") | split("/") | last;
      [ .mcpServers
        | to_entries[]?
        | .key as $name
        | [(.value.args // [])[]? | strings | base] as $bases
        | $forbidden[] as $f
        | if $name == $f then "\($name)\t"
          elif any($bases[]; IN($f, "server-" + $f, "mcp-server-" + $f, "mcp-" + $f, $f + "-mcp", $f + "-mcp-server")) then "\($name)\t\($f)"
          else empty end
      ] | unique[]
    ' "$MCP_CONFIG" 2>/dev/null || true)"
  if [[ -n "$forbidden_default_servers" ]]; then
    while IFS=$'\t' read -r item via; do
      [[ -z "$item" ]] && continue
      if [[ -n "$via" ]]; then
        log_warn "Default server policy" "$item enabled in strict-local profile (runs the $via server)"
      else
        log_warn "Default server policy" "$item enabled in strict-local profile"
      fi
    done <<<"$forbidden_default_servers"
  else
    log_success "Default server policy" "local-only default set"
  fi
}

# Every server's transport is on the trusted list
_mcp_check_transports() {
  invalid_transports="$(jq -r --argjson trusted "$TRUSTED_TRANSPORTS" "$MCP_JQ_DEFS"'
      .mcpServers
      | to_entries[]?
      | .key as $name
      | (.value | mcp_transport) as $transport
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
  # HTTPS for remote transports. http, sse and streamable-http all carry
  # the session over the network; sse and streamable-http are always held
  # to HTTPS, and requireHttpsForHttpTransports extends the rule to plain
  # http. An error, not a warning. One verdict, so a success line never
  # sits beside a failure.
  https_transports='["sse","streamable-http"]'
  [[ "$REQUIRE_HTTPS_FOR_HTTP" -eq 1 ]] && https_transports='["http","sse","streamable-http"]'
  insecure_http_servers="$(jq -r --argjson ts "$https_transports" "$MCP_JQ_DEFS"'
      .mcpServers
      | to_entries[]?
      | (.value | mcp_transport) as $t
      | select($t | IN($ts[]))
      | select((.value.url // "") | startswith("https://") | not)
      | "\(.key)\t\($t)"
    ' "$MCP_CONFIG" 2>/dev/null || true)"
  if [[ -n "$insecure_http_servers" ]]; then
    while IFS=$'\t' read -r item transport; do
      [[ -z "$item" ]] && continue
      log_fail "Transport security" "$item $transport transport must use HTTPS"
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
      incompatible_auth="$(jq -r --argjson registry "$APPROVED_REGISTRY" --argjson allowed_auth "$declared_auth" "$MCP_JQ_DEFS"'
          .mcpServers
          | to_entries[]?
          | .key as $name
          | (.value | mcp_transport) as $t
          | select($t | IN("http", "sse", "streamable-http"))
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
    non_oauth_http_servers="$(jq -r --argjson registry "$APPROVED_REGISTRY" "$MCP_JQ_DEFS"'
        .mcpServers
        | to_entries[]?
        | .key as $name
        | select(.value | mcp_transport | IN("http", "sse", "streamable-http"))
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

# npx launchers should pin an exact version of the package they run (the
# first positional arg); @latest, ranges and bare names float
_mcp_check_unpinned_npx() {
  if [[ "$POLICY_WARN_ON_UNPINNED_NPX" -eq 1 ]]; then
    unpinned_npx_servers="$(jq -r '
        .mcpServers
        | to_entries[]?
        | select((.value.command // "") | split("/") | last == "npx")
        | ([(.value.args // [])[]? | strings | select(startswith("-") | not)] | .[0] // "") as $pkg
        | select($pkg != "")
        | select($pkg | test("^(@[^/@]+/)?[^@/]+@[0-9]+\\.[0-9]+\\.[0-9]+([-+][0-9A-Za-z.+-]+)?$") | not)
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

# _mcp_manifest_has <ecosystem> <manifest> <package> <integrity>: the
# committed manifest pins exactly <package> with <integrity>.
_mcp_manifest_has() {
  case "$1" in
    npm)
      jq -e --arg n "${3%@*}" --arg v "${3##*@}" --arg i "$4" \
        '.packages["node_modules/" + $n] | .version == $v and .integrity == $i' "$2" >/dev/null 2>&1
      ;;
    pypi)
      # A requirement starts in column 0; its --hash lines follow, indented.
      [[ -f "$2" ]] && awk -v req="$3" -v hash="--hash=$4" '
        /^[^ #]/ { cur = ($1 == req) }
        cur && index($0, hash) { found = 1 }
        END { exit !found }' "$2"
      ;;
    *) return 1 ;;
  esac
}

# Lock entries with an integrity hash: the server must run the approved
# command, and the manifest the lock names must pin that package with that
# hash. Prints "server<TAB>detail" per mismatch.
_mcp_lock_integrity_mismatches() {
  local server cmd eco manifest pkg integ actual
  while IFS=$'\x1f' read -r server cmd eco manifest pkg integ actual; do
    [[ -n "$server" ]] || continue
    if [[ "$actual" != "$cmd" ]]; then
      printf '%s\t%s\n' "$server" "runs $actual (approved: $cmd)"
    elif ! _mcp_manifest_has "$eco" "$MCP_LOCK_ROOT/$manifest" "$pkg" "$integ"; then
      printf '%s\t%s\n' "$server" "$pkg integrity $integ is not in $manifest"
    fi
  done < <(jq -r --argjson approved "$APPROVED_PACKAGE_LOCK" '
      .mcpServers
      | to_entries[]?
      | .key as $s
      | (.value.command // "") as $actual
      | $approved[$s]
      | select(type == "object" and (.integrity // "") != "")
      | [$s, .command // "", .ecosystem // "", .manifest // "", .package // "", .integrity, $actual]
      | join("\u001f")
    ' "$MCP_CONFIG" 2>/dev/null || true)
}

# Servers must match the approved package lock: npx refs by package@version,
# installed servers by command and manifest integrity
_mcp_check_package_lock() {
  [[ "$REQUIRE_APPROVED_PACKAGE_LOCK" -eq 1 ]] || return 0
  local server actual expected detail found=0
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
  while IFS=$'\t' read -r server actual expected; do
    [[ -z "${server:-}" ]] && continue
    log_warn "Package lock" "$server uses $actual (approved: $expected)"
    found=1
  done <<<"$approved_package_mismatches"
  while IFS=$'\t' read -r server detail; do
    [[ -z "${server:-}" ]] && continue
    log_warn "Package lock" "$server: $detail"
    found=1
  done < <(_mcp_lock_integrity_mismatches)
  [[ "$found" -eq 1 ]] || log_success "Package lock" "all active servers match approved package refs"
}

# Servers must have a registry entry
_mcp_check_registry() {
  if [[ "$REQUIRE_REGISTRY_ENTRY" -eq 1 ]]; then
    registry_mismatches="$(jq -r --argjson registry "$APPROVED_REGISTRY" "$MCP_JQ_DEFS"'
        .mcpServers
        | to_entries[]?
        | .key as $server
        | (.value.command // "") as $command
        | (.value | mcp_transport) as $transport
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
