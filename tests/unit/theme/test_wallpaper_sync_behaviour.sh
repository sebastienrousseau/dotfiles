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

# Every stub is written once, into its own directory, and each case builds
# PATH from the tools it wants; behaviour comes from environment variables.
# (Creating fresh executables per case costs ~0.4s each on macOS, where
# every new binary is assessed on first run.) Each stub appends
# "<name> <args>" to $CALLS.
mkstub() {
  mkdir -p "$WORK/t/$1"
  printf '#!%s\necho "%s $*" >>"$CALLS"\n%s\n' "$REAL_BASH" "$1" "$2" >"$WORK/t/$1/$1"
  chmod +x "$WORK/t/$1/$1"
}
mkstub uname 'echo "$STUB_OS"'
mkstub sleep 'exit 0'
mkstub killall 'exit 0'
mkstub osascript 'exit 0'
mkstub shuf 'head -1'
# The store patcher has its own test (test_macos_wallpaper_patcher.sh);
# here it is only recorded. The real /usr/bin/python3 on macOS is an Xcode
# shim that takes seconds to start under `env -i`.
mkstub python3 'exit 0'
mkstub defaults '[ "${DEFAULTS_DARK:-0}" = 1 ] && echo Dark || exit 1'
mkstub pgrep 'case "${PGREP_MODE:-ok}" in
  never) exit 1 ;;
  slow) n=$(cat "$CALLS.pg" 2>/dev/null || echo 0); n=$((n + 1)); echo $n >"$CALLS.pg"; [ $n -ge 3 ] ;;
  *) exit 0 ;;
esac'
mkstub gsettings 'case "$1" in get) echo "${GS_SCHEME:-default}" ;; esac; exit 0'
mkstub dms 'case "$*" in
  "ipc theme getMode") echo "${DMS_GETMODE:-}" ;;
  "ipc wallpaper set"*) echo "${DMS_SET:-}" ;;
  "ipc outputs current") echo "${DMS_OUTPUTS:-}" ;;
esac; exit 0'
mkstub magick 'case "${MAGICK_MODE:-}" in
  fail) exit 1 ;;
  extractfail) [ "$1" = identify ] || exit 1 ;;
esac
case "$1" in
  identify) if [ "${MAGICK_MODE:-}" = single ]; then echo a; else printf "a\nb\n"; fi ;;
  *) last="${!#}"; base="${last%.png}"
     if [ "${last##*.}" = png ]; then : >"${base}-0.png"; : >"${base}-1.png"; else echo x >"$last"; fi ;;
esac'
mkstub heif-convert 'echo x >"$2"'
mkstub convert 'echo x >"$2"'
mkstub feh 'exit 0'
mkstub swaybg 'exit 0'
mkstub pkill 'exit 1'
mkstub wallpaper 'exit 0'

# setup <os> <theme> [wallpaper...]: a sandbox HOME with that theme; resets
# the tool set to the always-present stubs.
setup() {
  W="$WORK/c$((++N))"
  mkdir -p "$W/h/.dotfiles/defaults/.chezmoidata" "$W/h/Pictures/Wallpapers"
  echo defaults >"$W/h/.dotfiles/.chezmoiroot"
  if [[ -n "$2" ]]; then
    printf 'theme = "%s"\n' "$2" >"$W/h/.dotfiles/defaults/.chezmoidata.toml"
  else
    : >"$W/h/.dotfiles/defaults/.chezmoidata.toml"
  fi
  OS="$1"
  TOOLS="uname sleep killall osascript shuf python3 defaults pgrep"
  ENVS=()
  shift 2
  local f
  for f in "$@"; do : >"$W/h/Pictures/Wallpapers/$f"; done
}

# use <tool>...: add stubs to this case's PATH.
use() { TOOLS="$TOOLS $*"; }

ws() {
  local t path=""
  for t in $TOOLS; do path="$path$WORK/t/$t:"; done
  OUT="$(env -i HOME="$W/h" PATH="${path}/usr/bin:/bin" TERM=dumb NO_COLOR=1 CALLS="$W/calls" \
    STUB_OS="$OS" DOTFILES_THEME_SYSTEM_ROOT="$W/sys" ${ENVS[@]+"${ENVS[@]}"} "$REAL_BASH" "$WS" </dev/null 2>&1)"
  RC=$?
}
called() { grep -qF -- "$1" "$W/calls" 2>/dev/null && echo yes || echo no; }

# A dynamic HEIC named after the family only (dyn.heic) is split into
# frames on Linux and the mode's frame applied.
test_start "wallpaper_linux_dynamic_heic_applies_the_mode_frame"
setup Linux dyn-dark dyn.heic
use gsettings
use magick
ws
assert_equals "0:yes:yes" \
  "$RC:$(called 'magick '):$([[ "$OUT" == *"dyn-1.png ← dyn-dark"* ]] && echo yes || echo no)" \
  "frames extracted and the dark frame applied"

# applied <name>: yes when the run reports that wallpaper file as applied.
applied() { if [[ "$OUT" == *"Applied wallpaper ("*") "*"$1"* ]]; then echo yes; else echo no; fi; }
toml() { printf '[themes.%s]\nwallpaper = "%s"\n\n' "$1" "$2" >>"$W/h/.dotfiles/defaults/.chezmoidata/themes.toml"; }

# ── lookup order ─────────────────────────────────────────────────────────
test_start "wallpaper_prefers_extracted_frames"
setup Darwin ocean-dark ocean-1.png ocean-0.png ocean-dark.png
ws
assert_equals "0:yes" "$RC:$(applied ocean-1.png)" "frame -1 is the dark one"

test_start "wallpaper_light_frame_on_linux"
setup Linux ocean-light ocean-0.jpg ocean-1.jpg
use gsettings
ws
assert_equals "yes:yes" "$(applied ocean-0.jpg):$(called 'picture-uri-dark file://'"$W"'/h/Pictures/Wallpapers/ocean-1.jpg')" \
  "frame -0 is light; its -1 partner is the dark picture"

test_start "wallpaper_exact_theme_name"
setup Darwin hello-dark hello-dark.png hello.png
ws
assert_equals "yes" "$(applied hello-dark.png)" "the exact theme file"

test_start "wallpaper_family_mode_variant_uses_the_detected_mode"
setup Darwin hello hello-dark.heic hello-light.webp
ENVS+=(DEFAULTS_DARK=1)
ws
assert_equals "yes" "$(applied hello-dark.heic)" "no suffix in the theme: macOS dark mode picks -dark"

test_start "wallpaper_family_mode_variant_light_by_default"
setup Darwin hello hello-light.webp
ws
assert_equals "yes" "$(applied hello-light.webp)" "macOS light mode"

test_start "wallpaper_stored_home_relative_path"
setup Darwin sea-dark
mkdir -p "$W/h/Pictures/Other" && : >"$W/h/Pictures/Other/sea.jpg"
# shellcheck disable=SC2088 # a literal ~/ path, as themes.toml stores it
toml sea-dark "~/Pictures/Other/sea.jpg"
ws
assert_equals "yes" "$(applied sea.jpg)" "themes.toml ~/ path resolved"

test_start "wallpaper_stored_legacy_users_path"
setup Linux sea-dark
use gsettings
mkdir -p "$W/h/Pictures/Other" && : >"$W/h/Pictures/Other/sea.jpg"
toml sea-dark "/Users/bob/Pictures/Other/sea.jpg"
ws
assert_equals "yes" "$(applied sea.jpg)" "/Users/<name>/ maps to \$HOME"

test_start "wallpaper_stored_macos_system_path_skipped_on_linux"
setup Linux sea-dark sea.png
use gsettings
toml sea-dark "/System/Library/Desktop Pictures/Sea.heic"
ws
assert_equals "yes" "$(applied sea.png)" "falls through to the family file"

test_start "wallpaper_family_only_file"
setup Darwin fam-dark fam.jpg
ws
assert_equals "yes" "$(applied fam.jpg)" "family.jpg for fam-dark"

# ── pick fallbacks ───────────────────────────────────────────────────────
test_start "wallpaper_any_mode_file_when_the_theme_has_none"
setup Darwin nomatch-dark a-dark.png b-dark.jpg c-light.png
ws
assert_equals "yes" "$(applied a-dark.png)" "first *-dark file (shuf stubbed to head)"

test_start "wallpaper_any_frame_file_as_last_resort"
setup Darwin nomatch-dark x-1.png y-0.png
ws
assert_equals "yes" "$(applied x-1.png)" "*-1 frames are dark"

test_start "wallpaper_nothing_matches_skips_cleanly"
setup Darwin nomatch-dark z-light.png
ws
assert_equals "0:yes" "$RC:$([[ "$OUT" == *"no wallpaper for nomatch-dark"* ]] && echo yes)" "skip, exit 0"

test_start "wallpaper_without_a_wallpaper_dir"
setup Darwin ocean-dark
rm -rf "$W/h/Pictures/Wallpapers"
ws
assert_equals "0:yes" "$RC:$([[ "$OUT" == *"no wallpaper for ocean-dark"* ]] && echo yes)" "no dir, skip"

test_start "wallpaper_chezmoi_config_theme_wins"
setup Darwin ocean-dark cfg-light.png ocean-dark.png
mkdir -p "$W/h/.config/chezmoi" && printf 'theme = "cfg-light"\n' >"$W/h/.config/chezmoi/chezmoi.toml"
ws
assert_equals "yes" "$(applied cfg-light.png)" "chezmoi.toml theme over .chezmoidata"

# ── mode detection without a theme ──────────────────────────────────────
test_start "wallpaper_dms_mode"
setup Linux "" q-light.png q-dark.png
use gsettings
use dms
ENVS+=(DMS_GETMODE=light DMS_SET='SUCCESS: ok')
ws
assert_equals "yes:yes" "$(applied q-light.png):$([[ "$OUT" == *"dms ipc"* ]] && echo yes)" "dms decides the mode and applies"

test_start "wallpaper_gsettings_prefer_dark"
setup Linux "" q-light.png q-dark.png
use gsettings
ENVS+=(GS_SCHEME=prefer-dark)
ws
assert_equals "yes" "$(applied q-dark.png)" "gsettings color-scheme"

test_start "wallpaper_linux_without_gsettings_defaults_dark"
setup Linux "" q-dark.png q-light.png
use feh
ws
assert_equals "yes:yes" "$(applied q-dark.png):$(called 'feh --bg-fill')" "dark, applied with feh"

# ── appliers ─────────────────────────────────────────────────────────────
test_start "wallpaper_macos_restarts_the_agent_and_reasserts"
setup Darwin ocean-dark ocean-dark.png
ws
assert_equals "yes:yes:yes" "$(called 'macos-wallpaper-store.py '"$W"'/h/Pictures/Wallpapers/ocean-dark.png'):$(called 'killall WallpaperAgent'):$(called 'osascript -e')" \
  "store patch, agent restart and AppleScript"

test_start "wallpaper_macos_skip_agent_uses_the_wallpaper_cli"
setup Darwin ocean-dark ocean-dark.png
use wallpaper
ENVS+=(DOT_THEME_SKIP_WALLPAPER_AGENT=1)
ws
assert_equals "no:yes" "$(called 'killall'):$(called 'wallpaper set')" "no restart; wallpaper(1) sets it"

test_start "wallpaper_macos_agent_slow_to_return_still_applies"
setup Darwin ocean-dark ocean-dark.png
ENVS+=(PGREP_MODE=slow)
ws
assert_equals "0:yes" "$RC:$(applied ocean-dark.png)" "waits, then applies"

test_start "wallpaper_linux_dms_per_monitor"
setup Linux p-dark p-dark.png
use feh
use dms
ENVS+=(DMS_SET='ERROR: Per-monitor mode enabled' DMS_OUTPUTS='["DP-1","HDMI-A-1",""]')
ws
assert_equals "yes:yes" "$(called 'setFor DP-1'):$(called 'setFor HDMI-A-1')" "each output gets it"

test_start "wallpaper_linux_gsettings_single_file"
setup Linux solo-dark solo-dark.jpg
use gsettings
ws
assert_equals "yes" "$(called 'screensaver picture-uri file://')" "one file for desktop and lock screen"

test_start "wallpaper_linux_swaybg"
setup Linux p-dark p-dark.png
use swaybg pkill
ws
assert_equals "0:yes" "$RC:$([[ "$OUT" == *"swaybg"* ]] && echo yes)" "swaybg when there is no gsettings"

test_start "wallpaper_linux_without_any_setter_fails"
setup Linux p-dark p-dark.png
ws
assert_equals "1" "$RC" "no gsettings/swaybg/feh is an error"

test_start "wallpaper_unsupported_os_fails"
setup FreeBSD p-dark p-dark.png
ws
assert_equals "1" "$RC" "only Darwin and Linux"

# ── HEIC handling ────────────────────────────────────────────────────────
# The cache is only consulted for a HEIC the lookup picked, e.g. through the
# mode fallback, where the sorted listing puts x-dark.heic before x-dark.png.
test_start "wallpaper_linux_heic_uses_a_fresh_large_cached_png"
setup Linux nomatch-dark big-dark.heic
use gsettings
use heif-convert
touch -t 202001010000 "$W/h/Pictures/Wallpapers/big-dark.heic"
head -c 1100000 /dev/zero >"$W/h/Pictures/Wallpapers/big-dark.png"
ws
assert_equals "no:yes" "$(called 'heif-convert '):$(called 'picture-uri file://'"$W"'/h/Pictures/Wallpapers/big-dark.png')" \
  "the cache is used, nothing converted"

test_start "wallpaper_linux_heic_small_cache_is_reconverted"
setup Linux nomatch-dark sm-dark.heic
use gsettings
use heif-convert
touch -t 202001010000 "$W/h/Pictures/Wallpapers/sm-dark.heic"
echo tiny >"$W/h/Pictures/Wallpapers/sm-dark.png"
ws
assert_equals "yes" "$(called 'heif-convert ')" "a tiny cached png is not trusted"

test_start "wallpaper_linux_heic_stale_cache_is_reconverted"
setup Linux nomatch-dark st-dark.heic
use gsettings
use heif-convert
head -c 1100000 /dev/zero >"$W/h/Pictures/Wallpapers/st-dark.png"
touch -t 202001010000 "$W/h/Pictures/Wallpapers/st-dark.png"
ws
assert_equals "yes" "$(called 'heif-convert ')" "a png older than its heic is not trusted"

test_start "wallpaper_linux_heic_convert_fallback"
setup Linux cv-dark cv-dark.heic
use gsettings
use convert
ws
assert_equals "yes:no" "$(called 'picture-uri file://'"$W"'/h/Pictures/Wallpapers/cv-dark.png'):$(called 'picture-uri file://'"$W"'/h/Pictures/Wallpapers/cv-dark.heic')" \
  "ImageMagick 6 convert, and only the png is applied"

test_start "wallpaper_linux_heic_without_a_converter_uses_the_original"
setup Linux nc-dark nc-dark.heic
use gsettings
ws
assert_equals "yes" "$(called 'picture-uri file://'"$W"'/h/Pictures/Wallpapers/nc-dark.heic')" "the HEIC itself"

test_start "wallpaper_macos_dynamic_heic_is_reduced_to_the_mode_frame"
setup Darwin dyn-dark dyn.heic
use magick
ws
assert_equals "yes:yes" "$(called 'magick '"$W"'/h/Pictures/Wallpapers/dyn.heic[1]'):$([[ -f "$W/h/Pictures/Wallpapers/.dot-frames/dyn-dark.heic" ]] && echo yes)" \
  "frame 1 extracted into the frame cache"

test_start "wallpaper_macos_single_frame_heic_is_used_as_is"
setup Darwin dyn-dark dyn.heic
use magick
ENVS+=(MAGICK_MODE=single)
ws
assert_equals "no" "$([[ -d "$W/h/Pictures/Wallpapers/.dot-frames" ]] && echo yes || echo no)" "no frame cache for one frame"

# ── system wallpapers (under a fake DOTFILES_THEME_SYSTEM_ROOT) ─────────
test_start "wallpaper_macos_system_wallpaper_for_a_mapped_family"
setup Darwin "macos - pink-dark"
mkdir -p "$W/sys/System/Library/Desktop Pictures" && : >"$W/sys/System/Library/Desktop Pictures/Mac Pink.heic"
ws
assert_equals "yes:yes" "$(applied 'Mac Pink.heic'):$([[ "$OUT" == *"using system wallpaper"* ]] && echo yes)" "the mapped system file"

test_start "wallpaper_macos_unmapped_family_has_no_system_wallpaper"
setup Darwin "macos - teal-dark"
mkdir -p "$W/sys/System/Library/Desktop Pictures" && : >"$W/sys/System/Library/Desktop Pictures/Teal.heic"
ws
assert_equals "0:yes" "$RC:$([[ "$OUT" == *"no wallpaper for macos - teal-dark"* ]] && echo yes)" "no mapping, no wallpaper"

test_start "wallpaper_macos_mapped_but_missing_system_file"
setup Darwin "macos - blue-dark"
mkdir -p "$W/sys/System/Library/Desktop Pictures"
ws
assert_equals "yes" "$([[ "$OUT" == *"no wallpaper for macos - blue-dark"* ]] && echo yes)" "a missing file is no wallpaper"

test_start "wallpaper_linux_system_wallpaper_by_keyword"
setup Linux macos-hill-dark
use gsettings
mkdir -p "$W/sys/usr/share/wallpapers/x" && : >"$W/sys/usr/share/wallpapers/x/Green-Hill.jpg"
ws
assert_equals "yes" "$(applied Green-Hill.jpg)" "backgrounds/ absent, wallpapers/ searched by keyword"

# ── HEIC conversion failures and the macOS frame cache ──────────────────
test_start "wallpaper_linux_magick_failure_falls_back_to_the_heic"
setup Linux mf-dark mf-dark.heic
use gsettings magick
ENVS+=(MAGICK_MODE=fail)
ws
assert_equals "yes" "$(called 'picture-uri file://'"$W"'/h/Pictures/Wallpapers/mf-dark.heic')" "the original is used"

test_start "wallpaper_linux_heif_convert_failure_falls_back_to_the_heic"
setup Linux hf-dark hf-dark.heic
use gsettings
mkstub heif-convert-fail 'exit 1'
mv "$WORK/t/heif-convert-fail/heif-convert-fail" "$WORK/t/heif-convert-fail/heif-convert"
use heif-convert-fail
ws
assert_equals "yes" "$(called 'picture-uri file://'"$W"'/h/Pictures/Wallpapers/hf-dark.heic')" "the original is used"

test_start "wallpaper_macos_reuses_a_fresh_cached_frame"
setup Darwin dyn-dark dyn.heic
use magick
mkdir -p "$W/h/Pictures/Wallpapers/.dot-frames"
touch -t 202001010000 "$W/h/Pictures/Wallpapers/dyn.heic"
: >"$W/h/Pictures/Wallpapers/.dot-frames/dyn-dark.heic"
ws
assert_equals "no:yes" "$(called 'dyn.heic[1]'):$(called 'macos-wallpaper-store.py '"$W"'/h/Pictures/Wallpapers/.dot-frames/dyn-dark.heic')" \
  "no extraction; the cached frame is applied"

test_start "wallpaper_macos_failed_frame_extraction_keeps_the_original"
setup Darwin dyn-dark dyn.heic
use magick
ENVS+=(MAGICK_MODE=extractfail)
ws
assert_equals "yes" "$(applied dyn.heic)" "extraction failed, the dynamic HEIC is applied as is"

test_start "wallpaper_macos_agent_that_never_returns_is_waited_for_then_left"
setup Darwin ocean-dark ocean-dark.png
ENVS+=(PGREP_MODE=never)
ws
assert_equals "0:60" "$RC:$(grep -c '^sleep 0.1' "$W/calls")" "sixty 0.1s waits, then the wallpaper is applied anyway"

# ── gsettings pairs ─────────────────────────────────────────────────────
test_start "wallpaper_linux_gsettings_light_dark_pair"
setup Linux p-dark p-dark.png p-light.png
use gsettings
ws
assert_equals "yes:yes:yes" \
  "$(called 'background picture-uri file://'"$W"'/h/Pictures/Wallpapers/p-light.png'):$(called 'picture-uri-dark file://'"$W"'/h/Pictures/Wallpapers/p-dark.png'):$(called 'screensaver picture-uri file://'"$W"'/h/Pictures/Wallpapers/p-dark.png')" \
  "light, dark, and the dark lock screen"

test_start "wallpaper_linux_gsettings_pair_from_the_theme_family"
# Only an extension the lookup never tries (.tiff) reaches this: the theme's
# stored wallpaper has no -light/-dark or -0/-1 suffix, so the pair is
# looked up by the theme's family instead.
setup Linux pp-light pp.tiff pp-light.tiff pp-dark.tiff
use gsettings
toml pp-light "$W/h/Pictures/Wallpapers/pp.tiff"
ws
assert_equals "yes:yes:yes" \
  "$(called 'background picture-uri file://'"$W"'/h/Pictures/Wallpapers/pp-light.tiff'):$(called 'picture-uri-dark file://'"$W"'/h/Pictures/Wallpapers/pp-dark.tiff'):$(called 'screensaver picture-uri file://'"$W"'/h/Pictures/Wallpapers/pp-light.tiff')" \
  "a wallpaper with neither suffix pairs by the theme's family"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
