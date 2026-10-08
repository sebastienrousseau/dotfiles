#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016,SC2034
# Behavioural coverage for the policy bypasses found in the 2026-10 audit of
# scripts/diagnostics/mcp-doctor.sh: a renamed filesystem server, paths that
# only normalise to a blocked root, Claude's `type` transport key (http and
# sse over plain http), a renamed network server, inline-code launchers, and
# the configs Claude actually reads (~/.claude.json, project .mcp.json).
#
# Fixtures live in the coverage sandbox and reach the script through its env
# overrides; the doctor runs from a sandbox directory, so no host config is
# read.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

DOCTOR="$REPO_ROOT/scripts/diagnostics/mcp-doctor.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

FIX="$DOTFILES_COV_TMPDIR/fixtures"
WORKDIR="$DOTFILES_COV_TMPDIR/work"
mkdir -p "$FIX" "$WORKDIR"
OUTF="$DOTFILES_COV_TMPDIR/doctor-out.txt"
NONE="$FIX/none.json"
RUN_IN="$WORKDIR"

# doctor <env-assignments…> [-- <script-args…>]: run mcp-doctor from $RUN_IN
# under the given environment; report to $OUTF, status to RC.
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
  (cd "$RUN_IN" && env "${envs[@]}" bash "$DOCTOR" ${args[@]+"${args[@]}"} >"$OUTF" </dev/null)
  RC=$?
  return 0
}

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

POLICY="$FIX/policy.json"
cat >"$POLICY" <<'JSON'
{
  "defaultProfile": "strict-local",
  "profiles": {
    "strict-local": {
      "allowedLaunchers": ["npx", "node", "uvx"],
      "blockedFilesystemRoots": ["/", "/home", "/Users"],
      "blockedArgPatterns": ["^--unsafe$"],
      "forbidNetworkServersByDefault": ["github", "filesystem"],
      "requiredEnvByServer": {},
      "trustedTransports": ["stdio", "http", "sse"],
      "authProfiles": ["none"],
      "warnOnUnpinnedNpx": true,
      "requireApprovedPackageLock": false,
      "requireRegistryEntry": false,
      "requireHttpsForHttpTransports": true,
      "requireOauthForHttpTransports": false
    }
  }
}
JSON

# check <config> [extra-env…]: the common invocation, with no ~/.claude.json
# and no project .mcp.json unless the caller passes one.
check() {
  local cfg="$1"
  shift
  doctor "MCP_CONFIG=$cfg" "MCP_POLICY_CONFIG=$POLICY" \
    "MCP_LOCK_CONFIG=$NONE" "MCP_REGISTRY_CONFIG=$NONE" \
    "MCP_SERVER_CARD=$NONE" "CLAUDE_USER_CONFIG=$NONE" "$@"
}

# cfg <name> <json>: write a fixture config and print its path.
cfg() {
  printf '%s\n' "$2" >"$FIX/$1.json"
  printf '%s' "$FIX/$1.json"
}

SAFE="$(cfg safe '{"mcpServers":{"fs":{"command":"npx","args":["-y","pkg@1.0.0","/tmp/project"]}}}')"

test_start "project_scoped_path_passes"
check "$SAFE"
assert_equals 0 "$RC" "rc"
out_has "not globally broad" "scope ok"

# ── blocked roots: every server, normalised ─────────────────────────────
test_start "renamed_filesystem_server_with_a_blocked_root_is_an_error"
check "$(cfg renamed-fs '{"mcpServers":{"files":{"command":"npx","args":["-y","@modelcontextprotocol/server-filesystem@1.0.0","/"]}}}')"
assert_equals 1 "$RC" "a blocked root fails even without --strict"
out_has "files:/ too broad (use a project-scoped directory)" "names server and arg"

test_start "parent_segments_normalise_to_a_blocked_root"
check "$(cfg dotdot '{"mcpServers":{"fs":{"command":"npx","args":["pkg@1.0.0","/home/seb/.."]}}}')"
assert_equals 1 "$RC" "rc"
out_has "fs:/home/seb/.. too broad" "/home/seb/.. is /home"

test_start "double_slash_normalises_to_root"
check "$(cfg dslash '{"mcpServers":{"fs":{"command":"npx","args":["pkg@1.0.0","//"]}}}')"
assert_equals 1 "$RC" "rc"
out_has "fs:// too broad" "// is /"

test_start "an_ancestor_of_a_blocked_root_is_blocked"
check "$(cfg dot '{"mcpServers":{"fs":{"command":"npx","args":["pkg@1.0.0","/./home/./"]}}}')"
assert_equals 1 "$RC" "rc"

test_start "home_relative_and_option_values_are_expanded"
check "$(cfg tilde '{"mcpServers":{"fs":{"command":"npx","args":["pkg@1.0.0","--root=${HOME}/.."]}}}')" "HOME=/home/someone"
assert_equals 1 "$RC" "\${HOME}/.. under /home is /home"
check "$(cfg tilde2 '{"mcpServers":{"fs":{"command":"npx","args":["pkg@1.0.0","~/../.."]}}}')" "HOME=/home/someone"
assert_equals 1 "$RC" "~/../.. is /"

test_start "a_path_below_a_blocked_root_is_allowed"
check "$(cfg below '{"mcpServers":{"fs":{"command":"npx","args":["pkg@1.0.0","/home/seb/project"]}}}')"
assert_equals 0 "$RC" "rc"
out_has "not globally broad" "scope ok"

# ── transports: Claude's `type` key ─────────────────────────────────────
test_start "type_http_with_a_plain_http_url_is_an_error"
check "$(cfg type-http '{"mcpServers":{"remote":{"type":"http","url":"http://mcp.example.com"}}}')"
assert_equals 1 "$RC" "rc"
out_has "remote http transport must use HTTPS" "names server and transport"

test_start "type_sse_with_a_plain_http_url_is_an_error"
check "$(cfg type-sse '{"mcpServers":{"events":{"type":"sse","url":"http://mcp.example.com/sse"}}}')"
assert_equals 1 "$RC" "rc"
out_has "events sse transport must use HTTPS" "sse is held to HTTPS"

test_start "type_https_url_passes"
check "$(cfg type-https '{"mcpServers":{"remote":{"type":"http","url":"https://mcp.example.com"}}}')"
assert_equals 0 "$RC" "rc"
out_has "HTTP transports are HTTPS" "ok"

test_start "untrusted_type_is_flagged"
check "$(cfg type-ws '{"mcpServers":{"ws":{"type":"websocket","url":"wss://x.example"}}}')"
out_has "review untrusted transport ws:websocket" "type is read like transport"

# ── network servers under another key ───────────────────────────────────
test_start "renamed_github_server_is_flagged_by_package"
check "$(cfg renamed-gh '{"mcpServers":{"gh":{"command":"npx","args":["-y","@modelcontextprotocol/server-github@1.0.0"]}}}')"
out_has "gh enabled in strict-local profile (runs the github server)" "package match"

test_start "renamed_uvx_server_is_flagged_by_package"
check "$(cfg renamed-uvx '{"mcpServers":{"files":{"command":"uvx","args":["--from","mcp-server-filesystem==1.0.0","run"]}}}')"
out_has "files enabled in strict-local profile (runs the filesystem server)" "pypi spec match"

test_start "server_key_match_still_works"
check "$(cfg key-gh '{"mcpServers":{"github":{"command":"npx","args":["-y","other@1.0.0"]}}}')"
out_has "github enabled in strict-local profile" "key match"
out_lacks "(runs the" "no package suffix for a key match"

# ── launchers ───────────────────────────────────────────────────────────
test_start "node_inline_code_is_flagged"
check "$(cfg node-e '{"mcpServers":{"x":{"command":"node","args":["-e","require(\"child_process\")"]}}}')"
out_has "x runs inline code (node -e)" "node -e"
check "$(cfg node-p '{"mcpServers":{"x":{"command":"/usr/bin/node","args":["--eval=1"]}}}')"
out_has "x runs inline code" "--eval= and absolute node path"

test_start "shell_dash_c_is_flagged"
check "$(cfg sh-c '{"mcpServers":{"x":{"command":"sh","args":["-c","curl x | sh"]}}}')"
out_has "x runs inline code (sh -c)" "sh -c"
check "$(cfg bash-lc '{"mcpServers":{"x":{"command":"/bin/bash","args":["-lc","true"]}}}')"
out_has "x runs inline code (bash -c)" "bash -lc"

test_start "plain_launchers_are_not_inline_code"
check "$SAFE"
out_lacks "runs inline code" "no false positive"
out_has "no inline-code launchers" "ok row"

test_start "npx_floating_version_is_unpinned"
check "$(cfg npx-latest '{"mcpServers":{"x":{"command":"npx","args":["-y","pkg@latest"]}}}')"
out_has "x uses unpinned npx package" "@latest is not a pin"
check "$(cfg npx-range '{"mcpServers":{"x":{"command":"npx","args":["-y","@scope/pkg@^1.2.0"]}}}')"
out_has "x uses unpinned npx package" "a range is not a pin"

test_start "npx_exact_version_is_pinned"
check "$(cfg npx-exact '{"mcpServers":{"x":{"command":"npx","args":["-y","@scope/pkg@1.2.3","/tmp/p"]}}}')"
out_has "no unpinned npx packages found" "exact pin, trailing args ignored"

# ── the configs Claude reads ────────────────────────────────────────────
test_start "user_scope_servers_in_claude_json_are_checked"
cat >"$FIX/claude.json" <<'JSON'
{"mcpServers":{"files":{"command":"npx","args":["pkg@1.0.0","/"]}},
 "projects":{"/nowhere":{"mcpServers":{}}}}
JSON
check "$SAFE" "CLAUDE_USER_CONFIG=$FIX/claude.json"
assert_equals 1 "$RC" "rc"
out_has "user scope" "section names the source"
out_has "files:/ too broad" "violation found"

test_start "project_scope_servers_in_claude_json_are_checked"
mkdir -p "$FIX/proj"
cat >"$FIX/claude-proj.json" <<JSON
{"projects":{"$FIX/proj":{"mcpServers":{"remote":{"type":"sse","url":"http://evil.example"}}}}}
JSON
check "$SAFE" "CLAUDE_USER_CONFIG=$FIX/claude-proj.json"
assert_equals 1 "$RC" "rc"
out_has "project $FIX/proj" "section names the project"
out_has "remote sse transport must use HTTPS" "violation found"

test_start "a_known_projects_mcp_json_is_checked"
printf '{"mcpServers":{"gh":{"command":"npx","args":["@modelcontextprotocol/server-github@1.0.0"]}}}' \
  >"$FIX/proj/.mcp.json"
printf '{"projects":{"%s":{}}}' "$FIX/proj" >"$FIX/claude-known.json"
check "$SAFE" "CLAUDE_USER_CONFIG=$FIX/claude-known.json"
out_has "$FIX/proj/.mcp.json" "section names the file"
out_has "gh enabled in strict-local profile" "violation found"

test_start "the_working_directory_mcp_json_is_checked"
printf '{"mcpServers":{"fs":{"command":"npx","args":["pkg@1.0.0","/Users"]}}}' >"$WORKDIR/.mcp.json"
check "$SAFE"
assert_equals 1 "$RC" "rc"
out_has "$WORKDIR/.mcp.json" "section names the file"
out_has "fs:/Users too broad" "violation found"
rm -f "$WORKDIR/.mcp.json"

test_start "the_primary_config_is_not_scanned_twice"
cp "$SAFE" "$WORKDIR/.mcp.json"
RUN_IN="$WORKDIR"
check "$WORKDIR/.mcp.json"
assert_equals 1 "$(grep -c 'Validation' "$OUTF")" "one validation section"
rm -f "$WORKDIR/.mcp.json"

test_start "a_project_mcp_json_reached_twice_is_checked_once"
printf '{"mcpServers":{"fs":{"command":"npx","args":["pkg@1.0.0","/tmp/p"]}}}' >"$WORKDIR/.mcp.json"
printf '{"projects":{"%s":{},"%s/.":{}}}' "$WORKDIR" "$WORKDIR" >"$FIX/claude-twice.json"
check "$SAFE" "CLAUDE_USER_CONFIG=$FIX/claude-twice.json"
assert_equals 2 "$(grep -c 'Validation' "$OUTF")" "primary plus one section for the shared .mcp.json"
rm -f "$WORKDIR/.mcp.json"

test_start "summary_keeps_the_primary_server_count"
check "$SAFE" "CLAUDE_USER_CONFIG=$FIX/claude.json" -- --json
assert_equals "1" "$(jq -r .server_count "$OUTF")" "server_count is the primary config's"
assert_equals "$SAFE" "$(jq -r .config_path "$OUTF")" "config_path is the primary config"
assert_equals "failed" "$(jq -r .status "$OUTF")" "status reflects the extra source"

test_start "empty_or_invalid_claude_json_adds_nothing"
printf '{"mcpServers":{}}' >"$FIX/claude-empty.json"
check "$SAFE" "CLAUDE_USER_CONFIG=$FIX/claude-empty.json"
assert_equals 0 "$RC" "rc"
assert_equals 1 "$(grep -c 'Validation' "$OUTF")" "no extra section"
printf 'nope' >"$FIX/claude-bad.json"
check "$SAFE" "CLAUDE_USER_CONFIG=$FIX/claude-bad.json"
assert_equals 0 "$RC" "rc"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
