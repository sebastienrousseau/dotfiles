#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# rebuild-themes.sh end to end in a sandbox: a copy of the script beside a
# fake extract-theme.py (prints a [themes.NAME] block; fails for bad-*), a
# stub magick (two frames for dyn*), and a sandbox wallpaper directory.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

REAL_BASH="$(command -v bash)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# setup [wallpaper...]: fresh sandbox; W is its root.
setup() {
  W="$WORK/c$((++N))"
  mkdir -p "$W/home/.dotfiles/defaults/.chezmoidata" "$W/home/Pictures/Wallpapers" "$W/s" "$W/stubs"
  echo defaults >"$W/home/.dotfiles/.chezmoiroot"
  cp "$REPO_ROOT/scripts/theme/rebuild-themes.sh" "$REPO_ROOT/scripts/theme/fallback-themes.toml" "$W/s/"
  cat >"$W/s/extract-theme.py" <<'PY'
import sys
a = sys.argv[1:]
name, src = a[a.index("--name") + 1], a[a.index("--source") + 1]
if name.startswith("bad"):
    sys.exit(1)
print(f'[themes.{name}]\nwallpaper = "{a[0]}"\nsource = "{src}"')
PY
  local f
  for f in "$@"; do printf img >"$W/home/Pictures/Wallpapers/$f"; done
  touch -t 202001010000 "$W/home/Pictures/Wallpapers/"* 2>/dev/null
  printf '#!%s\ncase "$*" in *dyn*) printf "a\\nb\\n" ;; *) echo a ;; esac\n' "$REAL_BASH" >"$W/stubs/magick"
  chmod +x "$W/stubs/magick"
}
N=0

# rt [args...]: run the sandboxed script; sets OUT and RC.
rt() {
  OUT="$(env -i HOME="$W/home" XDG_CACHE_HOME="$W/home/.cache" PATH="$W/stubs:/usr/bin:/bin" \
    TERM=dumb LANG=C.UTF-8 "$REAL_BASH" "$W/s/rebuild-themes.sh" "$@" </dev/null 2>&1)"
  RC=$?
}
themes() { cat "$W/home/.dotfiles/defaults/.chezmoidata/themes.toml" 2>/dev/null; }
has() { if [[ "$1" == *"$2"* ]]; then echo yes; else echo no; fi; }

test_start "rebuild_static_image_gets_a_light_and_dark_theme"
setup "Ocean Blue.JPG"
rt
assert_equals "0:yes:yes" "$RC:$(has "$(themes)" '[themes.ocean-blue-dark]'):$(has "$(themes)" '[themes.ocean-blue-light]')" \
  "one static wallpaper, two themes"

test_start "rebuild_always_writes_the_fallback_themes"
assert_equals "yes:yes" "$(has "$(themes)" '[themes.fallback-dark]'):$(has "$(themes)" '[themes.fallback-light]')" "fallbacks present"

test_start "rebuild_dynamic_heic_maps_frames_to_modes"
setup dyn.heic
rt
assert_equals "yes:yes:no" \
  "$(has "$(themes)" 'dyn.heic[0]"'):$(has "$(themes)" 'dyn.heic[1]"'):$(has "$(themes)" '[themes.dyn]')" \
  "light is frame 0, dark frame 1, and the dynamic base is not a theme"

test_start "rebuild_explicit_mode_suffix_is_honoured"
setup "forest_night-dark.png"
rt
assert_equals "yes:no" "$(has "$(themes)" '[themes.forest-night-dark]'):$(has "$(themes)" 'forest-night-dark-light')" "only the named mode"

test_start "rebuild_counts_failures_and_leaves_them_out"
setup bad.png ok.png
rt
assert_equals "yes:no" "$(has "$OUT" 'Results: 2 generated, 0 cached, 2 failed'):$(has "$(themes)" 'bad-')" \
  "two ok, two failed, none of the failed in themes.toml"

test_start "rebuild_second_run_uses_the_cache"
rt
assert_contains "Results: 0 generated, 2 cached, 2 failed" "$OUT" "fresh cache entries are reused; failures retried"

test_start "rebuild_force_regenerates"
rt --force
assert_contains "Results: 2 generated, 0 cached, 2 failed" "$OUT" "--force ignores the cache"

test_start "rebuild_generator_change_invalidates_the_cache"
printf '\n# changed\n' >>"$W/s/extract-theme.py"
rt
assert_equals "yes:yes" "$(has "$OUT" 'Generator changed'):$(has "$OUT" 'Results: 2 generated, 0 cached')" "a new generator rebuilds"

test_start "rebuild_drops_orphaned_cache_entries"
printf 'x' >"$W/home/.cache/dotfiles/themes/gone-dark.toml"
rt
assert_file_not_exists "$W/home/.cache/dotfiles/themes/gone-dark.toml" "a cache entry with no wallpaper is removed"

test_start "rebuild_list_names_sources_and_paths"
setup "Sunset.webp" "--weird__.jpeg"
rt --list
assert_equals "yes:yes:yes" "$(has "$OUT" 'sunset-dark'):$(has "$OUT" 'weird-light'):$(has "$OUT" 'Total: 4 wallpapers')" \
  "normalized names, both modes, and the total"

test_start "rebuild_without_magick_is_a_clear_error"
setup ok.png
rm "$W/stubs/magick"
rt
assert_equals "1:yes" "$RC:$(has "$OUT" 'ImageMagick (magick) required')" "missing magick is named"

test_start "rebuild_with_no_wallpapers_writes_only_the_fallbacks"
setup
rt
assert_equals "0:yes" "$RC:$(has "$(themes)" '[themes.fallback-dark]')" "an empty wallpaper dir still yields a themes.toml"

test_start "rebuild_heic_without_magick_is_a_clear_error"
setup single.heic
rm "$W/stubs/magick"
rt
assert_equals "1:yes" "$RC:$(has "$OUT" 'ImageMagick (magick) required')" "not a silent exit 127"

test_start "rebuild_list_works_without_magick"
rt --list
assert_equals "0:yes" "$RC:$(has "$OUT" 'single-dark')" "listing needs no magick; a HEIC counts as one frame"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
