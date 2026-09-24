#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# The kiro-cli mise plugin (Linux path) must install only the versioned
# archive named in the release manifest, and only if its SHA-256 matches.
#
# No case reaches the network: uname/ldd/curl/unzip are stubs.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

PLUGIN="$REPO_ROOT/defaults/dot_local/share/mise/plugins/kiro-cli/bin/executable_download"

WORK="$(mktemp -d -t kiro.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/stubs"

printf 'kiro archive bytes\n' >"$WORK/archive.zip"
GOOD_SHA="$(shasum -a 256 "$WORK/archive.zip" 2>/dev/null | awk '{print $1}')"
[[ -n "$GOOD_SHA" ]] || GOOD_SHA="$(sha256sum "$WORK/archive.zip" | awk '{print $1}')"

write_manifest() { # sha
  cat >"$WORK/manifest.json" <<JSON
{"version": "9.9.9", "packages": [
  {"os": "linux", "download": "9.9.9/kirocli-x86_64-linux.zip", "sha256": "$1"},
  {"os": "linux", "download": "9.9.9/kirocli-x86_64-linux-musl.zip", "sha256": "$1"}
]}
JSON
}

printf '#!/bin/sh\n[ "$1" = -m ] && echo x86_64 || echo Linux\n' >"$WORK/stubs/uname"
printf '#!/bin/sh\necho "linux-vdso.so.1"\n' >"$WORK/stubs/ldd"
cat >"$WORK/stubs/curl" <<STUB
#!/bin/sh
out="" url=""
while [ \$# -gt 0 ]; do
  case "\$1" in
    -o) out="\$2"; shift 2 ;;
    https://*) url="\$1"; shift ;;
    *) shift ;;
  esac
done
echo "\$url" >>"$WORK/urls.log"
case "\$url" in
  */manifest.json) cat "$WORK/manifest.json" >"\$out" ;;
  *) cat "$WORK/archive.zip" >"\$out" ;;
esac
STUB
printf '#!/bin/sh\ntouch "%s"\n' "$WORK/unzipped" >"$WORK/stubs/unzip"
chmod +x "$WORK/stubs/"*

kiro_run() {
  rm -rf "$WORK/dl" "$WORK/unzipped" "$WORK/urls.log"
  mkdir -p "$WORK/dl"
  KIRO_OUT="$(ASDF_DOWNLOAD_PATH="$WORK/dl" PATH="$WORK/stubs:/usr/bin:/bin" \
    bash "$PLUGIN" 2>&1 </dev/null)"
  KIRO_RC=$?
}

test_start "kiro_rejects_mismatched_archive"
write_manifest "0000000000000000000000000000000000000000000000000000000000000000"
kiro_run
assert_not_equals "0" "$KIRO_RC" "a checksum mismatch should fail"
test_start "kiro_mismatch_never_unzips"
assert_file_not_exists "$WORK/unzipped" "an unverified archive is never extracted"
test_start "kiro_mismatch_removes_archive"
assert_file_not_exists "$WORK/dl/kiro-cli.zip" "the unverified archive is removed"

test_start "kiro_accepts_matching_archive"
write_manifest "$GOOD_SHA"
kiro_run
assert_equals "0" "$KIRO_RC" "a matching archive installs"
test_start "kiro_match_unzips"
assert_file_exists "$WORK/unzipped" "the verified archive is extracted"
test_start "kiro_downloads_versioned_path"
assert_contains "/9.9.9/kirocli-x86_64-linux.zip" "$(cat "$WORK/urls.log" 2>/dev/null)" \
  "the archive comes from the versioned path in the manifest, not latest/"

test_start "kiro_rejects_missing_entry"
printf '{"packages": []}\n' >"$WORK/manifest.json"
kiro_run
assert_not_equals "0" "$KIRO_RC" "no manifest entry should fail"
test_start "kiro_missing_entry_never_unzips"
assert_file_not_exists "$WORK/unzipped" "nothing is extracted without an entry"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
