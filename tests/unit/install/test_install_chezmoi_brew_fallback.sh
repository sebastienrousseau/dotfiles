#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# install.sh install_chezmoi on a machine with Homebrew: when `brew install
# chezmoi` fails, the installer falls back to the checksum-verified binary
# instead of stopping with "chezmoi installation failed" (Drill A1 on macOS
# runners stopped there, with brew's output discarded).
#
# install.sh is sourced, not run: brew is a stub, chezmoi is absent from
# PATH, and the verified binary install records that it was called.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
mkdir -p "$SANDBOX/stubs" "$SANDBOX/installer"
# A copy with no tools/ci beside it, so the embedded verifier is the path.
cp "$REPO_ROOT/install.sh" "$SANDBOX/installer/install.sh"

# The shell each case runs: install.sh sourced, the verified binary install
# recording its arguments in $CALLS, then install_chezmoi.
read -r -d '' CASE <<'EOF'
source "$INSTALLER" >/dev/null 2>&1
install_chezmoi_verified_embedded() { echo "verified $*" >>"$CALLS"; }
rc=0
install_chezmoi || rc=$?
echo "rc=$rc"
EOF

# run_install BREW_EXIT: install_chezmoi with a brew that exits BREW_EXIT;
# prints "rc=<code>" and the output, and leaves calls in $SANDBOX/calls.
run_install() {
  rm -f "$SANDBOX/calls"
  printf '#!/bin/sh\necho "brew $*" >>"%s/calls"\necho "brew says no" >&2\nexit %s\n' \
    "$SANDBOX" "$1" >"$SANDBOX/stubs/brew"
  chmod +x "$SANDBOX/stubs/brew"
  env -i HOME="$SANDBOX" TMPDIR="$SANDBOX" PATH="$SANDBOX/stubs:/usr/bin:/bin" \
    INSTALLER="$SANDBOX/installer/install.sh" CALLS="$SANDBOX/calls" \
    "$BASH" --norc --noprofile -c "$CASE" 2>&1
}

test_start "brew_failure_falls_back_to_the_verified_binary"
out="$(run_install 1)"
assert_contains "rc=0" "$out" "install_chezmoi succeeds"
assert_contains "Homebrew could not install chezmoi" "$out" "and says Homebrew failed"
assert_contains "verified 2.74.1 $SANDBOX/.local/bin" "$(cat "$SANDBOX/calls" 2>/dev/null)" \
  "the checksum-verified binary is installed instead"
assert_contains "brew says no" "$(cat "$SANDBOX/dotfiles-brew-chezmoi.log" 2>/dev/null)" \
  "brew's output is kept in the log the message names"

test_start "brew_success_needs_nothing_else"
out="$(run_install 0)"
assert_contains "rc=0" "$out" "install_chezmoi succeeds"
assert_equals "brew install chezmoi" "$(cat "$SANDBOX/calls" 2>/dev/null)" \
  "Homebrew alone installs chezmoi"

print_summary
