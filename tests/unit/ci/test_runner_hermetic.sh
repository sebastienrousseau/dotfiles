#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# The test runner keeps tests off the network and away from real builds:
# its hermetic guards refuse curl/wget to outside hosts and the build or
# download commands of cargo, rustup and go, unless the test file declares
# `# test-needs: <network|cargo|rustup|go>` in its header.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/runner-hermetic-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/tests/unit/fixture" "$WORK/fake" "$WORK/out"
cp -R "$REPO_ROOT/tests/framework" "$WORK/tests/framework"

# A fake cargo stands in for the real one the guard passes through to.
printf '#!/bin/sh\necho "fake cargo $*"\n' >"$WORK/fake/cargo"
chmod +x "$WORK/fake/cargo"

# fixture NAME HEADER COMMAND: a test file that runs COMMAND and records its
# exit status and output under $WORK/out/NAME.
fixture() {
  cat >"$WORK/tests/unit/fixture/test_hfixture_$1.sh" <<EOF
#!/usr/bin/env bash
$2
out=\$($3 2>&1); echo "\$?" >"$WORK/out/$1.rc"; printf '%s' "\$out" >"$WORK/out/$1.txt"
echo "RESULTS:1:1:0"
EOF
}

fixture net "" "curl -fsS https://example.invalid/x"
fixture loopback "" "curl -fsS http://127.0.0.1:9/"
fixture build "" "cargo build --release"
fixture list "" "cargo install --list"
fixture declared "# test-needs: cargo" "cargo build --release"

PATH="$WORK/fake:$PATH" bash "$WORK/tests/framework/test_runner.sh" 'hfixture_*' >"$WORK/runner.log" 2>&1

test_start "outside_network_is_refused"
assert_equals "97" "$(cat "$WORK/out/net.rc")" "curl to an outside host exits 97"
assert_contains "test-needs: network" "$(cat "$WORK/out/net.txt")" "the refusal says how to opt in"

test_start "loopback_is_allowed"
if [[ "$(cat "$WORK/out/loopback.rc")" != "97" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: curl to 127.0.0.1 was refused"
fi

test_start "real_build_is_refused"
assert_equals "97" "$(cat "$WORK/out/build.rc")" "cargo build exits 97"
assert_contains "test-needs: cargo" "$(cat "$WORK/out/build.txt")" "the refusal names the declaration"

test_start "read_only_probe_passes_through"
assert_equals "fake cargo install --list" "$(cat "$WORK/out/list.txt")" "cargo install --list reaches the real tool"

test_start "declared_need_passes_through"
assert_equals "fake cargo build --release" "$(cat "$WORK/out/declared.txt")" "a declared need reaches the real tool"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
