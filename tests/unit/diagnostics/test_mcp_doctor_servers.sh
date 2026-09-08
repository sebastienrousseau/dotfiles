#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural coverage for the *per-server* policy checks in
# scripts/diagnostics/mcp-doctor.sh: launcher allowlist, filesystem scope,
# risky args, forbidden default servers, transport trust, HTTPS/OAuth
# requirements, auth-profile compatibility, env placeholders, required
# tokens, npx pinning, package-lock and registry conformance.
#
# Each check gets both verdicts (clean + flagged). Fixtures live in the
# coverage sandbox and reach the script through its own env overrides, so
# nothing on the host is read or written.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

DOCTOR="$REPO_ROOT/scripts/diagnostics/mcp-doctor.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

FIX="$DOTFILES_COV_TMPDIR/fixtures"
mkdir -p "$FIX"
OUTF="$DOTFILES_COV_TMPDIR/doctor-out.txt"
NONE="$FIX/none.json"

# doctor <env-assignments…> [-- <script-args…>] — run mcp-doctor under the
# given environment, writing its report to $OUTF and its status to RC.
doctor() {
  local -a envs=() args=()
  while (($#)); do
    if [[ "$1" == "--" ]]; then
      shift
      args=("$@")
      break
    fi
    envs+=("$1")
    shift
  done
  # The report is kept in a FILE, never in a shell variable: a captured
  # multi-line report becomes a kilobyte-long xtrace record, and long
  # records get truncated in the coverage trace, silently dropping the
  # coverage of the lines that produced them. stderr is deliberately left
  # attached to ours so the child's xtrace still reaches the trace file.
  env "${envs[@]}" bash "$DOCTOR" ${args[@]+"${args[@]}"} >"$OUTF" </dev/null
  RC=$?
  return 0
}

# out_has <needle> [msg] / out_lacks <needle> [msg] — assert on the report.
out_has() { assert_file_contains "$OUTF" "$1" "${2:-output contains $1}"; }
out_lacks() {
  if grep -qF -- "$1" "$OUTF"; then
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: ${2:-output should not contain $1}"
  else
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: ${2:-output lacks $1}"
  fi
}
# out_json <jq-filter> — read one field out of a --json run.
out_json() { jq -r "$1" <"$OUTF"; }

# check <config-file> <policy-file> [extra-env…] — the common invocation.
check() {
  local cfg="$1" pol="$2"
  shift 2
  doctor "MCP_CONFIG=$cfg" "MCP_POLICY_CONFIG=$pol" \
    "MCP_LOCK_CONFIG=$FIX/lock.json" "MCP_REGISTRY_CONFIG=$FIX/registry.json" \
    "MCP_SERVER_CARD=$NONE" "$@"
}

printf '{"packages":{"filesystem":{"package":"@modelcontextprotocol/server-filesystem@1.0.0"}}}' \
  >"$FIX/lock.json"
cat >"$FIX/registry.json" <<'JSON'
{"servers":{
  "filesystem":{"transport":"stdio","launcher":"npx","package":"@modelcontextprotocol/server-filesystem@1.0.0","authProfile":"none"},
  "remote":{"transport":"http","launcher":"npx","package":"","url":"https://mcp.example.com","auth":"oauth2","authProfile":"env-token"},
  "other":{"transport":"http","launcher":"npx","package":"","url":"https://x.example","auth":"oauth2","authProfile":"bearer-static"}
}}
JSON

# Policy with every gate ON — the "strict-local" shape the repo ships.
FULL_POLICY="$FIX/full-policy.json"
cat >"$FULL_POLICY" <<'JSON'
{
  "defaultProfile": "strict-local",
  "profiles": {
    "strict-local": {
      "allowedLaunchers": ["npx", "node", "uvx"],
      "blockedFilesystemRoots": ["/", "/home", "/Users"],
      "blockedArgPatterns": ["^--allow-.*", "^--unsafe$"],
      "forbidNetworkServersByDefault": ["brave-search"],
      "requiredEnvByServer": {"github": ["GITHUB_TOKEN"]},
      "trustedTransports": ["stdio", "http"],
      "authProfiles": ["none", "env-token"],
      "warnOnUnpinnedNpx": true,
      "requireApprovedPackageLock": true,
      "requireRegistryEntry": true,
      "requireHttpsForHttpTransports": true,
      "requireOauthForHttpTransports": true
    }
  }
}
JSON

# A config that satisfies every gate above.
CLEAN="$FIX/clean.json"
cat >"$CLEAN" <<'JSON'
{"mcpServers":{
  "filesystem":{"command":"npx","args":["@modelcontextprotocol/server-filesystem@1.0.0"]},
  "remote":{"command":"npx","transport":"http","url":"https://mcp.example.com","args":[]}
}}
JSON

test_start "clean_config_passes_every_policy_gate"
check "$CLEAN" "$FULL_POLICY"
assert_equals 0 "$RC" "rc"
out_has "all server launchers are allowlisted" "launcher policy"
out_has "no high-risk wildcard/unsafe args" "arg policy"
out_has "local-only default set" "default server policy"
out_has "all servers use trusted transports" "transport policy"
out_has "HTTP transports are HTTPS" "transport security"
out_has "all server auth profiles match policy" "auth compatibility"
out_has "HTTP transports are registry-approved for OAuth2" "auth policy"
out_has "no unpinned npx packages found" "package pinning"
out_has "all active servers match approved package refs" "package lock"
out_has "all active servers match the tracked MCP registry" "registry policy"
out_has "not globally broad" "filesystem scope"
out_has "none declared" "env placeholders"

test_start "broad_filesystem_scope_is_flagged"
printf '{"mcpServers":{"filesystem":{"command":"npx","args":["/"]}}}' >"$FIX/broad.json"
check "$FIX/broad.json" "$FULL_POLICY"
out_has "too broad (use a project-scoped directory)" "warning"

test_start "non_allowlisted_launcher_is_flagged"
printf '{"mcpServers":{"weird":{"command":"bash","args":["-c","true"]}}}' >"$FIX/launcher.json"
check "$FIX/launcher.json" "$FULL_POLICY"
out_has "review non-standard command weird:bash" "warning names the server"

test_start "risky_args_are_flagged"
printf '{"mcpServers":{"fs":{"command":"npx","args":["--unsafe","--allow-everything"]}}}' >"$FIX/risky.json"
check "$FIX/risky.json" "$FULL_POLICY"
out_has "review risky argument fs:--unsafe" "unsafe flag"
out_has "review risky argument fs:--allow-everything" "allow- flag"

test_start "forbidden_default_server_is_flagged"
printf '{"mcpServers":{"brave-search":{"command":"npx","args":["pkg@1.0.0"]}}}' >"$FIX/forbidden.json"
check "$FIX/forbidden.json" "$FULL_POLICY"
out_has "brave-search enabled in strict-local profile" "warning"

test_start "untrusted_transport_is_flagged"
printf '{"mcpServers":{"ws":{"command":"npx","transport":"websocket","args":["pkg@1.0.0"]}}}' >"$FIX/transport.json"
check "$FIX/transport.json" "$FULL_POLICY"
out_has "review untrusted transport ws:websocket" "warning"

test_start "plain_http_transport_url_is_flagged"
printf '{"mcpServers":{"remote":{"command":"npx","transport":"http","url":"http://mcp.example.com","args":[]}}}' \
  >"$FIX/insecure.json"
check "$FIX/insecure.json" "$FULL_POLICY"
out_has "remote uses non-HTTPS HTTP transport" "warning"

test_start "streamable_http_must_use_https"
printf '{"mcpServers":{"stream":{"command":"npx","transport":"streamable-http","url":"http://x.example","args":[]}}}' \
  >"$FIX/stream.json"
check "$FIX/stream.json" "$FULL_POLICY"
out_has "stream streamable-http transport must use HTTPS" "warning"

test_start "auth_profile_outside_policy_is_flagged"
# The registry gives "other" the authProfile "bearer-static", which the
# policy's authProfiles list does not allow.
printf '{"mcpServers":{"other":{"command":"npx","transport":"http","url":"https://x.example","args":[]}}}' \
  >"$FIX/auth.json"
check "$FIX/auth.json" "$FULL_POLICY"
out_has "uses auth profile not in policy" "auth compatibility warning"

test_start "http_transport_without_registered_oauth_is_flagged"
NO_OAUTH_REG="$FIX/registry-no-oauth.json"
jq '.servers.remote.auth = "none"' "$FIX/registry.json" >"$NO_OAUTH_REG"
doctor "MCP_CONFIG=$CLEAN" "MCP_POLICY_CONFIG=$FULL_POLICY" \
  "MCP_LOCK_CONFIG=$FIX/lock.json" "MCP_REGISTRY_CONFIG=$NO_OAUTH_REG" \
  "MCP_SERVER_CARD=$NONE"
out_has "remote HTTP transport is not registered for OAuth2" "warning"

test_start "unset_env_placeholder_is_flagged"
printf '{"mcpServers":{"gh":{"command":"npx","args":["pkg@1.0.0"],"env":{"TOKEN":"${DOTFILES_MCP_TEST_TOKEN}"}}}}' \
  >"$FIX/env.json"
check "$FIX/env.json" "$FULL_POLICY"
out_has "DOTFILES_MCP_TEST_TOKEN is not set" "warning"

test_start "set_env_placeholder_passes"
check "$FIX/env.json" "$FULL_POLICY" "DOTFILES_MCP_TEST_TOKEN=xyz"
out_has "all referenced placeholders are set" "ok"

test_start "required_token_missing_for_a_configured_server"
printf '{"mcpServers":{"github":{"command":"npx","args":["pkg@1.0.0"]}}}' >"$FIX/github.json"
check "$FIX/github.json" "$FULL_POLICY" "GITHUB_TOKEN="
out_has "GITHUB_TOKEN missing for github MCP server" "warning"

test_start "required_token_present_for_a_configured_server"
check "$FIX/github.json" "$FULL_POLICY" "GITHUB_TOKEN=ghp_test"
out_has "GITHUB_TOKEN is set for github MCP server" "ok"

test_start "required_token_rule_skipped_when_the_server_is_absent"
check "$CLEAN" "$FULL_POLICY" "GITHUB_TOKEN="
out_lacks "for github MCP server" "no token row for an absent server"

test_start "unpinned_npx_package_is_flagged"
printf '{"mcpServers":{"fs":{"command":"npx","args":["@modelcontextprotocol/server-filesystem"]}}}' \
  >"$FIX/unpinned.json"
check "$FIX/unpinned.json" "$FULL_POLICY"
out_has "fs uses unpinned npx package" "warning"

test_start "package_not_matching_the_lock_is_flagged"
printf '{"mcpServers":{"filesystem":{"command":"npx","args":["@modelcontextprotocol/server-filesystem@9.9.9"]}}}' \
  >"$FIX/drifted.json"
check "$FIX/drifted.json" "$FULL_POLICY"
out_has "filesystem uses @modelcontextprotocol/server-filesystem@9.9.9" "actual"
out_has "approved: @modelcontextprotocol/server-filesystem@1.0.0" "expected"

test_start "server_missing_from_the_registry_is_flagged"
printf '{"mcpServers":{"ghost":{"command":"npx","args":["ghost@1.0.0"]}}}' >"$FIX/ghost.json"
check "$FIX/ghost.json" "$FULL_POLICY"
out_has "ghost is missing or diverges from the tracked MCP registry" "warning"

test_start "invalid_lock_and_registry_json_fall_back_to_empty_sets"
printf 'nope' >"$FIX/lock-bad.json"
printf 'nope' >"$FIX/registry-bad.json"
doctor "MCP_CONFIG=$CLEAN" "MCP_POLICY_CONFIG=$FULL_POLICY" \
  "MCP_LOCK_CONFIG=$FIX/lock-bad.json" "MCP_REGISTRY_CONFIG=$FIX/registry-bad.json" \
  "MCP_SERVER_CARD=$NONE"
out_has "approved:" "every server counts as untracked"
out_has "diverges from the tracked MCP registry" "registry mismatch"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
