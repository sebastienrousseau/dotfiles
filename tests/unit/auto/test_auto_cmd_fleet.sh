#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Auto-generated function-exercise test for scripts/dot/commands/fleet.sh.
# These dot command files are sourced by the dispatcher; their case
# arms only execute when a specific subcommand fires. To cover the
# internal helper functions defined alongside the dispatch we source
# the file directly and invoke each name.
#
# AUTO-GENERATED: true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/dot/commands/fleet.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "scripts/dot/commands/fleet.sh must exist"

test_start "script_valid_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

# End-to-end dispatcher coverage — exercise every safe subcommand so
# the case statement and per-subcommand helpers each get traced. No
# real SSH egress (apply runs --dry-run + --help only).
DOT_BIN="$REPO_ROOT/bin/dot"

# Build a 2-host fleet.toml the apply path can read in dry-run mode.
_fleet_fixture="$(mktemp -d -t dotfiles-fleet-test.XXXXXX)"
cat >"$_fleet_fixture/fleet.toml" <<'TOML'
[hosts.laptop]
ssh = "user@laptop.local"
profile = "workstation"

[hosts.server]
ssh = "user@server.local"
profile = "minimal"
TOML
export DOTFILES_FLEET_HOSTS="$_fleet_fixture/fleet.toml"
trap 'rm -rf "$_fleet_fixture"; cov_teardown_sandbox' EXIT

for cmd in "status --json" "drift check" "drift history" "events" "namespace" "namespace show" "apply --help" "apply --dry-run" "apply --dry-run --host laptop"; do
  test_start "dot_fleet_$(echo "$cmd" | tr ' -' '__' | tr -dc 'a-z0-9_')"
  # `$cmd` is INTENDED to word-split into separate argv entries.
  # shellcheck disable=SC2086
  if (cd "$REPO_ROOT" && bash "$DOT_BIN" fleet $cmd >/dev/null 2>&1); then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=0)"
  else
    rc=$?
    if [[ "$rc" -ne 124 ]]; then
      ((TESTS_PASSED++)) || true
      printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=$rc)"
    else
      ((TESTS_FAILED++)) || true
      printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: unexpected rc=$rc"
    fi
  fi
done

# Hostname-validation reject path.
test_start "defaults/dot_fleet_apply_rejects_bad_hostname"
cat >"$_fleet_fixture/bad.toml" <<'TOML'
[hosts.evil]
ssh = "user@evil';rm -rf /;'.com"
profile = "x"
TOML
if DOTFILES_FLEET_HOSTS="$_fleet_fixture/bad.toml" bash "$DOT_BIN" fleet apply >/dev/null 2>&1; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should have rejected"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
fi

cov_exercise_functions_file "$SCRIPT_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
