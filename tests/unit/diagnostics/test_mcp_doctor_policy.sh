#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural coverage for the *policy* half of
# scripts/diagnostics/mcp-doctor.sh: config/policy/lock/registry discovery,
# the SEP-1649 server card checks, the JSON summary and the strict-mode exit
# contract. Every fixture is written inside the coverage sandbox and fed in
# through the script's own env overrides (MCP_CONFIG, MCP_POLICY_CONFIG,
# MCP_LOCK_CONFIG, MCP_REGISTRY_CONFIG, MCP_SERVER_CARD, REPO_ROOT), so no
# host state is read or written.
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

MINIMAL_CFG="$FIX/minimal.json"
cat >"$MINIMAL_CFG" <<'JSON'
{"mcpServers":{"filesystem":{"command":"npx","args":["-y","@modelcontextprotocol/server-filesystem@1.0.0","/tmp/project"]}}}
JSON

LAX_POLICY="$FIX/lax-policy.json"
cat >"$LAX_POLICY" <<'JSON'
{
  "defaultProfile": "lax",
  "profiles": {
    "lax": {
      "allowedLaunchers": ["npx", "node", "uvx"],
      "blockedFilesystemRoots": ["/", "/home", "/Users"],
      "blockedArgPatterns": ["^--allow-.*", "^--unsafe$"],
      "forbidNetworkServersByDefault": [],
      "requiredEnvByServer": {},
      "trustedTransports": ["stdio"],
      "warnOnUnpinnedNpx": false,
      "requireApprovedPackageLock": false,
      "requireRegistryEntry": false,
      "requireHttpsForHttpTransports": false,
      "requireOauthForHttpTransports": false
    }
  }
}
JSON

test_start "script_exists_and_parses"
assert_file_exists "$DOCTOR" "mcp-doctor.sh must exist"
assert_true "bash -n '$DOCTOR'" "valid bash syntax"

# ── config discovery ────────────────────────────────────────────────────
test_start "healthy_config_passes_with_rc0"
doctor "MCP_CONFIG=$MINIMAL_CFG" "MCP_POLICY_CONFIG=$LAX_POLICY" \
  "MCP_LOCK_CONFIG=$FIX/none.json" "MCP_REGISTRY_CONFIG=$FIX/none.json" \
  "MCP_SERVER_CARD=$FIX/none.json"
assert_equals 0 "$RC" "rc"
out_has "MCP Doctor" "header"
out_has "JSON syntax" "validation section"
out_has "1 configured" "server count"

test_start "missing_config_is_an_error_and_exits_1"
# HOME without a .dotfiles tree, so the fallback candidate loop finds nothing.
mkdir -p "$FIX/emptyhome"
doctor "HOME=$FIX/emptyhome" "MCP_CONFIG=$FIX/absent.json" "MCP_POLICY_CONFIG=$LAX_POLICY" \
  "MCP_LOCK_CONFIG=$FIX/none.json" "MCP_REGISTRY_CONFIG=$FIX/none.json" \
  "MCP_SERVER_CARD=$FIX/none.json"
assert_equals 1 "$RC" "rc"
out_has "not found (expected" "config error"
out_has "MCP issues found" "summary"

test_start "invalid_config_json_is_an_error"
printf '{oops' >"$FIX/bad.json"
doctor "MCP_CONFIG=$FIX/bad.json" "MCP_POLICY_CONFIG=$LAX_POLICY" \
  "MCP_LOCK_CONFIG=$FIX/none.json" "MCP_REGISTRY_CONFIG=$FIX/none.json" \
  "MCP_SERVER_CARD=$FIX/none.json"
assert_equals 1 "$RC" "rc"
out_has "JSON syntax" "syntax row"
out_has "invalid" "invalid"

test_start "empty_server_map_is_an_error"
printf '{"mcpServers":{}}' >"$FIX/empty.json"
doctor "MCP_CONFIG=$FIX/empty.json" "MCP_POLICY_CONFIG=$LAX_POLICY" \
  "MCP_LOCK_CONFIG=$FIX/none.json" "MCP_REGISTRY_CONFIG=$FIX/none.json" \
  "MCP_SERVER_CARD=$FIX/none.json"
assert_equals 1 "$RC" "rc"
out_has "none configured" "server count error"

test_start "config_falls_back_to_the_dotfiles_copy"
# With no MCP_CONFIG and no ~/.config/claude copy, the loop over the
# ~/.dotfiles candidates picks the repo's tracked config.
rm -f "$HOME/.config/claude/mcp_servers.json"
doctor "MCP_POLICY_CONFIG=$LAX_POLICY" "MCP_LOCK_CONFIG=$FIX/none.json" \
  "MCP_REGISTRY_CONFIG=$FIX/none.json" "MCP_SERVER_CARD=$FIX/none.json" \
  "HOME=$HOME"
out_has "MCP config" "config row rendered"

# ── policy / supply-chain presence ──────────────────────────────────────
test_start "missing_policy_config_warns"
doctor "MCP_CONFIG=$MINIMAL_CFG" "MCP_POLICY_CONFIG=$FIX/absent.json" \
  "MCP_LOCK_CONFIG=$FIX/none.json" "MCP_REGISTRY_CONFIG=$FIX/none.json" \
  "MCP_SERVER_CARD=$FIX/none.json"
assert_equals 0 "$RC" "warnings alone do not fail"
out_has "using built-in defaults" "warning"

test_start "strict_mode_turns_warnings_into_failure"
# Under --strict every log_warn also increments Errors, so the same run that
# exits 0 with warnings exits 1 and reports them as errors.
doctor "MCP_CONFIG=$MINIMAL_CFG" "MCP_POLICY_CONFIG=$FIX/absent.json" \
  "MCP_LOCK_CONFIG=$FIX/none.json" "MCP_REGISTRY_CONFIG=$FIX/none.json" \
  "MCP_SERVER_CARD=$FIX/none.json" -- --strict
assert_equals 1 "$RC" "rc"
out_has "MCP issues found" "strict summary"
out_has "errors" "warnings promoted to errors"

test_start "lock_and_registry_optional_when_policy_does_not_require_them"
doctor "MCP_CONFIG=$MINIMAL_CFG" "MCP_POLICY_CONFIG=$LAX_POLICY" \
  "MCP_LOCK_CONFIG=$FIX/absent.json" "MCP_REGISTRY_CONFIG=$FIX/absent.json" \
  "MCP_SERVER_CARD=$FIX/none.json"
out_has "Package lock" "lock row"
out_has "not required" "optional"

test_start "lock_and_registry_missing_warn_under_strict_local_policy"
STRICT_POLICY="$FIX/strict-policy.json"
jq '.profiles.lax.requireApprovedPackageLock = true
    | .profiles.lax.requireRegistryEntry = true' "$LAX_POLICY" >"$STRICT_POLICY"
doctor "MCP_CONFIG=$MINIMAL_CFG" "MCP_POLICY_CONFIG=$STRICT_POLICY" \
  "MCP_LOCK_CONFIG=$FIX/absent.json" "MCP_REGISTRY_CONFIG=$FIX/absent.json" \
  "MCP_SERVER_CARD=$FIX/none.json"
out_has "strict-local expects a tracked lock file" "lock warning"
out_has "strict-local expects a tracked registry file" "registry warning"

test_start "present_lock_and_registry_are_reported"
printf '{"packages":{}}' >"$FIX/lock.json"
printf '{"servers":{}}' >"$FIX/registry.json"
doctor "MCP_CONFIG=$MINIMAL_CFG" "MCP_POLICY_CONFIG=$LAX_POLICY" \
  "MCP_LOCK_CONFIG=$FIX/lock.json" "MCP_REGISTRY_CONFIG=$FIX/registry.json" \
  "MCP_SERVER_CARD=$FIX/none.json"
out_has "lock.json" "lock path"
out_has "registry.json" "registry path"

# ── SEP-1649 server card ────────────────────────────────────────────────
test_start "missing_server_card_warns"
doctor "MCP_CONFIG=$MINIMAL_CFG" "MCP_POLICY_CONFIG=$LAX_POLICY" \
  "MCP_LOCK_CONFIG=$FIX/none.json" "MCP_REGISTRY_CONFIG=$FIX/none.json" \
  "MCP_SERVER_CARD=$FIX/absent.json"
out_has "Server card" "card row"
out_has "not found (expected" "warning"

test_start "invalid_server_card_json_is_an_error"
printf 'not json' >"$FIX/card-bad.json"
doctor "MCP_CONFIG=$MINIMAL_CFG" "MCP_POLICY_CONFIG=$LAX_POLICY" \
  "MCP_LOCK_CONFIG=$FIX/none.json" "MCP_REGISTRY_CONFIG=$FIX/none.json" \
  "MCP_SERVER_CARD=$FIX/card-bad.json"
assert_equals 1 "$RC" "rc"
out_has "invalid JSON" "card error"

test_start "complete_server_card_passes_every_field_check"
cat >"$FIX/card-ok.json" <<'JSON'
{"cardVersion":"1.0","name":"dotfiles","capabilities":{"tools":true},"transport":{"type":"stdio"}}
JSON
doctor "MCP_CONFIG=$MINIMAL_CFG" "MCP_POLICY_CONFIG=$LAX_POLICY" \
  "MCP_LOCK_CONFIG=$FIX/none.json" "MCP_REGISTRY_CONFIG=$FIX/none.json" \
  "MCP_SERVER_CARD=$FIX/card-ok.json"
assert_equals 0 "$RC" "rc"
out_has "Card version" "version row"
out_has "Card capabilities" "capabilities row"
out_has "Card transport" "transport row"

test_start "empty_server_card_warns_on_every_field"
printf '{}' >"$FIX/card-empty.json"
doctor "MCP_CONFIG=$MINIMAL_CFG" "MCP_POLICY_CONFIG=$LAX_POLICY" \
  "MCP_LOCK_CONFIG=$FIX/none.json" "MCP_REGISTRY_CONFIG=$FIX/none.json" \
  "MCP_SERVER_CARD=$FIX/card-empty.json"
out_has "missing cardVersion field" "version warning"
out_has "missing name field" "name warning"
out_has "missing capabilities block" "capabilities warning"
out_has "missing transport block" "transport warning"

# ── JSON summary ────────────────────────────────────────────────────────
test_start "json_mode_emits_a_machine_readable_summary"
doctor "MCP_CONFIG=$MINIMAL_CFG" "MCP_POLICY_CONFIG=$LAX_POLICY" \
  "MCP_LOCK_CONFIG=$FIX/none.json" "MCP_REGISTRY_CONFIG=$FIX/none.json" \
  "MCP_SERVER_CARD=$FIX/card-ok.json" -- --json
assert_equals 0 "$RC" "rc"
assert_equals "healthy" "$(out_json .status)" "status"
assert_equals "1" "$(out_json .server_count)" "server_count"
assert_equals "true" "$(out_json .checks.config_present)" "config_present"
assert_equals "false" "$(out_json .strict)" "strict flag"
out_lacks "MCP Doctor" "no human-readable chrome in --json mode"

test_start "json_mode_reports_warning_status"
doctor "MCP_CONFIG=$MINIMAL_CFG" "MCP_POLICY_CONFIG=$FIX/absent.json" \
  "MCP_LOCK_CONFIG=$FIX/none.json" "MCP_REGISTRY_CONFIG=$FIX/none.json" \
  "MCP_SERVER_CARD=$FIX/none.json" -- -j
assert_equals "warning" "$(out_json .status)" "status"
assert_true "[[ \$(out_json .summary.warnings) -gt 0 ]]" "warnings counted"

test_start "json_strict_mode_reports_failed_status_and_exit_1"
doctor "MCP_CONFIG=$MINIMAL_CFG" "MCP_POLICY_CONFIG=$FIX/absent.json" \
  "MCP_LOCK_CONFIG=$FIX/none.json" "MCP_REGISTRY_CONFIG=$FIX/none.json" \
  "MCP_SERVER_CARD=$FIX/none.json" -- --json -s
assert_equals 1 "$RC" "rc"
assert_equals "failed" "$(out_json .status)" "status"
assert_equals "true" "$(out_json .strict)" "strict flag"

test_start "unknown_flags_are_ignored"
doctor "MCP_CONFIG=$MINIMAL_CFG" "MCP_POLICY_CONFIG=$LAX_POLICY" \
  "MCP_LOCK_CONFIG=$FIX/none.json" "MCP_REGISTRY_CONFIG=$FIX/none.json" \
  "MCP_SERVER_CARD=$FIX/card-ok.json" -- --definitely-not-a-flag
assert_equals 0 "$RC" "rc"
out_has "MCP Doctor" "still ran"

test_start "invalid_policy_json_falls_back_to_builtin_defaults"
printf 'nope' >"$FIX/policy-bad.json"
doctor "MCP_CONFIG=$MINIMAL_CFG" "MCP_POLICY_CONFIG=$FIX/policy-bad.json" \
  "MCP_LOCK_CONFIG=$FIX/none.json" "MCP_REGISTRY_CONFIG=$FIX/none.json" \
  "MCP_SERVER_CARD=$FIX/none.json"
out_has "Launcher policy" "default allowlist still applied"

# ── no jq ───────────────────────────────────────────────────────────────
test_start "without_jq_only_the_grep_fallback_runs"
NOJQ="$DOTFILES_COV_TMPDIR/nojq"
mkdir -p "$NOJQ"
IFS=: read -ra _dirs <<<"$PATH"
_link_dirs() {
  local _d
  for _d in "$@"; do
    [[ -d "$_d" ]] && ln -s "$_d"/* "$NOJQ"/ 2>/dev/null
  done
  return 0
}
# System dirs first: a PATH entry may hold a *directory* whose name shadows
# a real command (PowerShell ships a `tr` locale dir). The prune pass then
# drops any link that did not resolve to a file.
# Building the farm expands to `ln -s` calls with ~900 arguments each. Under
# the coverage runner every one of those is an xtrace record tens of KB long,
# and records that big come back truncated — corrupting the trace around
# them. Turn tracing off for the farm only, then back on.
_xtrace_was_on=0
case "$-" in *x*) _xtrace_was_on=1 ;; esac
set +x
_link_dirs /usr/bin /bin /usr/sbin /sbin
_link_dirs "${_dirs[@]}"
for _l in "$NOJQ"/*; do [[ -f "$_l" ]] || rm -f "$_l"; done
_link_dirs /usr/bin /bin /usr/sbin /sbin
rm -f "$NOJQ/jq"
# Keep the *current* bash: on macOS the farm would otherwise resolve `bash`
# to /bin/bash 3.2, whose xtrace truncates the PS4 expansion at 100 chars —
# every coverage record from the child would be malformed and dropped.
ln -sf "$(command -v bash)" "$NOJQ/bash"
[[ "$_xtrace_was_on" == "1" ]] && set -x
doctor "PATH=$NOJQ" "MCP_CONFIG=$MINIMAL_CFG" "MCP_POLICY_CONFIG=$LAX_POLICY" \
  "MCP_LOCK_CONFIG=$FIX/none.json" "MCP_REGISTRY_CONFIG=$FIX/none.json" \
  "MCP_SERVER_CARD=$FIX/none.json"
out_has "not installed, running limited checks" "jq warning"
out_has "mcpServers key" "grep fallback ran"

test_start "without_jq_a_config_lacking_the_key_fails"
printf '{"other":{}}' >"$FIX/nokey.json"
doctor "PATH=$NOJQ" "MCP_CONFIG=$FIX/nokey.json" "MCP_POLICY_CONFIG=$LAX_POLICY" \
  "MCP_LOCK_CONFIG=$FIX/none.json" "MCP_REGISTRY_CONFIG=$FIX/none.json" \
  "MCP_SERVER_CARD=$FIX/none.json"
assert_equals 1 "$RC" "rc"
out_has "mcpServers key" "row"
out_has "missing" "failure"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
