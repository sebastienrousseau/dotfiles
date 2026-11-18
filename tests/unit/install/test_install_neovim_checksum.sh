#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# install/lib/install_neovim.sh verified the tarball with
# `sha256sum -c <checksum file>`, which checks the file NAMED inside the
# checksum file relative to the current directory, not $TARBALL. Run from a
# directory holding a matching nvim-linux64.tar.gz, a tampered
# ~/nvim-linux64.tar.gz passed and was installed. Runs the script against
# stubbed uname/id/sudo/sha256sum and real tarballs.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

HELPER="$REPO_ROOT/install/lib/install_neovim.sh"
WORK="$(mktemp -d -t nvim-checksum.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

hash_of() { shasum -a 256 "$1" | awk '{print $1}'; }

# make_tarball <out> <payload>: an nvim-linux64 tree whose nvim prints <payload>.
make_tarball() {
  local d
  d="$(mktemp -d "$WORK/tree.XXXXXX")"
  mkdir -p "$d/nvim-linux64/bin"
  printf '#!/bin/sh\necho %s\n' "$2" >"$d/nvim-linux64/bin/nvim"
  chmod +x "$d/nvim-linux64/bin/nvim"
  tar -C "$d" -czf "$1" nvim-linux64
}

# new_case NAME: HOME, stubs (Linux, non-root, sudo runs as the user,
# sha256sum backed by shasum) and a working directory.
new_case() {
  C="$WORK/$1"
  mkdir -p "$C/bin" "$C/home/.local/opt" "$C/home/.local/bin" "$C/cwd"
  printf '#!/bin/sh\necho Linux\n' >"$C/bin/uname"
  printf '#!/bin/sh\necho 1000\n' >"$C/bin/id"
  printf '#!/bin/sh\nexec "$@"\n' >"$C/bin/sudo"
  printf '#!/bin/sh\nexec shasum -a 256 "$@"\n' >"$C/bin/sha256sum"
  chmod +x "$C/bin/"*
}

run_helper() {
  RC=0
  OUT="$(cd "$C/cwd" && env PATH="$C/bin:/usr/bin:/bin" HOME="$C/home" \
    NVIM_INSTALL_DIR="$C/home/.local/opt" NVIM_BIN_DIR="$C/home/.local/bin" \
    bash "$HELPER" 2>&1 </dev/null)" || RC=$?
}

test_start "tampered_tarball_is_rejected_whatever_the_cwd_holds"
new_case tampered
make_tarball "$C/cwd/nvim-linux64.tar.gz" genuine
make_tarball "$C/home/nvim-linux64.tar.gz" tampered
printf '%s  nvim-linux64.tar.gz\n' "$(hash_of "$C/cwd/nvim-linux64.tar.gz")" \
  >"$C/home/nvim-linux64.tar.gz.sha256sum"
run_helper
assert_not_equals "0" "$RC" "the install fails"
assert_contains "Checksum verification failed" "$OUT" "on the checksum of \$TARBALL itself"
assert_file_not_exists "$C/home/.local/opt/nvim-linux64/bin/nvim" "nothing was extracted"

test_start "matching_tarball_is_installed"
new_case good
make_tarball "$C/home/nvim-linux64.tar.gz" genuine
printf '%s  nvim-linux64.tar.gz\n' "$(hash_of "$C/home/nvim-linux64.tar.gz")" \
  >"$C/home/nvim-linux64.tar.gz.sha256sum"
run_helper
assert_contains "Checksum verified." "$OUT" "a matching tarball verifies from any cwd"
assert_file_exists "$C/home/.local/opt/nvim-linux64/bin/nvim" "and is extracted"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
