#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# bin/dot-bootstrap runs the Nix installer as root (--daemon). The script it
# downloads must match a pinned SHA-256 before anything executes it.
#
# No case reaches the network: a curl stub serves a tampered installer.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

BOOTSTRAP="$REPO_ROOT/bin/dot-bootstrap"
MANIFEST="$REPO_ROOT/security/remote-installers.sha256"

WORK="$(mktemp -d -t dot-bootstrap.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/stubs" "$WORK/home"

# curl stub: every download returns an installer that records it was run.
cat >"$WORK/stubs/curl" <<STUB
#!/bin/sh
out=""
while [ \$# -gt 0 ]; do
  case "\$1" in
    -o) out="\$2"; shift 2 ;;
    *) shift ;;
  esac
done
printf '#!/bin/sh\ntouch "%s"\nexit 1\n' "$WORK/installer-ran" >"\$out"
exit 0
STUB
chmod +x "$WORK/stubs/curl"

test_start "bootstrap_refuses_tampered_nix_installer"
out="$(HOME="$WORK/home" PATH="$WORK/stubs:/usr/bin:/bin" bash "$BOOTSTRAP" 2>&1 </dev/null)"
rc=$?
assert_not_equals "0" "$rc" "a tampered installer should abort the bootstrap"

test_start "bootstrap_never_executes_unverified_installer"
assert_file_not_exists "$WORK/installer-ran" "the tampered installer must not run"

test_start "bootstrap_reports_checksum_mismatch"
assert_contains "checksum" "$out" "the failure should name the checksum"

# The pinned URL/hash in the script must be the reviewed manifest entry.
test_start "bootstrap_pin_matches_manifest"
url="$(sed -n 's/^NIX_INSTALLER_URL="\(.*\)"$/\1/p' "$BOOTSTRAP")"
sha="$(sed -n 's/^NIX_INSTALLER_SHA256="\(.*\)"$/\1/p' "$BOOTSTRAP")"
assert_equals "$sha  $url" "$(grep -F "  $url" "$MANIFEST" 2>/dev/null)" \
  "script pin and security/remote-installers.sha256 agree"

test_start "bootstrap_pin_is_versioned_https"
if [[ "$url" =~ ^https://releases\.nixos\.org/nix/nix-[0-9]+\.[0-9]+\.[0-9]+/install$ && "$sha" =~ ^[0-9a-f]{64}$ ]]; then
  assert_exit_code 0 "true"
else
  assert_exit_code 0 "false  # unversioned or malformed pin: $url $sha"
fi

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
