#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016,SC2034
# Behavioural coverage for the integrity half of the MCP package lock in
# scripts/diagnostics/mcp-doctor.sh: a lock entry with an integrity hash
# must match the server's command and appear, for that exact package, in
# the committed npm package-lock.json or hash-pinned requirements.txt it
# names. Also covers the shipped config/lock/registry/policy together and
# the launcher-prefix allowlist for installed server binaries.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

DOCTOR="$REPO_ROOT/scripts/diagnostics/mcp-doctor.sh"
SHIPPED="$REPO_ROOT/defaults/dot_config"
CONFIG="$SHIPPED/claude/mcp_servers.json"
LOCK="$SHIPPED/dotfiles/mcp-lock.json"
POLICY="$SHIPPED/dotfiles/mcp-policy.json"
REGISTRY="$SHIPPED/dotfiles/mcp-registry.json"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

FIX="$DOTFILES_COV_TMPDIR/fixtures"
mkdir -p "$FIX"
OUTF="$DOTFILES_COV_TMPDIR/doctor-out.txt"
NONE="$FIX/none.json"

# doctor <env-assignments…>: a strict run from the sandbox, report in $OUTF.
doctor() {
  (cd "$DOTFILES_COV_TMPDIR" && env "MCP_SERVER_CARD=$REPO_ROOT/.well-known/mcp/server-card.json" "CLAUDE_USER_CONFIG=$NONE" "$@" \
    bash "$DOCTOR" --strict >"$OUTF" </dev/null)
  RC=$?
  return 0
}
out_has() { assert_file_contains "$OUTF" "$1" "${2:-output contains $1}"; }

# shipped <env…>: the shipped files, each overridable by a later assignment.
shipped() {
  doctor "MCP_CONFIG=$CONFIG" "MCP_POLICY_CONFIG=$POLICY" "MCP_LOCK_CONFIG=$LOCK" \
    "MCP_REGISTRY_CONFIG=$REGISTRY" "MCP_LOCK_ROOT=$REPO_ROOT/defaults" "$@"
}

test_start "shipped_servers_run_installed_binaries_not_package_runners"
assert_equals "" "$(jq -r '.mcpServers[] | select(.command | test("(^|/)(npx|uvx)$")) | .command' "$CONFIG")" \
  "no shipped server fetches a package at launch"
assert_equals "3" "$(jq '[.packages[] | select(.integrity)] | length' "$LOCK")" "every lock entry carries an integrity hash"

test_start "shipped_config_passes_strict_with_integrity"
shipped
assert_equals 0 "$RC" "rc: $(tail -n 3 "$OUTF")"
out_has "all active servers match approved package refs" "lock ok"
out_has "all server launchers are allowlisted" "installed binaries are allowlisted by prefix"
out_has "all active servers match the tracked MCP registry" "registry ok"

test_start "a_lock_integrity_not_in_the_manifest_fails"
jq '.packages.git.integrity = "sha256:0000000000000000000000000000000000000000000000000000000000000000"' "$LOCK" >"$FIX/lock-bad-py.json"
shipped "MCP_LOCK_CONFIG=$FIX/lock-bad-py.json"
assert_equals 1 "$RC" "rc"
out_has "git: mcp-server-git==" "names the server and package"
out_has "is not in dot_local/share/dot-mcp/python/git/requirements.txt" "names the manifest"

test_start "an_npm_integrity_not_in_the_package_lock_fails"
jq '.packages.memory.integrity = "sha512-AAAA"' "$LOCK" >"$FIX/lock-bad-npm.json"
shipped "MCP_LOCK_CONFIG=$FIX/lock-bad-npm.json"
assert_equals 1 "$RC" "rc"
out_has "is not in dot_local/share/dot-mcp/node/package-lock.json" "names the manifest"

test_start "a_tampered_manifest_fails"
ROOTCOPY="$FIX/root"
mkdir -p "$ROOTCOPY"
cp -R "$REPO_ROOT/defaults/dot_local" "$ROOTCOPY/"
sed -i.bak 's/^mcp-server-sqlite==\(.*\) \\$/mcp-server-sqlite==9.9.9 \\/' \
  "$ROOTCOPY/dot_local/share/dot-mcp/python/sqlite/requirements.txt"
shipped "MCP_LOCK_ROOT=$ROOTCOPY"
assert_equals 1 "$RC" "rc"
out_has "sqlite: mcp-server-sqlite==" "a version swap in the manifest is caught"
jq '.packages["node_modules/@modelcontextprotocol/server-memory"].version = "0.0.1"' \
  "$REPO_ROOT/defaults/dot_local/share/dot-mcp/node/package-lock.json" \
  >"$ROOTCOPY/dot_local/share/dot-mcp/node/package-lock.json"
cp "$REPO_ROOT/defaults/dot_local/share/dot-mcp/python/sqlite/requirements.txt" \
  "$ROOTCOPY/dot_local/share/dot-mcp/python/sqlite/requirements.txt"
shipped "MCP_LOCK_ROOT=$ROOTCOPY"
assert_equals 1 "$RC" "rc"
out_has "memory: @modelcontextprotocol/server-memory@" "a version swap in the npm lock is caught"

test_start "a_missing_manifest_fails"
shipped "MCP_LOCK_ROOT=$FIX/nowhere"
assert_equals 1 "$RC" "rc"
out_has "is not in" "reported as missing integrity"

test_start "a_server_command_off_the_lock_fails"
jq '.mcpServers.git.command = "${HOME}/.local/share/dot-mcp/python/git/venv/bin/other"' "$CONFIG" >"$FIX/cmd.json"
shipped "MCP_CONFIG=$FIX/cmd.json"
assert_equals 1 "$RC" "rc"
out_has "git: runs \${HOME}/.local/share/dot-mcp/python/git/venv/bin/other (approved: \${HOME}/.local/share/dot-mcp/python/git/venv/bin/mcp-server-git)" \
  "names actual and approved command"

test_start "a_prefix_escape_is_not_allowlisted"
jq '.mcpServers.git.command = "${HOME}/.local/share/dot-mcp/../../bin/evil"' "$CONFIG" >"$FIX/escape.json"
shipped "MCP_CONFIG=$FIX/escape.json"
out_has 'review non-standard command git:${HOME}/.local/share/dot-mcp/../../bin/evil' "a .. escape is not under the prefix"

test_start "a_different_prefix_is_not_allowlisted"
jq '.mcpServers.git.command = "/tmp/dot-mcp/mcp-server-git"' "$CONFIG" >"$FIX/other.json"
shipped "MCP_CONFIG=$FIX/other.json"
out_has "review non-standard command git:/tmp/dot-mcp/mcp-server-git" "only the declared prefix"

test_start "an_npx_server_still_matches_the_package_ref"
jq '.mcpServers.memory = {"command":"npx","args":["-y","@modelcontextprotocol/server-memory@2026.2.0"]}' "$CONFIG" >"$FIX/npx.json"
shipped "MCP_CONFIG=$FIX/npx.json"
assert_equals 1 "$RC" "rc"
out_has "memory uses @modelcontextprotocol/server-memory@2026.2.0 (approved: @modelcontextprotocol/server-memory@2026.8.31)" \
  "the ref comparison still runs for npx"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
