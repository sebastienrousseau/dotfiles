#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Behavioural coverage for `dot fleet namespace|enforce|apply` and the
# top-level dispatcher in scripts/dot/commands/fleet.sh. The command's
# config writes (.chezmoidata.toml, agent-profiles.json) land in a
# private fake source tree; SSH fan-out is replaced by PATH shims for
# ssh / ssh-keygen / mv / sed so every failure branch is reachable
# without touching the host, the real repo, or the network.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# Keep child xtrace flowing to the coverage runner's trace stream even
# when a probe captures `2>&1` or discards stderr.
exec 21>&2
export BASH_XTRACEFD=21

trap cov_teardown_sandbox EXIT
cov_setup_sandbox
TMP="$DOTFILES_COV_TMPDIR"
[[ -n "$TMP" && -d "$TMP" ]] || {
  echo "sandbox tmpdir missing; refusing to run" >&2
  exit 1
}

# ── Fake source tree ────────────────────────────────────────────────
# lib/ scripts/ bin/ are symlinks into the real repo so the traced
# BASH_SOURCE paths resolve to the real files; defaults/ is a private
# copy so the command's config reads/writes never leave the sandbox.
# Under the coverage runner the tree must outlive sandbox teardown
# (the aggregator resolves symlinks after every test has finished);
# COV_TRACE_DIR is wiped by the runner at the start of each sweep.
if [[ -n "${COV_TRACE_DIR:-}" && -d "${COV_TRACE_DIR:-}" ]]; then
  FAKE="$(mktemp -d "$COV_TRACE_DIR/fleet-fake.XXXXXX")"
else
  FAKE="$TMP/repo"
fi
mkdir -p "$FAKE/defaults/dot_config/dotfiles"
ln -s "$REPO_ROOT/lib" "$FAKE/lib"
ln -s "$REPO_ROOT/scripts" "$FAKE/scripts"
ln -s "$REPO_ROOT/bin" "$FAKE/bin"
cp "$REPO_ROOT/package.json" "$FAKE/package.json"
echo defaults >"$FAKE/.chezmoiroot"
FLEET="$FAKE/scripts/dot/commands/fleet.sh"
DATA="$FAKE/defaults/.chezmoidata.toml"
PROFILES="$FAKE/defaults/dot_config/dotfiles/agent-profiles.json"
EVENTS="$XDG_STATE_HOME/dotfiles/fleet/events.jsonl"

# ── PATH ────────────────────────────────────────────────────────────
# $MINI holds only the coreutils the script needs; $SHIMS is a second
# front-of-PATH dir for per-test overrides (ssh, ssh-keygen, mv, sed).
MINI="$TMP/mini"
SHIMS="$TMP/shims"
mkdir -p "$MINI" "$SHIMS"
for t in bash sh dirname basename sed head tail hostname date mkdir awk wc tr \
  uname grep realpath readlink sort uniq cat mktemp mv rm cp cut env tput \
  stty ls find diff touch chmod jq; do
  p="$(command -v "$t" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$MINI/$t"
done
PATH_NO_SSH="$TMP/bin:$MINI"
export PATH="$SHIMS:$PATH_NO_SSH"

# ssh shim: never opens a socket; records the target and exits 0.
SSH_LOG="$TMP/ssh.log"
cat >"$SHIMS/ssh" <<'SHIM'
#!/usr/bin/env bash
target=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) shift 2 ;;
    -*) shift ;;
    *)
      target="$1"
      shift
      break
      ;;
  esac
done
printf '%s %s\n' "$target" "$*" >>"${FAKE_SSH_LOG:?}"
exit 0
SHIM
chmod +x "$SHIMS/ssh"
export FAKE_SSH_LOG="$SSH_LOG"

# ssh-keygen shim: `-F host` succeeds unless FAKE_UNKNOWN_HOST matches.
cat >"$SHIMS/ssh-keygen" <<'SHIM'
#!/usr/bin/env bash
host=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -F)
      host="$2"
      shift 2
      ;;
    *) shift ;;
  esac
done
[[ -n "${FAKE_UNKNOWN_HOST:-}" && "$host" == "$FAKE_UNKNOWN_HOST" ]] && exit 1
exit 0
SHIM
chmod +x "$SHIMS/ssh-keygen"

write_data() {
  cat >"$DATA"
}

# assert_not_contains <needle> <haystack> [msg] — string-level negative.
assert_not_contains() {
  local needle="$1" actual="$2" msg="${3:-string should not contain substring}"
  if [[ "$actual" != *"$needle"* ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $msg"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $msg"
    printf '%b\n' "    Should not contain: '$needle'"
  fi
}

fleet() {
  bash "$FLEET" fleet "$@"
}

# ── namespace ───────────────────────────────────────────────────────
write_data <<'TOML'
node_id = "node-a"
namespace = "team"

[namespaces.default]
[namespaces.team]
[namespaces.lab]
TOML

test_start "fleet_namespace_show_lists_available_namespaces"
out="$(fleet namespace show 2>&1)"
rc=$?
assert_equals 0 "$rc" "namespace show exits 0"
assert_contains "team" "$out" "active namespace shown"
assert_contains "[active]" "$out" "active marker rendered"
assert_contains "lab" "$out" "inactive namespace listed"

test_start "fleet_namespace_default_subcommand_and_alias"
out="$(fleet namespace 2>&1)"
assert_contains "Fleet Namespace" "$out" "bare namespace shows"
out="$(fleet ns 2>&1)"
assert_contains "Fleet Namespace" "$out" "ns alias routes to namespace"

test_start "fleet_namespace_set_rewrites_data_file"
out="$(fleet namespace set lab 2>&1)"
rc=$?
assert_equals 0 "$rc" "namespace set exits 0"
assert_contains "Set to 'lab'" "$out" "confirmation message"
assert_file_contains "$DATA" 'namespace = "lab"' "data file rewritten atomically"
assert_file_contains "$EVENTS" '"event":"namespace_set"' "event emitted"
assert_file_contains "$EVENTS" '"namespace":"lab"' "event carries the new namespace"

test_start "fleet_namespace_set_requires_name"
out="$(fleet namespace set 2>&1)"
rc=$?
assert_equals 1 "$rc" "missing name exits 1"
assert_contains "Usage: dot fleet namespace set" "$out" "usage printed"

test_start "fleet_namespace_set_rejects_unsafe_name"
out="$(fleet namespace set 'bad;name' 2>&1)"
rc=$?
assert_equals 1 "$rc" "unsafe name exits 1"
assert_contains "Invalid namespace" "$out" "validation message"
assert_file_contains "$DATA" 'namespace = "lab"' "data file untouched"

test_start "fleet_namespace_set_without_existing_key"
write_data <<'TOML'
node_id = "node-a"
TOML
out="$(fleet namespace set fresh 2>&1)"
rc=$?
assert_equals 0 "$rc" "set without a namespace line still succeeds"
assert_contains "Set to 'fresh'" "$out" "confirmation message"
assert_equals "" "$(grep '^namespace' "$DATA")" "no namespace line is invented"

write_data <<'TOML'
namespace = "team"
TOML

test_start "fleet_namespace_set_reports_mv_failure"
cat >"$SHIMS/mv" <<'SHIM'
#!/usr/bin/env bash
exit 1
SHIM
chmod +x "$SHIMS/mv"
out="$(fleet namespace set broken 2>&1)"
rc=$?
rm -f "$SHIMS/mv"
assert_equals 1 "$rc" "mv failure exits 1"
assert_contains "Failed to commit namespace update" "$out" "commit failure reported"
assert_file_contains "$DATA" 'namespace = "team"' "data file left intact"
assert_equals "" "$(ls "$FAKE/defaults"/.chezmoidata.toml.* 2>/dev/null)" "tempfile cleaned up"

test_start "fleet_namespace_set_reports_sed_failure"
cat >"$SHIMS/sed" <<'SHIM'
#!/usr/bin/env bash
case "$*" in
  *'s/^namespace = '*) exit 1 ;;
esac
exec "${FAKE_REAL_SED:?}" "$@"
SHIM
chmod +x "$SHIMS/sed"
out="$(FAKE_REAL_SED="$MINI/sed" fleet namespace set broken 2>&1)"
rc=$?
rm -f "$SHIMS/sed"
assert_equals 1 "$rc" "sed failure exits 1"
assert_contains "Failed to render namespace update" "$out" "render failure reported"
assert_file_contains "$DATA" 'namespace = "team"' "data file left intact"

test_start "fleet_namespace_unknown_subcommand"
out="$(fleet namespace bogus 2>&1)"
rc=$?
assert_equals 1 "$rc" "unknown namespace subcommand exits 1"
assert_contains "Usage: dot fleet namespace" "$out" "usage printed"

# ── enforce ─────────────────────────────────────────────────────────
test_start "fleet_enforce_status_without_profiles"
out="$(fleet enforce 2>&1)"
rc=$?
assert_equals 1 "$rc" "missing profiles exits 1"
assert_contains "agent-profiles.json not found" "$out" "explains the missing file"

cat >"$PROFILES" <<'JSON'
{
  "rbac": {
    "enforcement": "advisory",
    "defaultRole": "developer",
    "roles": {
      "developer": {"allowedProfiles": ["ask", "plan"]},
      "operator": {"allowedProfiles": ["apply"]}
    }
  }
}
JSON

test_start "fleet_enforce_status_renders_roles"
out="$(fleet enforce status 2>&1)"
rc=$?
assert_equals 0 "$rc" "enforce status exits 0"
assert_contains "advisory" "$out" "mode shown"
assert_contains "developer" "$out" "default role shown"
assert_contains "ask, plan" "$out" "role profiles joined"
assert_contains "operator" "$out" "every role listed"

test_start "fleet_enforce_set_strict"
out="$(fleet enforce set strict 2>&1)"
rc=$?
assert_equals 0 "$rc" "enforce set exits 0"
assert_contains "set to 'strict'" "$out" "confirmation"
assert_equals "strict" "$(jq -r .rbac.enforcement "$PROFILES")" "profiles file updated"
assert_file_contains "$EVENTS" '"event":"enforcement_set"' "event emitted"

test_start "fleet_enforce_set_requires_mode"
out="$(fleet enforce set 2>&1)"
rc=$?
assert_equals 1 "$rc" "missing mode exits 1"
assert_contains "Usage: dot fleet enforce set" "$out" "usage printed"

test_start "fleet_enforce_set_rejects_unknown_mode"
out="$(fleet enforce set lenient 2>&1)"
rc=$?
assert_equals 1 "$rc" "unknown mode exits 1"
assert_contains "Invalid enforcement mode: lenient" "$out" "validation message"
assert_equals "strict" "$(jq -r .rbac.enforcement "$PROFILES")" "profiles file untouched"

test_start "fleet_enforce_set_without_profiles"
mv "$PROFILES" "$PROFILES.bak"
out="$(fleet enforce set advisory 2>&1)"
rc=$?
mv "$PROFILES.bak" "$PROFILES"
assert_equals 1 "$rc" "missing profiles exits 1"
assert_contains "agent-profiles.json not found" "$out" "explains the missing file"

test_start "fleet_enforce_unknown_subcommand"
out="$(fleet enforce bogus 2>&1)"
rc=$?
assert_equals 1 "$rc" "unknown enforce subcommand exits 1"
assert_contains "Usage: dot fleet enforce" "$out" "usage printed"

# ── apply ───────────────────────────────────────────────────────────
HOSTS="$TMP/fleet.toml"
cat >"$HOSTS" <<'TOML'
[hosts.alpha]
ssh = "user@alpha.test"
profile = "workstation"

[hosts.beta]
ssh = "user@beta.test:2222"
profile = "minimal"
TOML
export DOTFILES_FLEET_HOSTS="$HOSTS"

test_start "fleet_apply_help"
out="$(fleet apply --help 2>&1)"
rc=$?
assert_equals 0 "$rc" "--help exits 0"
assert_contains "Usage: dot fleet apply" "$out" "usage header"
assert_contains "$HOSTS" "$out" "help names the active hosts file"

test_start "fleet_apply_rejects_unknown_flag"
out="$(fleet apply --bogus 2>&1)"
rc=$?
assert_equals 1 "$rc" "unknown flag exits 1"
assert_contains "Unknown arg" "$out" "flag echoed"

test_start "fleet_apply_without_hosts_file"
out="$(DOTFILES_FLEET_HOSTS="$TMP/nope.toml" fleet apply 2>&1)"
rc=$?
assert_equals 1 "$rc" "missing hosts file exits 1"
assert_contains "no hosts file at $TMP/nope.toml" "$out" "path reported"
assert_contains "Hint" "$out" "hint printed"

test_start "fleet_apply_with_empty_hosts_file"
: >"$TMP/empty.toml"
out="$(DOTFILES_FLEET_HOSTS="$TMP/empty.toml" fleet apply 2>&1)"
rc=$?
assert_equals 1 "$rc" "empty hosts file exits 1"
assert_contains "hosts file is empty" "$out" "explains"

test_start "fleet_apply_unknown_host_filter"
out="$(fleet apply --host gamma 2>&1)"
rc=$?
assert_equals 1 "$rc" "unknown host exits 1"
assert_contains "host not found: gamma" "$out" "host named"

test_start "fleet_apply_dry_run_lists_hosts"
out="$(fleet apply --dry-run --cmd "uptime" --jobs 2 2>&1)"
rc=$?
assert_equals 0 "$rc" "dry-run exits 0"
assert_contains "alpha" "$out" "first host listed"
assert_contains "user@beta.test:2222  profile=minimal  cmd=uptime" "$out" "host line carries ssh target, profile and command"
assert_contains "no SSH connections opened" "$out" "dry-run confirmation"
assert_contains "Parallel" "$out" "parallelism reported"
assert_file_not_exists "$SSH_LOG" "dry-run never invokes ssh"

test_start "fleet_apply_short_flags"
out="$(fleet apply -n -j 1 2>&1)"
rc=$?
assert_equals 0 "$rc" "-n / -j accepted"
assert_contains "dot sync && dot doctor --quiet" "$out" "default command shown"

test_start "fleet_apply_without_ssh_binary"
out="$(PATH="$PATH_NO_SSH" fleet apply 2>&1)"
rc=$?
assert_equals 127 "$rc" "missing ssh exits 127"
assert_contains "not installed" "$out" "explains"

test_start "fleet_apply_rejects_invalid_ssh_target"
cat >"$TMP/bad.toml" <<'TOML'
[hosts.evil]
ssh = "user@evil';rm -rf /;'.com"
profile = "x"
TOML
out="$(DOTFILES_FLEET_HOSTS="$TMP/bad.toml" fleet apply --cmd true 2>&1)"
rc=$?
assert_equals 1 "$rc" "invalid target exits 1"
assert_contains "invalid ssh target" "$out" "rejection message"
assert_file_not_exists "$SSH_LOG" "no ssh call for a rejected target"

test_start "fleet_apply_verify_hosts_requires_known_hosts"
rm -f "$HOME/.ssh/known_hosts"
out="$(fleet apply --verify-hosts --cmd true 2>&1)"
rc=$?
assert_equals 1 "$rc" "missing known_hosts exits 1"
assert_contains "populate before --verify-hosts" "$out" "explains"

mkdir -p "$HOME/.ssh"
: >"$HOME/.ssh/known_hosts"

test_start "fleet_apply_verify_hosts_aborts_on_unknown_host"
out="$(FAKE_UNKNOWN_HOST=beta.test fleet apply --verify-hosts --cmd true 2>&1)"
rc=$?
assert_equals 1 "$rc" "unknown host aborts"
assert_contains "no known_hosts entry for beta.test" "$out" "host named (user@ and :port stripped)"
assert_contains "1 host(s) missing from known_hosts" "$out" "count reported"
assert_file_not_exists "$SSH_LOG" "no ssh call when verification fails"

test_start "fleet_apply_verify_hosts_then_fans_out"
out="$(fleet apply --verify-hosts --jobs 1 --cmd "echo hi" 2>&1)"
rc=$?
assert_equals 0 "$rc" "verified apply exits 0"
assert_contains "all hosts found in known_hosts" "$out" "verification confirmation"
assert_contains "2 ok / 0 failed / 2 total" "$out" "summary line"
assert_file_contains "$SSH_LOG" "user@alpha.test echo hi" "alpha received the command"
assert_file_contains "$SSH_LOG" "user@beta.test:2222 echo hi" "beta received the command"
assert_file_contains "$EVENTS" '"event":"apply"' "apply events emitted"
assert_file_contains "$EVENTS" '"host":"beta"' "event carries the host"

test_start "fleet_apply_reports_failed_hosts"
cat >"$SHIMS/ssh" <<'SHIM'
#!/usr/bin/env bash
# Failing variant: every connection "breaks" with a diagnostic on stderr.
echo "shim: connection refused" >&2
exit 255
SHIM
chmod +x "$SHIMS/ssh"
out="$(fleet apply --cmd "uptime" 2>&1)"
rc=$?
assert_equals 1 "$rc" "any failed host makes apply exit 1"
assert_contains "0 ok / 2 failed / 2 total" "$out" "summary counts failures"
assert_contains "connection refused" "$out" "first stderr line surfaced per host"
assert_file_contains "$EVENTS" '"status":"fail 255"' "event records the ssh exit code"
cat >"$SHIMS/ssh" <<'SHIM'
#!/usr/bin/env bash
target=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) shift 2 ;;
    -*) shift ;;
    *)
      target="$1"
      shift
      break
      ;;
  esac
done
printf '%s %s\n' "$target" "$*" >>"${FAKE_SSH_LOG:?}"
exit 0
SHIM
chmod +x "$SHIMS/ssh"

test_start "fleet_apply_push_alias"
rm -f "$SSH_LOG"
out="$(fleet push --host alpha --cmd "uptime" 2>&1)"
rc=$?
assert_equals 0 "$rc" "push alias exits 0"
assert_contains "1 ok / 0 failed / 1 total" "$out" "single host summary"
assert_file_contains "$SSH_LOG" "user@alpha.test uptime" "only alpha contacted"

# ── dispatcher ──────────────────────────────────────────────────────
test_start "fleet_default_subcommand_with_flag"
out="$(fleet --json 2>&1)"
rc=$?
assert_equals 0 "$rc" "flag-only argv exits 0"
assert_contains '{"node_id"' "$out" "--json without subcommand runs status --json"

test_start "fleet_unknown_subcommand_prints_usage"
out="$(fleet bogus 2>&1)"
rc=$?
assert_equals 0 "$rc" "usage listing exits 0"
assert_contains "Fleet Commands" "$out" "usage header"
assert_contains "enforce" "$out" "enforce listed"
assert_contains "apply" "$out" "apply listed"

test_start "fleet_dispatch_without_fleet_prefix"
out="$(bash "$FLEET" --json 2>&1)"
rc=$?
assert_equals 0 "$rc" "direct invocation exits 0"
assert_contains '{"node_id"' "$out" "prefix-less argv still dispatches"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
