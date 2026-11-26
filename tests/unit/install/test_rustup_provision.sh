#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# install/provision/run_onchange_26-rust-tools.sh.tmpl installs the standalone
# rustup on macOS and Linux, verifying the rustup-init binary for this
# platform against its published checksum, and retires Homebrew's rustup.
# (It used to fetch rustup-init.sh with a checksum URL rust-lang.org does not
# publish, a 404, so rustup never installed on Linux; drill A1.) With both installed, each one's
# proxies fall back to the other's and `rust-analyzer` recursed forever.
# Homebrew's copy is removed only once the replacement is downloaded and
# verified, so a failed download never leaves a machine without rustup.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/module_fixture.sh"

if ! command -v chezmoi >/dev/null 2>&1; then
  echo "SKIP: chezmoi is needed to render the template"
  echo "RESULTS:0:0:0"
  exit 0
fi

WORK="$(mktemp -d -t rustup-provision.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
STUBS="$WORK/stubs"
CALLS="$WORK/calls.log"
INSTALLER='#!/bin/sh
echo "rustup-init $*" >>"$CALLS"
mkdir -p "$HOME/.cargo/bin" && cp "$RUSTUP_STUB" "$HOME/.cargo/bin/rustup"'
mkdir -p "$STUBS" "$WORK/cz"
dot_fixture_basebin "$WORK/base" sha256sum shasum
: >"$WORK/cz/chezmoi.toml"

# stub <name> [body]: records "<name> <args>" in $CALLS, then runs <body>.
stub() {
  printf '#!/bin/sh\necho "%s $*" >>"$CALLS"\n%s\n' "$1" "${2:-exit 0}" >"$STUBS/$1"
  chmod +x "$STUBS/$1"
}
stub cargo
stub curl 'out=""; url=""
while [ $# -gt 0 ]; do case "$1" in -o) out="$2"; shift ;; https://*) url="$1" ;; esac; shift; done
[ -n "$CURL_FAIL" ] && exit 22
case "$url" in
  https://static.rust-lang.org/rustup/dist/*/rustup-init) printf "%s\n" "$INSTALLER" >"$out" ;;
  https://static.rust-lang.org/rustup/dist/*/rustup-init.sha256) printf "%s *./rustup-init\n" "$INSTALLER_SHA" >"$out" ;;
esac'
stub brew 'case "$1" in list) [ -n "$BREW_HAS_RUSTUP" ] ;; esac'
printf '#!/bin/sh\necho "rustup $*" >>"$CALLS"\n' >"$WORK/rustup.stub"
chmod +x "$WORK/rustup.stub"
REAL_SHA="$(printf '%s\n' "$INSTALLER" | { sha256sum 2>/dev/null || shasum -a 256; } | awk '{print $1}')"

env -i HOME="$WORK/cz" PATH="$STUBS:$PATH" chezmoi --config "$WORK/cz/chezmoi.toml" \
  --source "$REPO_ROOT/defaults" --persistent-state "$WORK/cz/state" \
  execute-template <"$REPO_ROOT/install/provision/run_onchange_26-rust-tools.sh.tmpl" >"$WORK/rust.sh"

# run [VAR=value...]: a fresh HOME, then the rendered script. Sets RC and OUT.
run() {
  local home="$WORK/home.$RANDOM"
  mkdir -p "$home"
  [[ -n "${STANDALONE:-}" ]] && mkdir -p "$home/.cargo/bin" && cp "$WORK/rustup.stub" "$home/.cargo/bin/rustup"
  : >"$CALLS"
  RC=0
  OUT="$(env -i HOME="$home" PATH="$STUBS:$WORK/base" CALLS="$CALLS" INSTALLER="$INSTALLER" \
    INSTALLER_SHA="${INSTALLER_SHA:-$REAL_SHA}" RUSTUP_STUB="$WORK/rustup.stub" "$@" \
    bash "$WORK/rust.sh" 2>&1 </dev/null)" || RC=$?
}
calls() { cat "$CALLS"; }
# line_of <pattern>: the first line number in $CALLS that matches, or 0.
line_of() { grep -n -m1 -e "$1" "$CALLS" | cut -d: -f1 | grep . || echo 0; }

test_start "fresh_machine_gets_verified_standalone_rustup"
run
assert_equals "0" "$RC" "exits 0"
assert_contains "curl --proto =https --tlsv1.2 -fsSL -o" "$(calls)" "downloads over HTTPS only"
assert_contains "rustup-init -y --no-modify-path" "$(calls)" "runs the verified installer"
assert_contains "rustup component add rust-analyzer" "$(calls)" "then installs components with the new rustup"

test_start "the_installer_is_this_platforms_rustup_init"
run
assert_contains "https://static.rust-lang.org/rustup/dist/$(case "$(uname -s)-$(uname -m)" in
  Linux-x86_64) echo x86_64-unknown-linux-gnu ;;
  Linux-aarch64 | Linux-arm64) echo aarch64-unknown-linux-gnu ;;
  Darwin-arm64) echo aarch64-apple-darwin ;;
  Darwin-x86_64) echo x86_64-apple-darwin ;;
esac)/rustup-init" "$(calls)" "the rustup-init binary for this OS and CPU"

for platform in "Linux x86_64 x86_64-unknown-linux-gnu" "Linux aarch64 aarch64-unknown-linux-gnu" \
  "Darwin arm64 aarch64-apple-darwin" "Darwin x86_64 x86_64-apple-darwin"; do
  read -r os cpu target <<<"$platform"
  test_start "rustup_target_for_${os}_${cpu}"
  stub uname "case \"\$1\" in -s) echo $os ;; -m) echo $cpu ;; esac"
  run
  assert_contains "/rustup/dist/$target/rustup-init" "$(calls)" "$os $cpu downloads $target"
  rm -f "$STUBS/uname"
done

test_start "checksum_mismatch_never_runs_the_installer"
INSTALLER_SHA="$(printf '0%.0s' {1..64})" run
assert_equals "0" "$RC" "never fails the apply"
assert_output_not_contains "rustup-init -y" calls
assert_contains "checksum mismatch" "$OUT" "says why"
assert_output_not_contains "cargo install" calls

test_start "homebrew_rustup_is_replaced_after_verification"
run BREW_HAS_RUSTUP=1
assert_equals "0" "$RC" "exits 0"
dl="$(line_of 'rustup/dist/')" un="$(line_of 'brew uninstall rustup')" init="$(line_of '^rustup-init ')"
assert_true "(( dl > 0 && un > dl && init > un ))" \
  "download ($dl), then brew uninstall ($un), then install ($init)"

test_start "homebrew_and_standalone_keeps_standalone"
STANDALONE=1 run BREW_HAS_RUSTUP=1
assert_contains "brew uninstall rustup" "$(calls)" "the Homebrew duplicate goes"
assert_output_not_contains "sh.rustup.rs" calls
assert_output_not_contains "rustup-init -y" calls

test_start "failed_download_keeps_homebrew_rustup"
run BREW_HAS_RUSTUP=1 CURL_FAIL=1
assert_equals "0" "$RC" "never fails the apply"
assert_output_not_contains "brew uninstall" calls

test_start "standalone_only_is_left_alone"
STANDALONE=1 run
assert_output_not_contains "curl" calls
assert_output_not_contains "brew uninstall" calls
assert_contains "rustup update stable" "$(calls)" "the existing rustup is used"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
