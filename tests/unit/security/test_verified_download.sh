#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

LIB_FILE="$REPO_ROOT/lib/dot/verified-download.sh"
tmp="$(mktemp -d -t dot-verified-download.XXXXXX)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"

cat >"$tmp/bin/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
dest=
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) dest="$2"; shift 2 ;;
    *) shift ;;
  esac
done
cp "$FAKE_INSTALLER_PAYLOAD" "$dest"
SH
chmod +x "$tmp/bin/curl"

payload="$tmp/payload.sh"
printf '#!/usr/bin/env bash\nprintf "verified\\n"\n' >"$payload"
hash="$(shasum -a 256 "$payload" | awk '{print $1}')"
url="https://example.test/install.sh"
manifest="$tmp/installers.sha256"
printf '%s  %s\n' "$hash" "$url" >"$manifest"

export PATH="$tmp/bin:$PATH"
export FAKE_INSTALLER_PAYLOAD="$payload"
export DOTFILES_INSTALLER_MANIFEST="$manifest"
source "$LIB_FILE"

test_start "verified_download_syntax"
if bash -n "$LIB_FILE"; then
  ((TESTS_PASSED++)) || true
else
  ((TESTS_FAILED++)) || true
fi

test_start "verified_download_accepts_matching_hash"
output="$tmp/verified.sh"
if download_verified_script "$url" "$output" 1024 && cmp -s "$payload" "$output"; then
  ((TESTS_PASSED++)) || true
else
  ((TESTS_FAILED++)) || true
fi

test_start "verified_download_rejects_checksum_mismatch"
printf '%064d  %s\n' 0 "$url" >"$manifest"
if download_verified_script "$url" "$tmp/mismatch.sh" 1024 2>/dev/null; then
  ((TESTS_FAILED++)) || true
else
  ((TESTS_PASSED++)) || true
fi

test_start "verified_download_rejects_unpinned_url"
: >"$manifest"
if download_verified_script "$url" "$tmp/unpinned.sh" 1024 2>/dev/null; then
  ((TESTS_FAILED++)) || true
else
  ((TESTS_PASSED++)) || true
fi

test_start "verified_download_rejects_plain_http"
if download_verified_script http://example.test/install.sh "$tmp/http.sh" 1024 2>/dev/null; then
  ((TESTS_FAILED++)) || true
else
  ((TESTS_PASSED++)) || true
fi

test_start "verified_download_rejects_oversize"
printf '%s  %s\n' "$hash" "$url" >"$manifest"
if download_verified_script "$url" "$tmp/large.sh" 8 2>/dev/null; then
  ((TESTS_FAILED++)) || true
else
  ((TESTS_PASSED++)) || true
fi

test_start "verified_download_rejects_non_script"
printf 'not a script\n' >"$payload"
hash="$(shasum -a 256 "$payload" | awk '{print $1}')"
printf '%s  %s\n' "$hash" "$url" >"$manifest"
if download_verified_script "$url" "$tmp/not-script" 1024 2>/dev/null; then
  ((TESTS_FAILED++)) || true
else
  ((TESTS_PASSED++)) || true
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
