#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016,SC2034
# The Nerd Font installers unzip a downloaded archive into the font directory
# with `unzip -o`. A checksum proves only that the release served it: the
# archive must also pass archive_paths_are_safe (no symlinks, no paths that
# leave the directory) before anything is extracted, and a refused archive
# must fail the run instead of being recorded as installed.
#
# No case reaches the network: curl serves a fixture release.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

FONTS_SCRIPT="$REPO_ROOT/install/provision/run_onchange_50-install-fonts.sh"

if ! command -v python3 >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1 ||
  ! command -v zipinfo >/dev/null 2>&1; then
  echo "SKIP: python3, unzip and zipinfo are needed to build and inspect zips"
  echo "RESULTS:0:0:0"
  exit 0
fi

WORK="$(mktemp -d -t fonts-safety.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
REL="$WORK/release"
STUBS="$WORK/stubs"
mkdir -p "$REL" "$STUBS"

cat >"$STUBS/curl" <<EOF
#!/bin/sh
out=''; url=''
while [ \$# -gt 0 ]; do case "\$1" in -o) out="\$2"; shift ;; https://*) url="\$1" ;; esac; shift; done
[ -f "$REL/\${url##*/}" ] || exit 22
cp "$REL/\${url##*/}" "\$out"
EOF
printf '#!/bin/sh\necho Linux\n' >"$STUBS/uname"
printf '#!/bin/sh\nexit 0\n' >"$STUBS/fc-cache"
chmod +x "$STUBS/curl" "$STUBS/uname" "$STUBS/fc-cache"

# make_zip <zip> <kind>: regular (one font file), symlink (an entry that is a
# link to ~/.bashrc), or traversal (an entry named ../escaped.ttf).
make_zip() {
  python3 - "$1" "$2" <<'PY'
import sys, zipfile
path, kind = sys.argv[1], sys.argv[2]
def entry(name, mode):
    info = zipfile.ZipInfo(name)
    info.create_system = 3
    info.external_attr = mode << 16
    return info
with zipfile.ZipFile(path, "w") as z:
    z.writestr(entry("Font-Regular.ttf", 0o100644), "font")
    if kind == "symlink":
        z.writestr(entry("Font-Bold.ttf", 0o120777), "../../../.bashrc")
    elif kind == "traversal":
        z.writestr(entry("../escaped.ttf", 0o100644), "font")
PY
}

sha_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# release <kind>: both font zips of that kind plus a SHA-256.txt matching them.
release() {
  rm -f "$REL"/*
  make_zip "$REL/JetBrainsMono.zip" "$1"
  make_zip "$REL/NerdFontsSymbolsOnly.zip" regular
  {
    printf '%s  JetBrainsMono.zip\n' "$(sha_of "$REL/JetBrainsMono.zip")"
    printf '%s  NerdFontsSymbolsOnly.zip\n' "$(sha_of "$REL/NerdFontsSymbolsOnly.zip")"
  } >"$REL/SHA-256.txt"
}

# run_fonts <home>: prints the exit status.
run_fonts() {
  local rc=0
  mkdir -p "$1"
  env -i HOME="$1" PATH="$STUBS:/usr/bin:/bin" DOTFILES_SOURCE_DIR="$REPO_ROOT" DOTFILES_SILENT=1 \
    bash "$FONTS_SCRIPT" >"$WORK/out.txt" 2>&1 </dev/null || rc=$?
  printf '%s' "$rc"
}

FONTS=".local/share/fonts"

release regular
test_start "fonts_regular_archive_installed"
rc="$(run_fonts "$WORK/h1")"
assert_equals "0|yes|v3.4.0" \
  "$rc|$([[ -f "$WORK/h1/$FONTS/Font-Regular.ttf" ]] && echo yes || echo no)|$(cat "$WORK/h1/$FONTS/.nerd-fonts-version" 2>/dev/null)" \
  "a verified, regular archive is extracted and the version recorded"

release symlink
test_start "fonts_symlink_entry_refused"
rc="$(run_fonts "$WORK/h2")"
assert_equals "1|no|no" \
  "$rc|$([[ -L "$WORK/h2/$FONTS/Font-Bold.ttf" ]] && echo yes || echo no)|$([[ -e "$WORK/h2/$FONTS/.nerd-fonts-version" ]] && echo yes || echo no)" \
  "an archive holding a symlink is not extracted, and the run fails unrecorded"

release traversal
test_start "fonts_traversal_entry_refused"
rc="$(run_fonts "$WORK/h3")"
assert_equals "1|no|no" \
  "$rc|$([[ -e "$WORK/h3/.local/share/escaped.ttf" ]] && echo yes || echo no)|$([[ -e "$WORK/h3/$FONTS/.nerd-fonts-version" ]] && echo yes || echo no)" \
  "an archive with a path leaving the font directory is refused"

# The interactive checker (run_onchange_after_fonts.sh.tmpl) installs FiraCode
# when a terminal user accepts the gum prompt. It is rendered with chezmoi and
# run on a pty from script(1), with gum accepting and fc-list finding no font.
CHECKER_TMPL="$REPO_ROOT/defaults/run_onchange_after_fonts.sh.tmpl"
pty_run() {
  if script -qec true /dev/null </dev/null >/dev/null 2>&1; then
    script -qec "$1" /dev/null </dev/null
  else
    script -q /dev/null "$1" </dev/null
  fi
}
if command -v chezmoi >/dev/null 2>&1 && command -v script >/dev/null 2>&1; then
  mkdir -p "$WORK/cz"
  : >"$WORK/cz/chezmoi.toml"
  env -i HOME="$WORK/cz" PATH="$PATH" chezmoi --config "$WORK/cz/chezmoi.toml" \
    --source "$REPO_ROOT/defaults" --persistent-state "$WORK/cz/state" \
    execute-template <"$CHECKER_TMPL" >"$WORK/checker.sh"
  printf '#!/bin/sh\n[ "$1" = confirm ] && exit 0\necho "$*"\n' >"$STUBS/gum"
  printf '#!/bin/sh\nexit 0\n' >"$STUBS/fc-list"
  chmod +x "$STUBS/gum" "$STUBS/fc-list"
  printf '#!/bin/sh\nexec env -i HOME="$1" PATH="%s:/usr/bin:/bin" bash "%s"\n' "$STUBS" "$WORK/checker.sh" \
    >"$WORK/run-checker.sh"
  chmod +x "$WORK/run-checker.sh"

  # run_checker <kind> <home>: FiraCode.zip of that kind; prints the output.
  run_checker() {
    rm -f "$REL"/*
    make_zip "$REL/FiraCode.zip" "$1"
    printf '%s  FiraCode.zip\n' "$(sha_of "$REL/FiraCode.zip")" >"$REL/SHA-256.txt"
    mkdir -p "$2"
    pty_run "$WORK/run-checker.sh $2" 2>&1 | tr -d '\r'
  }

  test_start "checker_regular_archive_installed"
  run_checker regular "$WORK/c1" >/dev/null
  assert_equals "yes" "$([[ -f "$WORK/c1/$FONTS/Font-Regular.ttf" ]] && echo yes || echo no)" \
    "an accepted, regular FiraCode archive is extracted"

  test_start "checker_symlink_entry_refused"
  run_checker symlink "$WORK/c2" >/dev/null
  assert_equals "no|no" \
    "$([[ -L "$WORK/c2/$FONTS/Font-Bold.ttf" ]] && echo yes || echo no)|$([[ -e "$WORK/c2/$FONTS/Font-Regular.ttf" ]] && echo yes || echo no)" \
    "an archive holding a symlink is refused before anything is extracted"
else
  echo "SKIP: chezmoi or script(1) unavailable; interactive checker not run"
fi

print_summary
