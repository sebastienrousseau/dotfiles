#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
#
# Mocked-SSH coverage for `dot fleet apply`. The dry-run path is
# already covered by tests/unit/auto/test_auto_cmd_fleet.sh; this
# test takes the FULL apply path with a fake `ssh` binary on PATH
# so the per-host SSH invocation, status capture, summary line,
# and event-emit paths all execute without leaving the machine.
#
# Closes the round-2 audit gap "fleet apply has only dry-run
# coverage; the real-fanout branch is unverified."
# AUTO-GENERATED: false (hand-written)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

DOT_BIN="$REPO_ROOT/bin/dot"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

# ─── Build a fake-ssh shim that always succeeds with predictable output ───
_shim_dir="$(mktemp -d -t fleet-apply-ssh.XXXXXX)"
cat > "$_shim_dir/ssh" <<'SHIM'
#!/usr/bin/env bash
# Fake ssh — accepts the same flags as real ssh but never opens a
# socket. Prints "shim-ok <argv>" to stdout, exits 0. Used by the
# fleet-apply mocked-SSH test.
exit_rc=0
target=""
cmd=""
# Parse args: skip any `-o foo=bar` pairs, capture target + command.
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) shift 2 ;;
    -*) shift ;;
    *) if [[ -z "$target" ]]; then target="$1"; else cmd="$cmd $1"; fi; shift ;;
  esac
done
printf 'shim-ok target=%s cmd=%s\n' "$target" "$cmd"
exit "$exit_rc"
SHIM
chmod +x "$_shim_dir/ssh"
trap 'rm -rf "$_shim_dir"; cov_teardown_sandbox' EXIT
export PATH="$_shim_dir:$PATH"

# ─── fleet.toml fixture ───
_fleet_dir="$(mktemp -d -t fleet-apply-cfg.XXXXXX)"
cat > "$_fleet_dir/fleet.toml" <<'TOML'
[hosts.alpha]
ssh = "user@alpha.test"
profile = "workstation"

[hosts.beta]
ssh = "user@beta.test"
profile = "minimal"
TOML
export DOTFILES_FLEET_HOSTS="$_fleet_dir/fleet.toml"

# ─── 1. Happy path — both hosts succeed via the shim ───
test_start "fleet_apply_two_hosts_via_shim"
out="$(cd "$REPO_ROOT" && bash "$DOT_BIN" fleet apply --cmd "echo hi" 2>&1)"
rc=$?
if [[ "$rc" -eq 0 ]] && [[ "$out" == *"2 ok"* ]] && [[ "$out" == *"0 failed"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: rc=$rc, output: ${out: -200}"
fi

# ─── 2. --host filter restricts the apply to one host ───
test_start "fleet_apply_host_filter"
out="$(cd "$REPO_ROOT" && bash "$DOT_BIN" fleet apply --host alpha --cmd "echo hi" 2>&1)"
rc=$?
if [[ "$rc" -eq 0 ]] && [[ "$out" == *"1 ok"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: rc=$rc"
fi

# ─── 3. Failing-shim variant — when ssh exits non-zero per host ───
cat > "$_shim_dir/ssh" <<'SHIM'
#!/usr/bin/env bash
printf 'shim-fail\n' >&2
exit 7
SHIM
chmod +x "$_shim_dir/ssh"

test_start "fleet_apply_all_hosts_fail"
out="$(cd "$REPO_ROOT" && bash "$DOT_BIN" fleet apply --cmd "false" 2>&1)"
rc=$?
# Failed hosts → cmd_fleet_apply returns non-zero, summary should
# show "0 ok / 2 failed".
if [[ "$rc" -ne 0 ]] && [[ "$out" == *"0 ok"* ]] && [[ "$out" == *"2 failed"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: rc=$rc"
fi

# ─── 4. Empty hosts file — apply should refuse with a clear error ───
echo "" > "$_fleet_dir/empty.toml"
test_start "fleet_apply_refuses_empty_hosts_file"
if DOTFILES_FLEET_HOSTS="$_fleet_dir/empty.toml" bash "$DOT_BIN" fleet apply --cmd "true" >/dev/null 2>&1; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should have refused"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
fi

# ─── 5. Missing hosts file — apply should refuse with a clear error ───
test_start "fleet_apply_refuses_missing_hosts_file"
if DOTFILES_FLEET_HOSTS="/nonexistent/path/fleet.toml" bash "$DOT_BIN" fleet apply --cmd "true" >/dev/null 2>&1; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should have refused"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
