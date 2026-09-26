#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016,SC2034
# Unit tests for Wave 1: install.sh chezmoi installation strategy
#
# install.sh is never run. A copy is sourced in a sandbox (sourcing does
# not call main), the chezmoi installer functions nested in main are
# lifted out of `declare -f main` and run with brew, curl, chezmoi and
# the verified installer replaced by stubs that record their calls.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

INSTALL_SCRIPT="$REPO_ROOT/install.sh"

echo "Testing Wave 1: install.sh chezmoi installation..."

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
INST="$SANDBOX/installer"
mkdir -p "$INST/tools/ci" "$SANDBOX/bin"
cp "$INSTALL_SCRIPT" "$INST/install.sh"

# Lift install_chezmoi and install_chezmoi_verified_embedded out of main.
# They are written next to the install.sh copy so their BASH_SOURCE-based
# lookup of tools/ci/install-chezmoi-verified.sh resolves into the sandbox.
env -i HOME="$SANDBOX" PATH="/usr/bin:/bin" "$BASH" --norc --noprofile -c \
  'source "$1" && declare -f main' _ "$INST/install.sh" |
  awk '/^    function install_chezmoi(_verified_embedded)? \(\) *$/ { on = 1 }
       on { print }
       on && /^    };?$/ { on = 0 }' >"$INST/nested.sh"

# run_install <home> <path> [VAR=value ...]: run install_chezmoi in a clean
# bash the way main does (a background subshell under install.sh's
# `set -euo pipefail`, then wait); stdout+stderr go to $SANDBOX/out.txt,
# the exit code is printed.
run_install() {
  local home="$1" path="$2"
  shift 2
  mkdir -p "$home"
  env -i HOME="$home" PATH="$path" CALL_LOG="$SANDBOX/calls.log" "$@" \
    "$BASH" --norc --noprofile -c 'source "$1"; source "$2"
      (install_chezmoi) &
      rc=0; wait "$!" || rc=$?; echo "rc=$rc"' \
    _ "$INST/install.sh" "$INST/nested.sh" >"$SANDBOX/out.txt" 2>&1
  sed -n 's/^rc=//p' "$SANDBOX/out.txt"
}

# stub <dir> <name> <body>: an executable that logs "<name> <args>" then runs <body>.
stub() {
  printf '#!/bin/sh\necho "%s $*" >>"$CALL_LOG"\n%s\n' "$2" "$3" >"$1/$2"
  chmod +x "$1/$2"
}

# Directories of stubs, combined per scenario. /usr/bin:/bin never holds
# chezmoi or brew, so a scenario only sees the ones it lists.
mkdir -p "$SANDBOX/has-chezmoi" "$SANDBOX/has-brew" "$SANDBOX/has-curl"
stub "$SANDBOX/has-chezmoi" chezmoi 'echo "chezmoi version v9.9.9"'
stub "$SANDBOX/has-brew" brew 'exit 0'
stub "$SANDBOX/has-curl" curl 'exit 22'
SYS="/usr/bin:/bin"

test_start "installer_functions_lifted"
assert_equals "function function" \
  "$(env -i PATH="$SYS" "$BASH" --norc --noprofile -c 'source "$1"; echo $(type -t install_chezmoi install_chezmoi_verified_embedded)' _ "$INST/nested.sh")" \
  "install_chezmoi and its verified bootstrap are defined in main"

# --- chezmoi already installed ---

: >"$SANDBOX/calls.log"
rc="$(run_install "$SANDBOX/h1" "$SANDBOX/has-chezmoi:$SANDBOX/has-brew:$SANDBOX/has-curl:$SYS")"

test_start "install_chezmoi_already_installed"
assert_equals "0|chezmoi version v9.9.9" "$rc|$(sed -n 's/^ *chezmoi already installed: //p' "$SANDBOX/out.txt")" \
  "an existing chezmoi is reported and kept"

test_start "install_chezmoi_already_installed_no_install"
assert_equals "chezmoi --version" "$(cat "$SANDBOX/calls.log")" \
  "with chezmoi present, brew and curl are never called"

# --- Homebrew ---

: >"$SANDBOX/calls.log"
rc="$(run_install "$SANDBOX/h2" "$SANDBOX/has-brew:$SANDBOX/has-curl:$SYS")"

test_start "install_brew_chezmoi"
assert_equals "0|brew install chezmoi" "$rc|$(cat "$SANDBOX/calls.log")" \
  "without chezmoi, Homebrew installs it (and nothing else runs)"

test_start "install_brew_no_local_bin"
assert_equals "absent" "$([[ -e "$SANDBOX/h2/.local/bin" ]] && echo present || echo absent)" \
  "the Homebrew path does not create ~/.local/bin"

# --- No Homebrew: checksum-verified installer into ~/.local/bin ---

stub "$INST/tools/ci" install-chezmoi-verified.sh 'exit 0'
: >"$SANDBOX/calls.log"
rc="$(run_install "$SANDBOX/h3" "$SANDBOX/has-curl:$SYS")"

test_start "install_local_bin_path"
assert_equals "0|install-chezmoi-verified.sh 2.47.1 $SANDBOX/h3/.local/bin" "$rc|$(cat "$SANDBOX/calls.log")" \
  "without Homebrew, the verified installer targets ~/.local/bin (curl unused)"

test_start "install_local_bin_created"
assert_equals "present" "$([[ -d "$SANDBOX/h3/.local/bin" ]] && echo present || echo absent)" \
  "the ~/.local/bin dir is created for the binary"

: >"$SANDBOX/calls.log"
rc="$(run_install "$SANDBOX/h4" "$SANDBOX/has-curl:$SYS" CHEZMOI_VERSION=2.60.0)"
test_start "install_chezmoi_version_override"
assert_equals "0|install-chezmoi-verified.sh 2.60.0 $SANDBOX/h4/.local/bin" "$rc|$(cat "$SANDBOX/calls.log")" \
  "CHEZMOI_VERSION selects the chezmoi release"

stub "$INST/tools/ci" install-chezmoi-verified.sh 'exit 1'
: >"$SANDBOX/calls.log"
rc="$(run_install "$SANDBOX/h5" "$SANDBOX/has-curl:$SYS")"

test_start "install_verified_failure_refuses_fallback"
assert_equals "1|install-chezmoi-verified.sh 2.47.1 $SANDBOX/h5/.local/bin|yes" \
  "$rc|$(cat "$SANDBOX/calls.log")|$(grep -q 'Refusing to fall back' "$SANDBOX/out.txt" && echo yes || echo no)" \
  "a failed verified install fails without trying another source"

# --- No verified installer script: embedded checksum verifier ---

rm -f "$INST/tools/ci/install-chezmoi-verified.sh"

test_start "install_embedded_download_failure"
: >"$SANDBOX/calls.log"
rc="$(run_install "$SANDBOX/h6" "$SANDBOX/has-curl:$SYS")"
assert_equals "1|github.com/twpayne/chezmoi|no|yes" \
  "$rc|$(grep -o 'github.com/twpayne/chezmoi' "$SANDBOX/calls.log" | sort -u)|$(grep -q 'get.chezmoi.io' "$SANDBOX/calls.log" && echo yes || echo no)|$(grep -q 'Refusing to fall back' "$SANDBOX/out.txt" && echo yes || echo no)" \
  "a failed release download fails; get.chezmoi.io is never fetched"

# A fake release: curl serves a tarball holding a `chezmoi` script and a
# checksums file, both built here.
os="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch="$(uname -m)"
case "$arch" in x86_64 | amd64) arch=amd64 ;; arm64 | aarch64) arch=arm64 ;; esac
asset="chezmoi_2.47.1_${os}_${arch}.tar.gz"
REL="$SANDBOX/release"
mkdir -p "$REL/pkg"
printf '#!/bin/sh\necho fake-chezmoi\n' >"$REL/pkg/chezmoi"
chmod +x "$REL/pkg/chezmoi"
tar -czf "$REL/$asset" -C "$REL/pkg" chezmoi
if command -v sha256sum >/dev/null 2>&1; then
  sum="$(sha256sum "$REL/$asset" | awk '{print $1}')"
else
  sum="$(shasum -a 256 "$REL/$asset" | awk '{print $1}')"
fi
# curl -o <dest> <url>: copy the release file named by the URL's last part.
stub "$SANDBOX/has-curl" curl "out=''; url=''
while [ \$# -gt 0 ]; do case \"\$1\" in -o) out=\"\$2\"; shift ;; https://*) url=\"\$1\" ;; esac; shift; done
cp \"$REL/\${url##*/}\" \"\$out\""

printf '%s  %s\n' "$sum" "$asset" >"$REL/chezmoi_2.47.1_checksums.txt"
: >"$SANDBOX/calls.log"
rc="$(run_install "$SANDBOX/h7" "$SANDBOX/has-curl:$SYS")"
test_start "install_embedded_verified_install"
assert_equals "0|fake-chezmoi" "$rc|$("$SANDBOX/h7/.local/bin/chezmoi" 2>/dev/null)" \
  "a release whose checksum matches is installed to ~/.local/bin"

printf '%s  %s\n' "0000000000000000000000000000000000000000000000000000000000000000" "$asset" \
  >"$REL/chezmoi_2.47.1_checksums.txt"
: >"$SANDBOX/calls.log"
rc="$(run_install "$SANDBOX/h8" "$SANDBOX/has-curl:$SYS")"
test_start "install_embedded_checksum_mismatch"
assert_equals "1|absent" "$rc|$([[ -e "$SANDBOX/h8/.local/bin/chezmoi" ]] && echo present || echo absent)" \
  "a release whose checksum does not match is rejected and not installed"

# The checksum list downloads but the release archive does not: refused.
printf '%s  %s\n' "$sum" "$asset" >"$REL/chezmoi_2.47.1_checksums.txt"
mv "$REL/$asset" "$REL/$asset.held"
: >"$SANDBOX/calls.log"
rc="$(run_install "$SANDBOX/h9" "$SANDBOX/has-curl:$SYS")"
mv "$REL/$asset.held" "$REL/$asset"
test_start "install_embedded_asset_download_failure"
assert_equals "1|absent" "$rc|$([[ -e "$SANDBOX/h9/.local/bin/chezmoi" ]] && echo present || echo absent)" \
  "a failed archive download is refused, not reported as installed"

# An archive that matches its checksum but is not a tarball: refused.
cp "$REL/$asset" "$REL/$asset.good"
printf 'not a tarball\n' >"$REL/$asset"
if command -v sha256sum >/dev/null 2>&1; then
  bad="$(sha256sum "$REL/$asset" | awk '{print $1}')"
else
  bad="$(shasum -a 256 "$REL/$asset" | awk '{print $1}')"
fi
printf '%s  %s\n' "$bad" "$asset" >"$REL/chezmoi_2.47.1_checksums.txt"
: >"$SANDBOX/calls.log"
rc="$(run_install "$SANDBOX/h10" "$SANDBOX/has-curl:$SYS")"
mv "$REL/$asset.good" "$REL/$asset"
test_start "install_embedded_extract_failure"
assert_equals "1|absent" "$rc|$([[ -e "$SANDBOX/h10/.local/bin/chezmoi" ]] && echo present || echo absent)" \
  "an archive that cannot be extracted is refused, not reported as installed"

# --- Paths and version pin (top level of install.sh) ---

test_start "install_source_dir_defined"
assert_equals "$SANDBOX/h9/.dotfiles" \
  "$(env -i HOME="$SANDBOX/h9" PATH="$SYS" "$BASH" --norc --noprofile -c 'source "$1"; echo "$SOURCE_DIR"' _ "$INST/install.sh")" \
  "SOURCE_DIR defaults to ~/.dotfiles"

test_start "install_source_dir_override"
assert_equals "/srv/dots" \
  "$(env -i HOME="$SANDBOX/h9" PATH="$SYS" SOURCE_DIR=/srv/dots "$BASH" --norc --noprofile -c 'source "$1"; echo "$SOURCE_DIR"' _ "$INST/install.sh")" \
  "an exported SOURCE_DIR is kept"

test_start "install_version_pinned"
if command -v chezmoi >/dev/null 2>&1; then
  mkdir -p "$SANDBOX/cz"
  : >"$SANDBOX/cz/chezmoi.toml"
  want="v$(env -i HOME="$SANDBOX/cz" PATH="$PATH" chezmoi --config "$SANDBOX/cz/chezmoi.toml" \
    --source "$REPO_ROOT/defaults" --persistent-state "$SANDBOX/cz/state" \
    execute-template '{{ .dotfiles_version }}')"
else
  want="v0.2.523"
fi
got="$(env -i HOME="$SANDBOX/h9" PATH="$SYS" "$BASH" --norc --noprofile -c 'source "$1"; show_help' _ "$INST/install.sh" |
  sed -n 's/.*(default: \(v[^)]*\)).*/\1/p')"
assert_equals "$want" "$got" "the default pinned version matches dotfiles_version in .chezmoidata.toml"

echo ""
echo "Wave 1 install.sh chezmoi installation tests completed."
print_summary
