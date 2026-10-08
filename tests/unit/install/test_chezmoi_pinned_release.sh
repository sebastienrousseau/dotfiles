#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016,SC2034
# tools/ci/install-chezmoi-verified.sh trusts a SHA-256 pinned in the repo,
# not the checksums file shipped next to the archive: a replaced release
# carries a checksums file that matches its own tampered archive. Windows
# (Git Bash) goes through the same pinned path instead of get.chezmoi.io.
#
# No case reaches the network: curl serves files from a fixture release.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

INSTALLER="$REPO_ROOT/tools/ci/install-chezmoi-verified.sh"

WORK="$(mktemp -d -t chezmoi-pin.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
REL="$WORK/release"
STUBS="$WORK/stubs"
mkdir -p "$REL/pkg" "$STUBS"

sha_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# curl -o <dest> <url>: copy the release file named by the URL's last part;
# record every URL fetched.
cat >"$STUBS/curl" <<EOF
#!/bin/sh
out=''; url=''
while [ \$# -gt 0 ]; do case "\$1" in -o) out="\$2"; shift ;; https://*) url="\$1" ;; esac; shift; done
echo "\$url" >>"$WORK/urls.log"
[ -f "$REL/\${url##*/}" ] || exit 22
cp "$REL/\${url##*/}" "\$out"
EOF
chmod +x "$STUBS/curl"

# set_uname <kernel> <machine>
set_uname() {
  printf '#!/bin/sh\ncase "$1" in -s) echo %s ;; -m) echo %s ;; esac\n' "$1" "$2" >"$STUBS/uname"
  chmod +x "$STUBS/uname"
}

# run_installer <version> <dest> [VAR=value ...]: prints the exit status.
run_installer() {
  local version="$1" dest="$2" rc=0
  shift 2
  : >"$WORK/urls.log"
  env PATH="$STUBS:$PATH" "$@" bash "$INSTALLER" "$version" "$dest" >"$WORK/out.txt" 2>&1 </dev/null || rc=$?
  printf '%s' "$rc"
}

# A tampered linux/amd64 archive for the pinned 2.72.2, with a checksums
# file that agrees with it.
set_uname Linux x86_64
printf '#!/bin/sh\necho tampered-chezmoi\n' >"$REL/pkg/chezmoi"
chmod +x "$REL/pkg/chezmoi"
tar -czf "$REL/chezmoi_2.72.2_linux_amd64.tar.gz" -C "$REL/pkg" chezmoi
printf '%s  chezmoi_2.72.2_linux_amd64.tar.gz\n' "$(sha_of "$REL/chezmoi_2.72.2_linux_amd64.tar.gz")" \
  >"$REL/chezmoi_2.72.2_checksums.txt"

test_start "tampered_release_with_matching_checksums_refused"
rc="$(run_installer 2.72.2 "$WORK/bin1")"
assert_equals "1|absent" "$rc|$([[ -e "$WORK/bin1/chezmoi" ]] && echo present || echo absent)" \
  "an archive matching only its own release checksums file is not installed"

# An unlisted version needs an explicit pin.
cp "$REL/chezmoi_2.72.2_linux_amd64.tar.gz" "$REL/chezmoi_9.9.9_linux_amd64.tar.gz"
GOOD_SHA="$(sha_of "$REL/chezmoi_9.9.9_linux_amd64.tar.gz")"
printf '%s  chezmoi_9.9.9_linux_amd64.tar.gz\n' "$GOOD_SHA" >"$REL/chezmoi_9.9.9_checksums.txt"

test_start "unpinned_version_refused"
rc="$(run_installer 9.9.9 "$WORK/bin2")"
assert_equals "1|absent" "$rc|$([[ -e "$WORK/bin2/chezmoi" ]] && echo present || echo absent)" \
  "a version with no pinned hash is refused, whatever its checksums file says"

test_start "unpinned_version_never_downloaded"
assert_equals "" "$(cat "$WORK/urls.log")" "nothing is fetched before a pin is known"

test_start "explicit_pin_installs"
rc="$(run_installer 9.9.9 "$WORK/bin3" CHEZMOI_SHA256="$GOOD_SHA")"
assert_equals "0|tampered-chezmoi" "$rc|$("$WORK/bin3/chezmoi" 2>/dev/null)" \
  "an archive matching the pin is installed"

test_start "checksums_file_disagreeing_with_pin_refused"
printf '%s  chezmoi_9.9.9_linux_amd64.tar.gz\n' "$(printf '%064d' 7)" >"$REL/chezmoi_9.9.9_checksums.txt"
rc="$(run_installer 9.9.9 "$WORK/bin4" CHEZMOI_SHA256="$GOOD_SHA")"
assert_equals "1|absent" "$rc|$([[ -e "$WORK/bin4/chezmoi" ]] && echo present || echo absent)" \
  "a release checksums file that disagrees with the pin stops the install"

test_start "missing_checksums_file_still_installs_on_pin"
rm -f "$REL/chezmoi_9.9.9_checksums.txt"
rc="$(run_installer 9.9.9 "$WORK/bin5" CHEZMOI_SHA256="$GOOD_SHA")"
assert_equals "0" "$rc" "the pin alone is enough when the cross-check file is absent"

# Windows (Git Bash): the zip release, verified the same way.
if command -v python3 >/dev/null 2>&1 && command -v unzip >/dev/null 2>&1; then
  set_uname MINGW64_NT-10.0-20348 x86_64
  printf 'MZ fake exe\n' >"$REL/pkg/chezmoi.exe"
  python3 -c 'import sys, zipfile
with zipfile.ZipFile(sys.argv[1], "w") as z: z.write(sys.argv[2], "chezmoi.exe")' \
    "$REL/chezmoi_9.9.9_windows_amd64.zip" "$REL/pkg/chezmoi.exe"
  WIN_SHA="$(sha_of "$REL/chezmoi_9.9.9_windows_amd64.zip")"

  test_start "windows_zip_installed_on_pin"
  rc="$(run_installer 9.9.9 "$WORK/bin6" CHEZMOI_SHA256="$WIN_SHA")"
  assert_equals "0|MZ fake exe" "$rc|$(cat "$WORK/bin6/chezmoi.exe" 2>/dev/null)" \
    "Git Bash installs chezmoi.exe from the pinned zip"

  test_start "windows_zip_wrong_pin_refused"
  rc="$(run_installer 9.9.9 "$WORK/bin7" CHEZMOI_SHA256="$GOOD_SHA")"
  assert_equals "1|absent" "$rc|$([[ -e "$WORK/bin7/chezmoi.exe" ]] && echo present || echo absent)" \
    "a zip that does not match the pin is not installed"
else
  echo "SKIP: zip/unzip unavailable; Windows cases not run"
fi

print_summary
