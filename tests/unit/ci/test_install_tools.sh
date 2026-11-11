#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1091
# tools/ci/install-tools.sh installs a missing CI tool with apt and, when apt
# cannot (on 2026-11-11 security.ubuntu.com stopped resolving on the runners
# for hours), from a pinned release whose SHA-256 it checks first. Downloads
# here are file:// fixtures, so nothing leaves the machine; apt and sudo are
# stubbed as functions after the script is sourced.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

INSTALLER="$REPO_ROOT/tools/ci/install-tools.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/install-tools.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
export TMPDIR="$WORK"

# sha256_of FILE: the file's SHA-256, on Linux or macOS.
sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# in_installer CODE: run CODE in a subshell that has sourced the installer,
# with sudo a pass-through and binaries going to $WORK/bin (on PATH).
in_installer() {
  local code="$1"
  (
    export INSTALL_TOOLS_BIN_DIR="$WORK/bin"
    mkdir -p "$INSTALL_TOOLS_BIN_DIR"
    PATH="$INSTALL_TOOLS_BIN_DIR:$PATH"
    # sudo is stubbed before sourcing, and sourced with no arguments, so a
    # sourcing that ran the installer could never reach the real sudo.
    sudo() { "$@"; }
    set --
    source "$INSTALLER"
    eval "$code"
  )
}

# Fixtures: a plain binary and a release tarball holding one in a subdirectory.
mkdir -p "$WORK/fx/pkg-1.0" "$WORK/bin"
printf '#!/bin/sh\necho plain-tool\n' >"$WORK/fx/plain"
printf '#!/bin/sh\necho packed-tool\n' >"$WORK/fx/pkg-1.0/packed"
tar -czf "$WORK/fx/pkg.tar.gz" -C "$WORK/fx" pkg-1.0
PLAIN_SUM="$(sha256_of "$WORK/fx/plain")"
TAR_SUM="$(sha256_of "$WORK/fx/pkg.tar.gz")"
BAD_SUM="0000000000000000000000000000000000000000000000000000000000000000"

test_start "sourcing_the_installer_runs_nothing"
out="$(in_installer 'echo sourced' 2>&1)"
assert_equals "sourced" "$out" "sourcing prints nothing and installs nothing"

test_start "a_pinned_binary_with_the_right_checksum_is_installed"
in_installer "install_pinned 'file://$WORK/fx/plain' '$PLAIN_SUM' plain-tool" >/dev/null 2>&1
assert_equals "plain-tool" "$("$WORK/bin/plain-tool" 2>/dev/null)" "the binary is installed, executable"

test_start "a_pinned_tarball_is_unpacked_for_its_binary"
in_installer "install_pinned 'file://$WORK/fx/pkg.tar.gz' '$TAR_SUM' packed" >/dev/null 2>&1
assert_equals "packed-tool" "$("$WORK/bin/packed" 2>/dev/null)" "the binary inside the tarball is installed"

test_start "a_checksum_mismatch_installs_nothing"
rc=0
in_installer "install_pinned 'file://$WORK/fx/plain' '$BAD_SUM' tampered" >/dev/null 2>&1 || rc=$?
assert_equals "1" "$rc" "install_pinned fails"
assert_equals "absent" "$([[ -e "$WORK/bin/tampered" ]] && echo present || echo absent)" "nothing is installed"

test_start "only_ripgrep_and_shfmt_have_pins_and_only_on_linux_x86_64"
linux='uname() { case "$1" in -s) echo Linux ;; -m) echo x86_64 ;; esac; }'
spec="$(in_installer "$linux; fallback_spec ripgrep")"
assert_contains "https://github.com/BurntSushi/ripgrep/releases/download/" "$spec" "ripgrep is pinned to a GitHub release"
assert_contains " rg" "$spec" "and provides rg"
spec="$(in_installer "$linux; fallback_spec shfmt")"
assert_contains "https://github.com/mvdan/sh/releases/download/" "$spec" "shfmt is pinned to a GitHub release"
rc=0
in_installer "$linux; fallback_spec yq" >/dev/null 2>&1 || rc=$?
assert_equals "1" "$rc" "yq has no pin: it stays on the package manager"
rc=0
in_installer 'uname() { case "$1" in -s) echo Darwin ;; -m) echo arm64 ;; esac; }; fallback_spec ripgrep' >/dev/null 2>&1 || rc=$?
assert_equals "1" "$rc" "no pin off Linux x86_64"

test_start "when_apt_fails_the_pinned_release_is_used"
out="$(in_installer "apt_install_missing() { return 1; }
  fallback_spec() { printf '%s %s %s\n' 'file://$WORK/fx/plain' '$PLAIN_SUM' fallback-tool; }
  main fallback-pkg:fallback-tool" 2>&1)"
rc=$?
assert_equals "0" "$rc" "the install succeeds"
assert_contains "apt attempt 1/3 failed" "$out" "after one failed apt attempt"
assert_equals "plain-tool" "$("$WORK/bin/fallback-tool" 2>/dev/null)" "from the pinned release"

test_start "when_apt_fails_and_a_tool_has_no_pin_the_install_fails"
out="$(in_installer 'apt_install_missing() { return 1; }; sleep() { :; }
  fallback_spec() { return 1; }
  main no-pin-pkg:no-pin-tool' 2>&1)"
rc=$?
assert_equals "1" "$rc" "the install fails"
assert_contains "Failed to install after 3 attempts: no-pin-pkg" "$out" "with the apt error"

test_start "a_tool_already_present_skips_apt_and_the_fallback"
out="$(in_installer 'apt_install_missing() { echo APT-RAN; }; main sh' 2>&1)"
assert_contains "skipping apt entirely" "$out" "nothing is installed"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
