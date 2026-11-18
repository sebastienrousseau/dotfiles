#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# install.sh _chezmoi_fetch_install checks the pinned SHA-256 with sha256sum
# when the machine has it, and with `shasum -a 256` otherwise. Each case
# hides the other tool, so picking the wrong one fails the install.
#
# install.sh is sourced, never run: curl serves a local tarball holding a
# stand-in chezmoi, and the served checksums file is unavailable.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/module_fixture.sh"

SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
ASSET="chezmoi_9.9.9_linux_amd64.tar.gz"

mkdir -p "$SANDBOX/pkg" "$SANDBOX/serve"
printf '#!/bin/sh\necho stand-in\n' >"$SANDBOX/pkg/chezmoi"
tar -czf "$SANDBOX/serve/$ASSET" -C "$SANDBOX/pkg" chezmoi
if command -v sha256sum >/dev/null 2>&1; then
  PIN="$(sha256sum "$SANDBOX/serve/$ASSET" | awk '{print $1}')"
else
  PIN="$(shasum -a 256 "$SANDBOX/serve/$ASSET" | awk '{print $1}')"
fi

# A curl that serves the asset by its basename and 404s anything else.
mkdir -p "$SANDBOX/stubs"
cat >"$SANDBOX/stubs/curl" <<EOF
#!/bin/sh
out="" url=""
while [ \$# -gt 0 ]; do
  case "\$1" in -o) out="\$2"; shift ;; https://*) url="\$1" ;; esac
  shift
done
[ -f "$SANDBOX/serve/\${url##*/}" ] || exit 22
cp "$SANDBOX/serve/\${url##*/}" "\$out"
EOF
chmod +x "$SANDBOX/stubs/curl"

# fetch_with TOOL PIN: _chezmoi_fetch_install with only TOOL as the SHA-256
# checker on PATH; prints "rc=<status> installed=<yes|no>".
fetch_with() {
  local bin="$SANDBOX/bin-$1" dest="$SANDBOX/dest-$1"
  rm -rf "$bin" "$dest" "$SANDBOX/work"
  dot_fixture_basebin "$bin" tar gzip install "$1"
  mkdir -p "$SANDBOX/work"
  env -i HOME="$SANDBOX" PATH="$SANDBOX/stubs:$bin" "$BASH" --norc --noprofile -c '
    source "$1" >/dev/null 2>&1
    rc=0
    _chezmoi_fetch_install "$2" https://example.invalid/dl "$3" checksums.txt "$4" "$5" >/dev/null 2>&1 || rc=$?
    printf "rc=%s installed=%s\n" "$rc" "$([[ -x "$5/chezmoi" ]] && echo yes || echo no)"
  ' _ "$REPO_ROOT/install.sh" "$SANDBOX/work" "$ASSET" "$2" "$dest"
}

for tool in sha256sum shasum; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "SKIP: $tool is not installed"
    continue
  fi
  test_start "fetch_verifies_with_${tool}_alone"
  assert_equals "rc=0 installed=yes" "$(fetch_with "$tool" "$PIN")" \
    "the pinned asset installs with only $tool available"

  test_start "fetch_refuses_a_wrong_pin_with_${tool}"
  assert_equals "rc=1 installed=no" "$(fetch_with "$tool" "$(printf '0%.0s' {1..64})")" \
    "a digest mismatch stops the install"
done

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
