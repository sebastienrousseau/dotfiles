#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Negative + positive tests for tools/ci/install-chezmoi-verified.sh.
# Confirms the SHA256 verification step actually catches a tampered
# tarball (the only thing standing between a user and an arbitrary
# binary if get.chezmoi.io / the GitHub CDN is compromised).
#
# Regression for: GH-858
# Why: a verified installer that silently accepts bad hashes is worse
# than no verification — gives the user false confidence.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
# shellcheck source=../../framework/assertions.sh
source "$REPO_ROOT/tests/framework/assertions.sh"

INSTALLER="$REPO_ROOT/tools/ci/install-chezmoi-verified.sh"

# -----------------------------------------------------------------------------
# Structural
# -----------------------------------------------------------------------------

test_start "installer_exists"
assert_file_exists "$INSTALLER" "verified chezmoi installer should exist"

test_start "installer_uses_pipefail"
assert_file_contains "$INSTALLER" "set -euo pipefail" "installer must enforce strict mode"

test_start "installer_uses_sha256"
# Either shasum -a 256 or sha256sum — accept both.
if grep -Eq 'shasum[[:space:]]+-a[[:space:]]+256|sha256sum' "$INSTALLER"; then
  assert_exit_code 0 "true"
else
  assert_exit_code 0 "false  # installer must use SHA256 verification"
fi

test_start "installer_aborts_on_missing_entry"
assert_file_contains "$INSTALLER" "Checksum entry not found" \
  "installer must abort with a clear error if the checksum line is missing"

# -----------------------------------------------------------------------------
# Negative behavioural test: simulate a tampered tarball and confirm
# the verification step aborts. We mock the network by intercepting
# curl via a PATH override that serves controlled fixtures.
# -----------------------------------------------------------------------------

if ! command -v shasum >/dev/null 2>&1 && ! command -v sha256sum >/dev/null 2>&1; then
  echo "::warning::neither shasum nor sha256sum on PATH; skipping behavioural tests" >&2
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
  exit 0
fi

# Use shasum (BSD) by default, fall back to sha256sum.
sha256_of() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# 1. Fake tarball + checksum.
fake_asset="$tmp/chezmoi_999.999.999_linux_amd64.tar.gz"
echo "this is not really chezmoi" > "$fake_asset"
real_sha=$(sha256_of "$fake_asset")

# 2. Build a fake mirror server. Use Python http.server in a subshell.
mirror_dir="$tmp/mirror"
mkdir -p "$mirror_dir"
cp "$fake_asset" "$mirror_dir/"

# Negative case: checksum file with the WRONG hash.
wrong_sha="0000000000000000000000000000000000000000000000000000000000000000"
printf '%s  chezmoi_999.999.999_linux_amd64.tar.gz\n' "$wrong_sha" \
  > "$mirror_dir/chezmoi_999.999.999_checksums.txt"

# Stub `uname` so the installer always resolves to linux/amd64 regardless
# of the host. Lets the same fixture asset work on macOS dev boxes and CI.
uname_shim="$tmp/uname"
cat > "$uname_shim" <<'SH'
#!/usr/bin/env bash
case "${1:-}" in
  -s) echo "Linux" ;;
  -m) echo "x86_64" ;;
  *)  echo "Linux x86_64" ;;
esac
SH
chmod +x "$uname_shim"

# Curl-shim that serves files from the mirror directory.
curl_shim="$tmp/curl"
cat > "$curl_shim" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
# Minimal curl-compat: -fsSL -o <dst> <url> — extract the basename
# from the URL and serve from $MIRROR_DIR.
out=""
url=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    -fsSL|-f|-s|-S|-L) shift ;;
    *) url="$1"; shift ;;
  esac
done
asset="${url##*/}"
if [[ -z "$out" ]]; then
  cat "$MIRROR_DIR/$asset"
else
  if [[ ! -f "$MIRROR_DIR/$asset" ]]; then
    echo "curl-shim: no fixture for $asset" >&2
    exit 22  # curl HTTP error code
  fi
  cp "$MIRROR_DIR/$asset" "$out"
fi
SH
chmod +x "$curl_shim"

# 3. Run the installer with the curl-shim on PATH. Force a Linux
#    arch so the asset name matches what the shim serves regardless
#    of the host OS.
test_start "verification_rejects_wrong_hash"
set +e
MIRROR_DIR="$mirror_dir" \
  PATH="$tmp:$PATH" \
  bash "$INSTALLER" "999.999.999" "$tmp/install-target" >"$tmp/log.out" 2>&1 < /dev/null
rc=$?
set -e

if [[ $rc -ne 0 ]] && grep -qi "checksum\|verification\|sha" "$tmp/log.out"; then
  assert_exit_code 0 "true"
else
  echo "Installer should have failed with a checksum error; rc=$rc" >&2
  cat "$tmp/log.out" >&2 || true
  assert_exit_code 0 "false  # installer accepted the wrong-hash tarball"
fi

# 4. Positive case: same fixture but with the CORRECT hash.
printf '%s  chezmoi_999.999.999_linux_amd64.tar.gz\n' "$real_sha" \
  > "$mirror_dir/chezmoi_999.999.999_checksums.txt"

test_start "verification_accepts_correct_hash"
set +e
MIRROR_DIR="$mirror_dir" \
  PATH="$tmp:$PATH" \
  bash "$INSTALLER" "999.999.999" "$tmp/install-target" >"$tmp/log_ok.out" 2>&1 < /dev/null
rc=$?
set -e

# The installer will fail later (tar extract on a non-tarball), but
# the checksum step itself should have passed. We grep the log for
# evidence we got past the checksum gate.
if grep -qi "checksum entry not found\|FAILED open\|computed.*does not match" "$tmp/log_ok.out"; then
  echo "Checksum step rejected a correct hash. rc=$rc, log:" >&2
  cat "$tmp/log_ok.out" >&2 || true
  assert_exit_code 0 "false"
else
  assert_exit_code 0 "true"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
