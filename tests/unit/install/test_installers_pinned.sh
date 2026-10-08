#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016,SC2034
# install/lib/installers.sh verifies release downloads against SHA-256 values
# pinned in versions.env. The release's own checksum file comes from the same
# place as the archive, so it is only a cross-check: a replaced release whose
# checksum file matches its tampered archive is refused. Asset URLs resolve
# by exact asset name, so a link in the release notes cannot stand in.
#
# No case reaches the network: curl serves a fixture release.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

LIB_DIR="$REPO_ROOT/install/lib"

WORK="$(mktemp -d -t installers-pinned.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
REL="$WORK/release"
STUBS="$WORK/stubs"
mkdir -p "$REL" "$STUBS"

sha_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# curl: API URLs print $REL/release.json; `-o dest url` copies the release
# file named by the URL's last part (exit 22 when there is none).
cat >"$STUBS/curl" <<EOF
#!/bin/sh
out=''; url=''
while [ \$# -gt 0 ]; do case "\$1" in -o) out="\$2"; shift ;; https://*) url="\$1" ;; esac; shift; done
case "\$url" in https://api.github.com/*) cat "$REL/release.json"; exit 0 ;; esac
[ -f "$REL/\${url##*/}" ] || exit 22
cp "$REL/\${url##*/}" "\$out"
EOF
chmod +x "$STUBS/curl"
printf '#!/bin/sh\necho "${FAKE_ARCH:-x86_64}"\n' >"$STUBS/uname"
chmod +x "$STUBS/uname"

# lib <snippet> [VAR=value ...]: run <snippet> with the libraries loaded;
# prints its output, then rc=<status>.
lib() {
  local snippet="$1" rc=0 out
  shift
  out="$(env PATH="$STUBS:$PATH" "$@" bash -c 'source "$1/logging.sh"; source "$1/installers.sh"
    '"$snippet" _ "$LIB_DIR" 2>&1)" || rc=$?
  printf '%s\nrc=%s\n' "$out" "$rc"
}
rc_of() { sed -n 's/^rc=//p' <<<"$1" | tail -n 1; }

# A tampered archive; its release checksum file agrees with it.
printf 'tampered\n' >"$REL/tool-x86_64.tar.gz"
TAMPERED_SHA="$(sha_of "$REL/tool-x86_64.tar.gz")"
printf '%s  tool-x86_64.tar.gz\n' "$TAMPERED_SHA" >"$REL/tool-x86_64.tar.gz.sha256"
PINNED_SHA="$(printf '%064d' 1)"

test_start "tampered_release_with_matching_checksum_refused"
r="$(lib 'download_and_verify_sha256 https://x.invalid/tool-x86_64.tar.gz https://x.invalid/tool-x86_64.tar.gz.sha256 "$D/out" "$PIN"' \
  D="$WORK" PIN="$PINNED_SHA")"
assert_equals "1" "$(rc_of "$r")" "an archive matching only its release checksum file is refused"

test_start "matching_pin_accepted"
r="$(lib 'download_and_verify_sha256 https://x.invalid/tool-x86_64.tar.gz https://x.invalid/tool-x86_64.tar.gz.sha256 "$D/out2" "$PIN" && echo verified' \
  D="$WORK" PIN="$TAMPERED_SHA")"
assert_equals "0|yes" "$(rc_of "$r")|$(grep -qx verified <<<"$r" && echo yes || echo no)" \
  "an archive matching the pin is accepted"

test_start "pin_without_checksum_file_accepted"
r="$(lib 'download_and_verify_sha256 https://x.invalid/tool-x86_64.tar.gz "" "$D/out3" "$PIN"' \
  D="$WORK" PIN="$TAMPERED_SHA")"
assert_equals "0" "$(rc_of "$r")" "a release with no checksum file installs on the pin alone"

test_start "checksum_file_disagreeing_with_pin_refused"
printf '%s  tool-x86_64.tar.gz\n' "$PINNED_SHA" >"$REL/tool-x86_64.tar.gz.sha256"
r="$(lib 'download_and_verify_sha256 https://x.invalid/tool-x86_64.tar.gz https://x.invalid/tool-x86_64.tar.gz.sha256 "$D/out4" "$PIN"' \
  D="$WORK" PIN="$TAMPERED_SHA")"
assert_equals "1" "$(rc_of "$r")" "a release checksum file disagreeing with the pin stops the install"

test_start "bare_hash_checksum_file_disagreeing_refused"
printf '%s\n' "$PINNED_SHA" >"$REL/tool-x86_64.tar.gz.sha256"
r="$(lib 'download_and_verify_sha256 https://x.invalid/tool-x86_64.tar.gz https://x.invalid/tool-x86_64.tar.gz.sha256 "$D/out6" "$PIN"' \
  D="$WORK" PIN="$TAMPERED_SHA")"
assert_equals "1" "$(rc_of "$r")" "a single-hash checksum file that disagrees with the pin stops the install"

test_start "checksum_line_for_other_asset_ignored"
printf '%s  other-asset.tar.gz\n' "$PINNED_SHA" >"$REL/tool-x86_64.tar.gz.sha256"
r="$(lib 'download_and_verify_sha256 https://x.invalid/tool-x86_64.tar.gz https://x.invalid/tool-x86_64.tar.gz.sha256 "$D/out7" "$PIN"' \
  D="$WORK" PIN="$TAMPERED_SHA")"
assert_equals "0" "$(rc_of "$r")" "a checksum line naming another asset is not a cross-check of this one"

test_start "malformed_pin_refused"
r="$(lib 'download_and_verify_sha256 https://x.invalid/tool-x86_64.tar.gz "" "$D/out8" "$PIN"' \
  D="$WORK" PIN="x$TAMPERED_SHA")"
assert_equals "1|no" "$(rc_of "$r")|$([[ -e "$WORK/out8" ]] && echo yes || echo no)" \
  "a pin that is not exactly 64 hex digits is refused before any download"

test_start "missing_pin_refused"
r="$(lib 'download_and_verify_sha256 https://x.invalid/tool-x86_64.tar.gz "" "$D/out5" ""' D="$WORK")"
assert_equals "1|no" "$(rc_of "$r")|$([[ -e "$WORK/out5" ]] && echo yes || echo no)" \
  "with no pin nothing is downloaded"

# A tarball install end to end, then the same with a tampered archive.
mkdir -p "$WORK/pkg"
printf '#!/bin/sh\necho real-tool\n' >"$WORK/pkg/tool"
chmod +x "$WORK/pkg/tool"
tar -czf "$REL/tool-real.tar.gz" -C "$WORK/pkg" tool
REAL_SHA="$(sha_of "$REL/tool-real.tar.gz")"

test_start "install_from_tarball_pinned"
r="$(lib 'install_from_tarball https://x.invalid/tool-real.tar.gz "" tool "$D/bin1" "$PIN"' D="$WORK" PIN="$REAL_SHA")"
assert_equals "0|real-tool" "$(rc_of "$r")|$("$WORK/bin1/tool" 2>/dev/null)" "a pinned tarball installs its binary"

test_start "install_from_tarball_checksums_refuses_tamper"
mkdir -p "$WORK/evil"
printf '#!/bin/sh\necho evil-tool\n' >"$WORK/evil/tool"
chmod +x "$WORK/evil/tool"
tar -czf "$REL/tool-evil.tar.gz" -C "$WORK/evil" tool
printf '%s  tool-evil.tar.gz\n' "$(sha_of "$REL/tool-evil.tar.gz")" >"$REL/checksums.txt"
r="$(lib 'install_from_tarball_checksums https://x.invalid/tool-evil.tar.gz https://x.invalid/checksums.txt tool "$D/bin2" "$PIN"' \
  D="$WORK" PIN="$REAL_SHA")"
assert_equals "1|absent" "$(rc_of "$r")|$([[ -e "$WORK/bin2/tool" ]] && echo present || echo absent)" \
  "a multi-file checksums.txt agreeing with a tampered archive does not let it install"

if command -v python3 >/dev/null 2>&1 && command -v unzip >/dev/null 2>&1 && command -v zipinfo >/dev/null 2>&1; then
  python3 -c 'import sys, zipfile
z = zipfile.ZipFile(sys.argv[1], "w")
info = zipfile.ZipInfo("tool")
info.external_attr = 0o100755 << 16
z.writestr(info, open(sys.argv[2]).read())
z.close()' "$REL/tool.zip" "$WORK/pkg/tool"
  ZIP_SHA="$(sha_of "$REL/tool.zip")"

  test_start "install_from_zip_pinned"
  r="$(lib 'install_from_zip https://x.invalid/tool.zip "" "$D/bin3" "$PIN" tool' D="$WORK" PIN="$ZIP_SHA")"
  assert_equals "0|real-tool" "$(rc_of "$r")|$("$WORK/bin3/tool" 2>/dev/null)" "a pinned zip installs its binary"

  test_start "install_from_zip_wrong_pin_refused"
  r="$(lib 'install_from_zip https://x.invalid/tool.zip "" "$D/bin4" "$PIN" tool' D="$WORK" PIN="$REAL_SHA")"
  assert_equals "1|absent" "$(rc_of "$r")|$([[ -e "$WORK/bin4/tool" ]] && echo present || echo absent)" \
    "a zip that does not match its pin is not installed"
fi

# Release JSON whose notes come first and carry a look-alike link.
cat >"$REL/release.json" <<'JSON'
{"tag_name": "v1.0.0",
 "body": "Mirror: https://evil.invalid/download/tool-x86_64-unknown-linux-gnu.tar.gz",
 "assets": [
  {"name": "tool-server-x86_64-unknown-linux-gnu.tar.gz",
   "browser_download_url": "https://github.com/o/r/releases/download/v1.0.0/tool-server-x86_64-unknown-linux-gnu.tar.gz"},
  {"name": "tool-x86_64-unknown-linux-gnu.tar.gz",
   "browser_download_url": "https://github.com/o/r/releases/download/v1.0.0/tool-x86_64-unknown-linux-gnu.tar.gz"}
 ]}
JSON

test_start "asset_url_ignores_release_notes"
r="$(lib 'github_asset_url o/r tool-x86_64-unknown-linux-gnu.tar.gz v1.0.0')"
assert_equals "https://github.com/o/r/releases/download/v1.0.0/tool-x86_64-unknown-linux-gnu.tar.gz" \
  "$(head -n 1 <<<"$r")" "the URL is the asset's own, not a link from the notes or a longer name"

test_start "asset_url_unknown_name_falls_back_to_release_path"
r="$(lib 'github_asset_url o/r tool-aarch64-unknown-linux-gnu.tar.gz v1.0.0')"
assert_equals "https://github.com/o/r/releases/download/v1.0.0/tool-aarch64-unknown-linux-gnu.tar.gz" \
  "$(head -n 1 <<<"$r")" "an asset missing from the JSON resolves to its release download path"

# Per-architecture pins from versions.env variables.
test_start "pinned_sha256_x86_64"
r="$(lib 'pinned_sha256 TOOL' TOOL_SHA256_X86_64=aaa TOOL_SHA256_AARCH64=bbb FAKE_ARCH=x86_64)"
assert_equals "aaa" "$(head -n 1 <<<"$r")" "x86_64 reads <TOOL>_SHA256_X86_64"

test_start "pinned_sha256_aarch64"
r="$(lib 'pinned_sha256 TOOL' TOOL_SHA256_X86_64=aaa TOOL_SHA256_AARCH64=bbb FAKE_ARCH=arm64)"
assert_equals "bbb" "$(head -n 1 <<<"$r")" "arm64 reads <TOOL>_SHA256_AARCH64"

# apt_keyring_holds_only: exactly one primary key, the pinned one.
if command -v gpg >/dev/null 2>&1; then
  # A short home: macOS's long $TMPDIR pushes gpg-agent's socket path past the
  # Unix socket limit, and key generation then fails without saying why.
  GNUPGHOME="$(mktemp -d /tmp/ip-gpg.XXXXXX)"
  export GNUPGHOME
  chmod 700 "$GNUPGHOME"
  trap 'gpgconf --kill gpg-agent >/dev/null 2>&1 || true; rm -rf "$GNUPGHOME" "$WORK"' EXIT
  gen_key() {
    gpg --batch --quiet --passphrase '' --quick-gen-key "$1" ed25519 sign never 2>/dev/null
    gpg --with-colons --list-keys "$1" | awk -F: '/^fpr:/ { print $10; exit }'
  }
  PIN_FPR="$(gen_key 'Pinned <pinned@example.invalid>')"
  EVIL_FPR="$(gen_key 'Evil <evil@example.invalid>')"
  gpg --export "$PIN_FPR" >"$WORK/pinned.gpg"
  gpg --export "$PIN_FPR" "$EVIL_FPR" >"$WORK/both.gpg"
  gpg --export "$EVIL_FPR" >"$WORK/evil.gpg"
  keyring_rc() {
    local r
    r="$(lib 'apt_keyring_holds_only "$K" "$F"' K="$1" F="$PIN_FPR" GNUPGHOME="$GNUPGHOME")"
    rc_of "$r"
  }
fi
if command -v gpg >/dev/null 2>&1 && [[ -z "${PIN_FPR:-}" || -z "${EVIL_FPR:-}" ]]; then
  test_start "apt_keyring_fixture_keys"
  printf '  %s (skipped: gpg could not generate the fixture keys here)\n' "$CURRENT_TEST"
elif command -v gpg >/dev/null 2>&1; then
  test_start "apt_keyring_pinned_key_alone_trusted"
  assert_equals "0" "$(keyring_rc "$WORK/pinned.gpg")" "a keyring with only the pinned key passes"

  test_start "apt_keyring_with_extra_key_refused"
  assert_equals "1" "$(keyring_rc "$WORK/both.gpg")" "a second primary key after the pinned one is refused"

  test_start "apt_keyring_with_other_key_refused"
  assert_equals "1" "$(keyring_rc "$WORK/evil.gpg")" "a keyring holding another key is refused"
fi

# The shipped versions.env pins every tool for both architectures.
test_start "versions_env_pins_complete"
missing="$(env -i PATH="$PATH" bash -c '. "$1"
  for t in STARSHIP ZOXIDE NEOVIM LAZYGIT ATUIN ZELLIJ UV TOPGRADE MISE YAZI AICHAT MODS; do
    for a in X86_64 AARCH64; do
      v="${t}_SHA256_$a"
      [[ "${!v:-}" =~ ^[0-9a-f]{64}$ ]] || printf "%s " "$v"
    done
  done' _ "$REPO_ROOT/defaults/dot_config/dotfiles/versions.env")"
assert_equals "" "$missing" "every provisioned tool has a SHA-256 per architecture"

print_summary
