#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

TEST_SCRIPT="$REPO_ROOT/scripts/diagnostics/mcp-doctor.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox
MCP_CONFIG_FILE="$REPO_ROOT/defaults/dot_config/claude/mcp_servers.json"
MCP_POLICY_FILE="$REPO_ROOT/defaults/dot_config/dotfiles/mcp-policy.json"
MCP_LOCK_FILE="$REPO_ROOT/defaults/dot_config/dotfiles/mcp-lock.json"
MCP_REGISTRY_FILE="$REPO_ROOT/defaults/dot_config/dotfiles/mcp-registry.json"
META_COMMANDS_SCRIPT="$REPO_ROOT/scripts/dot/commands/meta.sh"

test_start "mcp_doctor_exists"
assert_file_exists "$TEST_SCRIPT" "mcp-doctor.sh should exist"

test_start "mcp_doctor_syntax"
if bash -n "$TEST_SCRIPT" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: syntax error"
fi

# meta <args...>: run `dot mcp` through the meta command module.
meta() {
  REPO_ROOT="$REPO_ROOT" MCP_CONFIG="$MCP_CONFIG_FILE" NO_COLOR=1 bash "$META_COMMANDS_SCRIPT" "$@" 2>&1
}

test_start "mcp_meta_accepts_flag_form"
assert_equals "healthy" "$(meta mcp --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["status"])' 2>/dev/null)" \
  "dot mcp --json (flag only) runs the doctor"

test_start "mcp_policy_exists"
assert_file_exists "$MCP_POLICY_FILE" "mcp-policy.json should exist"

test_start "mcp_lock_exists"
assert_file_exists "$MCP_LOCK_FILE" "mcp-lock.json should exist"

test_start "mcp_registry_exists"
assert_file_exists "$MCP_REGISTRY_FILE" "mcp-registry.json should exist"

test_start "mcp_config_local_only_defaults"
for server in filesystem github brave-search fetch puppeteer; do
  if grep -q "\"$server\"" "$MCP_CONFIG_FILE"; then
    ((TESTS_FAILED++))
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: default MCP config should exclude $server"
  else
    ((TESTS_PASSED++))
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: default MCP config excludes $server"
  fi
done

test_start "mcp_config_uses_pinned_package_refs"
# Each shipped server runs the binary its hash-pinned lock entry approves.
MCP_LOCK_FILE="$REPO_ROOT/defaults/dot_config/dotfiles/mcp-lock.json"
for server in git memory sqlite; do
  cmd="$(jq -r --arg s "$server" '.mcpServers[$s].command' "$MCP_CONFIG_FILE")"
  if [[ "$cmd" == "$(jq -r --arg s "$server" '.packages[$s].command' "$MCP_LOCK_FILE")" ]] &&
    [[ -n "$(jq -r --arg s "$server" '.packages[$s].integrity // empty' "$MCP_LOCK_FILE")" ]]; then
    ((TESTS_PASSED++))
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $server runs its locked, integrity-pinned binary"
  else
    ((TESTS_FAILED++))
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $server command $cmd is not the locked one"
  fi
done

test_start "mcp_doctor_json_output"
output=$(REPO_ROOT="$REPO_ROOT" MCP_CONFIG="$MCP_CONFIG_FILE" bash "$TEST_SCRIPT" --json 2>/dev/null) || true
if [[ "$output" == \{* ]] && [[ "$output" == *"\"status\""* ]] && [[ "$output" == *"\"policy_path\""* ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: emits JSON summary"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should emit JSON summary"
  printf '%b\n' "    Output: $output"
fi

test_start "mcp_doctor_short_flag_json_output"
output=$(REPO_ROOT="$REPO_ROOT" MCP_CONFIG="$MCP_CONFIG_FILE" bash "$TEST_SCRIPT" -s -j 2>/dev/null) || true
if [[ "$output" == \{* ]] && [[ "$output" == *"\"status\""* ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: -s -j emits JSON summary"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: -s -j should emit JSON summary"
  printf '%b\n' "    Output: $output"
fi

# Policy enforcement, run against configs that break one rule each.
MCPX="$DOTFILES_COV_TMPDIR/mcp-policy"
mkdir -p "$MCPX"
jq '.mcpServers.rogue={"command":"npx","args":["-y","mcp-server-rogue@1.0.0"],"env":{}}' "$MCP_CONFIG_FILE" >"$MCPX/unregistered.json"
jq '.mcpServers["example-remote"]={"transport":"streamable-http","url":"http://mcp.example.com/v1"}' "$MCP_CONFIG_FILE" >"$MCPX/plain-http.json"
jq '.mcpServers["example-remote"]={"transport":"streamable-http","url":"https://mcp.example.com/v1"}' "$MCP_CONFIG_FILE" >"$MCPX/https.json"
jq '.servers["example-remote"].auth="none" | .servers["example-remote"].authProfile="none"' "$MCP_REGISTRY_FILE" >"$MCPX/registry-no-oauth.json"

# strict <config> [registry]: mcp-doctor --strict; sets S_OUT and S_RC.
strict() {
  local -a extra=()
  [[ -n "${2:-}" ]] && extra=(MCP_REGISTRY_CONFIG="$2")
  S_RC=0
  S_OUT="$(env REPO_ROOT="$REPO_ROOT" MCP_CONFIG="$1" NO_COLOR=1 ${extra[@]+"${extra[@]}"} bash "$TEST_SCRIPT" --strict 2>&1)" || S_RC=$?
}

test_start "mcp_policy_requires_registry_entry"
strict "$MCPX/unregistered.json"
assert_true '[[ $S_RC -ne 0 && $S_OUT == *"rogue is missing or diverges from the tracked MCP registry"* ]]' \
  "a server missing from the registry fails strict mode"

test_start "mcp_policy_requires_https"
strict "$MCPX/plain-http.json"
assert_true '[[ $S_RC -ne 0 && $S_OUT == *"example-remote streamable-http transport must use HTTPS"* && $S_OUT != *"HTTP transports are HTTPS"* ]]' \
  "a streamable-http server on http:// fails, with no contradicting success line"

test_start "mcp_policy_requires_https_for_plain_http"
jq '.mcpServers["example-remote"]={"transport":"http","url":"http://mcp.example.com/v1"}' "$MCP_CONFIG_FILE" >"$MCPX/plain-http-transport.json"
strict "$MCPX/plain-http-transport.json"
assert_true '[[ $S_OUT == *"example-remote http transport must use HTTPS"* ]]' \
  "with requireHttpsForHttpTransports, a plain http transport on http:// is flagged too"

test_start "mcp_policy_requires_oauth_for_streamable_http"
strict "$MCPX/https.json" "$MCPX/registry-no-oauth.json"
assert_true '[[ $S_OUT == *"example-remote HTTP transport is not registered for OAuth2"* ]]' \
  "a streamable-http server registered without OAuth2 is flagged (the rule used to cover only plain http)"

test_start "mcp_policy_https_oauth_server_passes_those_rules"
strict "$MCPX/https.json"
assert_true '[[ $S_OUT == *"HTTP transports are HTTPS"* && $S_OUT == *"HTTP transports are registry-approved for OAuth2"* && $S_OUT != *"must use HTTPS"* ]]' \
  "an HTTPS, OAuth2-registered remote server passes the HTTPS and OAuth rules"

test_start "mcp_meta_registry_subcommand"
assert_true '[[ "$(meta mcp registry)" == *"git"*"mcp-server-git==2026.8.18"* ]]' "dot mcp registry lists the tracked servers"

test_start "mcp_meta_unknown_subcommand_shows_usage"
rc=0
out="$(meta mcp bogus)" || rc=$?
assert_equals "1|Usage: dot mcp [doctor|registry|serve]" "$rc|$out" "an unknown subcommand prints the usage and exits 1"

test_start "mcp_doctor_strict_local_passes"
if REPO_ROOT="$REPO_ROOT" MCP_CONFIG="$MCP_CONFIG_FILE" bash "$TEST_SCRIPT" --strict >/dev/null 2>&1; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: strict-local baseline passes"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: strict-local baseline should pass"
fi

test_start "mcp_doctor_deep_policy_warning_branches"
if command -v jq >/dev/null 2>&1; then
  fixture_dir="$DOTFILES_COV_TMPDIR/mcp-fixtures"
  mkdir -p "$fixture_dir"
  cat >"$fixture_dir/mcp_servers.json" <<'JSON'
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/"]
    },
    "unsafe": {
      "command": "python",
      "args": ["--unsafe"]
    },
    "remote": {
      "transport": "http",
      "command": "node",
      "url": "http://example.invalid/mcp"
    },
    "stream": {
      "transport": "streamable-http",
      "command": "node",
      "url": "http://example.invalid/stream"
    }
  }
}
JSON
  cat >"$fixture_dir/policy.json" <<'JSON'
{
  "defaultProfile": "strict-local",
  "profiles": {
    "strict-local": {
      "allowedLaunchers": ["npx", "node", "uvx"],
      "trustedTransports": ["stdio"],
      "blockedFilesystemRoots": ["/", "/home", "/Users"],
      "blockedArgPatterns": ["^--allow-.*", "^--unsafe$", "^\\\\*$"],
      "forbidNetworkServersByDefault": ["filesystem"],
      "requiredEnvByServer": {"filesystem": ["GITHUB_TOKEN"]},
      "warnOnUnpinnedNpx": true,
      "requireApprovedPackageLock": true,
      "requireRegistryEntry": true,
      "requireHttpsForHttpTransports": true,
      "requireOauthForHttpTransports": true,
      "authProfiles": ["oauth2"]
    }
  }
}
JSON
  cat >"$fixture_dir/lock.json" <<'JSON'
{"packages": {"filesystem": {"package": "@modelcontextprotocol/server-filesystem@2026.3.0"}}}
JSON
  cat >"$fixture_dir/registry.json" <<'JSON'
{"servers": {"remote": {"transport": "http", "launcher": "node", "url": "https://example.invalid/mcp", "auth": "none", "authProfile": "none"}}}
JSON
  output="$(
    REPO_ROOT="$REPO_ROOT" \
      MCP_CONFIG="$fixture_dir/mcp_servers.json" \
      MCP_POLICY_CONFIG="$fixture_dir/policy.json" \
      MCP_LOCK_CONFIG="$fixture_dir/lock.json" \
      MCP_REGISTRY_CONFIG="$fixture_dir/registry.json" \
      bash "$TEST_SCRIPT" --json
  )" || true
  if [[ "$output" == *'"status": "failed"'* ]] && [[ "$output" == *'"warnings":'* ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: a blocked root and plain-http transports fail even without --strict"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: expected failed JSON summary"
    printf '%b\n' "    Output: $output"
  fi
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: jq unavailable, skipped"
fi

test_start "mcp_doctor_strict_warning_branch_fails"
if command -v jq >/dev/null 2>&1; then
  if REPO_ROOT="$REPO_ROOT" \
    MCP_CONFIG="$fixture_dir/mcp_servers.json" \
    MCP_POLICY_CONFIG="$fixture_dir/policy.json" \
    MCP_LOCK_CONFIG="$fixture_dir/lock.json" \
    MCP_REGISTRY_CONFIG="$fixture_dir/registry.json" \
    bash "$TEST_SCRIPT" --strict --json >/dev/null; then
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: strict warnings should fail"
  else
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: strict warnings fail the check"
  fi
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: jq unavailable, skipped"
fi

# Slice 2: drive real line coverage of the script under test
cov_exercise_script "$TEST_SCRIPT"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
