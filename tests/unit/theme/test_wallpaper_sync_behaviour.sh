#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# wallpaper-sync.sh end to end in a sandbox HOME: uname picks the platform,
# and every setter (gsettings, dms, magick, WallpaperAgent, osascript, …) is
# a stub that records its call, so nothing on the host is touched.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WS="$REPO_ROOT/scripts/theme/wallpaper-sync.sh"
REAL_BASH="$(command -v bash)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
N=0

stub() {
  printf '#!%s\necho "%s $*" >>"%s/calls"\n%s\n' "$REAL_BASH" "$1" "$W" "$2" >"$W/stubs/$1"
  chmod +x "$W/stubs/$1"
}

# setup <os> <theme> [wallpaper...]: a sandbox HOME with that theme.
setup() {
  W="$WORK/c$((++N))"
  mkdir -p "$W/h/.dotfiles/defaults/.chezmoidata" "$W/h/Pictures/Wallpapers" "$W/stubs"
  echo defaults >"$W/h/.dotfiles/.chezmoiroot"
  printf 'theme = "%s"\n' "$2" >"$W/h/.dotfiles/defaults/.chezmoidata.toml"
  stub uname "echo $1"
  stub sleep 'exit 0'
  stub killall 'exit 0'
  stub pgrep 'exit 0'
  stub osascript 'exit 0'
  stub shuf 'head -1'
  shift 2
  local f
  for f in "$@"; do : >"$W/h/Pictures/Wallpapers/$f"; done
}

ws() {
  OUT="$(env -i HOME="$W/h" PATH="$W/stubs:/usr/bin:/bin" TERM=dumb NO_COLOR=1 "$REAL_BASH" "$WS" </dev/null 2>&1)"
  RC=$?
}
called() { grep -qF -- "$1" "$W/calls" 2>/dev/null && echo yes || echo no; }

# A dynamic HEIC named after the family only (dyn.heic) is split into
# frames on Linux and the mode's frame applied.
test_start "wallpaper_linux_dynamic_heic_applies_the_mode_frame"
setup Linux dyn-dark dyn.heic
stub gsettings 'exit 0'
stub magick 'last="${!#}"; base="${last%.png}"; : >"${base}-0.png"; : >"${base}-1.png"'
ws
assert_equals "0:yes:yes" \
  "$RC:$(called 'magick '):$([[ "$OUT" == *"dyn-1.png ← dyn-dark"* ]] && echo yes || echo no)" \
  "frames extracted and the dark frame applied"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
