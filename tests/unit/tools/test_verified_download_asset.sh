#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# The verification failures in lib/dot/verified-download.sh.
#
# download_verified_asset only reports anything interesting when the network
# or the toolchain misbehaves: the asset download fails after the manifest
# succeeded, or there is no SHA-256 tool at all. Neither can happen on a
# healthy machine, so a curl stub decides which request fails and the PATH
# decides which digest tools exist.
#
# No case reaches the network: the stub answers from local files.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"
source "$SCRIPT_DIR/../../framework/module_fixture.sh"

VD_LIB="$REPO_ROOT/lib/dot/verified-download.sh"

WORK="$(mktemp -d -t vdl.XXXXXX)"
cov_setup_sandbox
trap 'rm -rf "$WORK"; cov_teardown_sandbox' EXIT

mkdir -p "$WORK/stubs" "$WORK/out"
# shasum but no sha256sum: the second arm of the digest helper, which a
# machine with GNU coreutils installed would never take.
dot_fixture_basebin "$WORK/shasum-only" shasum
dot_fixture_basebin "$WORK/no-digest"
rm -f "$WORK/no-digest/shasum" "$WORK/no-digest/sha256sum"

printf 'release payload\n' >"$WORK/payload.bin"
PAYLOAD_SHA="$(shasum -a 256 "$WORK/payload.bin" | awk '{print $1}')"
printf '%s  asset.tar.gz\n' "$PAYLOAD_SHA" >"$WORK/manifest.txt"
printf '%s  asset.tar.gz\n' "0000000000000000000000000000000000000000000000000000000000000000" \
  >"$WORK/manifest-wrong.txt"

# curl stub: answers the checksum URL from a local manifest and the asset URL
# from a local payload, or refuses the asset when VD_ASSET_FAILS is set.
cat >"$WORK/stubs/curl" <<STUB
#!/bin/sh
out=""
url=""
while [ \$# -gt 0 ]; do
  case "\$1" in
    -o) out="\$2"; shift 2 ;;
    https://*) url="\$1"; shift ;;
    *) shift ;;
  esac
done
case "\$url" in
  *checksums*)
    cat "\${VD_MANIFEST:-$WORK/manifest.txt}" >"\$out"
    ;;
  *)
    [ -n "\${VD_ASSET_FAILS:-}" ] && exit 22
    cat "$WORK/payload.bin" >"\$out"
    ;;
esac
exit 0
STUB
chmod +x "$WORK/stubs/curl"

VD_OUT=""
VD_RC=0
# vd_run <tool-dir> — call download_verified_asset with the given PATH.
vd_run() {
  local tools="$1"
  shift
  VD_RC=0
  VD_OUT="$(
    PATH="$WORK/stubs:$tools" "${BASH:-bash}" -c '
      set -uo pipefail
      source "$1"
      shift
      rc=0
      download_verified_asset \
        "https://example.invalid/asset.tar.gz" \
        "https://example.invalid/checksums.txt" \
        "asset.tar.gz" \
        "$1" || rc=$?
      printf "VD_RC=%s\n" "$rc"
    ' _ "$VD_LIB" "$WORK/out/asset.tar.gz" 2>&1 </dev/null
  )" || VD_RC=$?
}

# ── 1. A verified download that succeeds, using shasum ─────────────────────
test_start "verified_download_accepts_a_matching_asset"
rm -f "$WORK/out/asset.tar.gz"
vd_run "$WORK/shasum-only"
assert_contains "VD_RC=0" "$VD_OUT" "a matching checksum should succeed"
assert_file_exists "$WORK/out/asset.tar.gz" "the asset should be left in place"

# ── 2. The asset download fails after the manifest succeeded ───────────────
test_start "verified_download_reports_a_failed_asset_fetch"
rm -f "$WORK/out/asset.tar.gz"
VD_ASSET_FAILS=1 vd_run "$WORK/shasum-only"
assert_contains "VD_RC=1" "$VD_OUT" "a failed asset fetch should return 1"
assert_file_not_exists "$WORK/out/asset.tar.gz" \
  "a half-finished download must not be left behind"

# ── 3. No SHA-256 tool at all ──────────────────────────────────────────────
test_start "verified_download_refuses_without_a_digest_tool"
rm -f "$WORK/out/asset.tar.gz"
vd_run "$WORK/no-digest"
assert_contains "VD_RC=1" "$VD_OUT" "no digest tool should return 1"
assert_contains "SHA-256 verifier not found" "$VD_OUT" \
  "the failure should name what is missing"
assert_file_not_exists "$WORK/out/asset.tar.gz" \
  "an unverifiable download must not be left behind"

# ── 4. A checksum that does not match ──────────────────────────────────────
test_start "verified_download_rejects_a_mismatched_checksum"
rm -f "$WORK/out/asset.tar.gz"
VD_MANIFEST="$WORK/manifest-wrong.txt" vd_run "$WORK/shasum-only"
assert_contains "VD_RC=1" "$VD_OUT" "a mismatched checksum should return 1"
assert_file_not_exists "$WORK/out/asset.tar.gz" \
  "a mismatched download must not be left behind"

print_summary
