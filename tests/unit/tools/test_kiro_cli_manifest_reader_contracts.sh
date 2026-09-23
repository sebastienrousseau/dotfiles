#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# The kiro-cli mise plugin reads the release manifest with jq, or with a
# python3 fallback when jq is absent, and refuses to continue with neither.
# The existing download test always had jq on PATH, so the mutation gate
# found the python3 reader and the no-reader exit unprotected. Pinned
# here, with a PATH that has NO jq:
#   - the python3 reader selects the linux asset named by the manifest
#     (the versioned linux archive is downloaded, verified and extracted)
#   - the python3 reader ignores an entry for another OS even when its
#     file name matches (exit 1, "no single valid entry", nothing
#     extracted)
#   - with neither jq nor python3 the plugin exits 1 with its message and
#     never downloads the archive
# uname/ldd/curl/unzip are stubs and PATH holds only sandboxed wrappers,
# so nothing reaches the network or the real tools' state.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

PLUGIN="$REPO_ROOT/defaults/dot_local/share/mise/plugins/kiro-cli/bin/executable_download"
# The restricted PATH below has no bash, so run the plugin with this
# interpreter by absolute path.
REAL_BASH="${BASH:-$(command -v bash)}"

WORK="$(mktemp -d -t kiro-reader.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/py"

# Real helpers the plugin (and the /bin/sh stubs) need, exposed by name
# only, so `command -v jq` fails no matter what the host has installed.
link_real() {
  local tool real
  for tool in "$@"; do
    real="$(command -v "$tool" 2>/dev/null || true)"
    [[ -n "$real" ]] && ln -s "$real" "$WORK/bin/$tool"
  done
}
link_real grep awk rm cat touch shasum sha256sum

REAL_PYTHON3="$(command -v python3 2>/dev/null || true)"
if [[ -z "$REAL_PYTHON3" ]]; then
  test_start "python3_available"
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: python3 is required to exercise the fallback reader"
  echo ""
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
  exit 1
fi
printf '#!/bin/sh\nexec "%s" "$@"\n' "$REAL_PYTHON3" >"$WORK/py/python3"
chmod +x "$WORK/py/python3"

printf 'kiro archive bytes\n' >"$WORK/archive.zip"
GOOD_SHA="$(shasum -a 256 "$WORK/archive.zip" 2>/dev/null | awk '{print $1}')"
[[ -n "$GOOD_SHA" ]] || GOOD_SHA="$(sha256sum "$WORK/archive.zip" | awk '{print $1}')"

printf '#!/bin/sh\n[ "$1" = -m ] && echo x86_64 || echo Linux\n' >"$WORK/bin/uname"
printf '#!/bin/sh\necho "linux-vdso.so.1"\n' >"$WORK/bin/ldd"
cat >"$WORK/bin/curl" <<STUB
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
printf '#!/bin/sh\ntouch "%s"\n' "$WORK/unzipped" >"$WORK/bin/unzip"
chmod +x "$WORK/bin/uname" "$WORK/bin/ldd" "$WORK/bin/curl" "$WORK/bin/unzip"

kiro_run() { # kiro_run <PATH>
  rm -rf "$WORK/dl" "$WORK/unzipped" "$WORK/urls.log"
  mkdir -p "$WORK/dl"
  KIRO_OUT="$(ASDF_DOWNLOAD_PATH="$WORK/dl" PATH="$1" "$REAL_BASH" "$PLUGIN" 2>&1 </dev/null)"
  KIRO_RC=$?
}

test_start "kiro_python_reader_selects_linux_asset"
cat >"$WORK/manifest.json" <<JSON
{"version": "9.9.9", "packages": [
  {"os": "darwin", "download": "9.9.9/kirocli-x86_64-darwin.zip", "sha256": "$GOOD_SHA"},
  {"os": "linux", "download": "9.9.9/kirocli-x86_64-linux.zip", "sha256": "$GOOD_SHA"},
  {"os": "linux", "download": "9.9.9/kirocli-x86_64-linux-musl.zip", "sha256": "$GOOD_SHA"}
]}
JSON
kiro_run "$WORK/bin:$WORK/py"
assert_equals "0" "$KIRO_RC" "the linux entry is found without jq"
assert_contains "/9.9.9/kirocli-x86_64-linux.zip" "$(cat "$WORK/urls.log" 2>/dev/null)" \
  "the versioned linux archive is downloaded"
assert_file_exists "$WORK/unzipped" "the verified archive is extracted"

test_start "kiro_python_reader_ignores_other_os_with_same_file_name"
cat >"$WORK/manifest.json" <<JSON
{"version": "9.9.9", "packages": [
  {"os": "darwin", "download": "9.9.9/kirocli-x86_64-linux.zip", "sha256": "$GOOD_SHA"}
]}
JSON
kiro_run "$WORK/bin:$WORK/py"
assert_equals "1" "$KIRO_RC" "an entry for another OS is not a linux asset"
assert_contains "Kiro release manifest has no single valid entry for kirocli-x86_64-linux.zip" \
  "$KIRO_OUT" "the refusal names the expected file"
assert_file_not_exists "$WORK/unzipped" "nothing is extracted"

test_start "kiro_without_jq_or_python3_exits_1"
kiro_run "$WORK/bin"
assert_equals "1" "$KIRO_RC" "no manifest reader is a hard failure"
assert_contains "Need jq or python3 to read the Kiro release manifest." "$KIRO_OUT" \
  "the failure says what is missing"
assert_equals "https://desktop-release.q.us-east-1.amazonaws.com/latest/manifest.json" \
  "$(cat "$WORK/urls.log" 2>/dev/null)" "only the manifest was fetched, never the archive"
assert_file_not_exists "$WORK/unzipped" "nothing is extracted"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
