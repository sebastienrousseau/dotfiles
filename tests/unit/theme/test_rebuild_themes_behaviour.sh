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

# rebuild-themes.sh needs bash >= 4 (associative arrays, wait -n) and
# refuses to run otherwise; macOS runners may have only /bin/bash 3.2.
REAL_BASH=""
for _b in "$(command -v bash)" /opt/homebrew/bin/bash /usr/local/bin/bash; do
  if [[ -x "$_b" ]] && "$_b" -c '((BASH_VERSINFO[0] >= 4))' 2>/dev/null; then
    REAL_BASH="$_b"
    break
  fi
done
if [[ -z "$REAL_BASH" ]]; then
  echo "  (skipped: no bash >= 4 available, which rebuild-themes.sh requires)"
  echo "RESULTS:0:0:0"
  exit 0
fi
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
# sysbin <dir> <tool...>: /usr/bin and /bin as links in <dir>, minus the
# named tools, so a "without <tool>" case holds on machines that have it.
sysbin() {
  local dir="$1" args=() t
  shift
  for t in "$@"; do args+=(! -name "$t"); done
  mkdir -p "$dir"
  find /usr/bin/ /bin/ -maxdepth 1 \( -type f -o -type l \) "${args[@]}" -exec sh -c 'ln -sf "$@" "$0"' "$dir" {} + 2>/dev/null
}
sysbin "$WORK/sysbin" magick

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
  OUT="$(env -i HOME="$W/home" XDG_CACHE_HOME="$W/home/.cache" PATH="$W/stubs:$WORK/sysbin" \
    TERM=dumb LANG=C.UTF-8 DOTFILES_THEME_SYSTEM=1 DOTFILES_THEME_SYSTEM_ROOT="$W/sys" "$REAL_BASH" "$W/s/rebuild-themes.sh" "$@" </dev/null 2>&1)"
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

test_start "rebuild_aaa_pass_change_invalidates_the_cache"
rt
printf '# v1\n' >"$W/s/aaa.py"
rt
assert_equals "yes:yes" "$(has "$OUT" 'Generator changed'):$(has "$OUT" 'Results: 2 generated, 0 cached')" "a new AAA pass rebuilds"
rt
assert_contains "Results: 0 generated, 2 cached" "$OUT" "an unchanged AAA pass reuses the cache"
printf '# v1\n' >"$W/s/apple.py"
rt
assert_contains "Results: 2 generated, 0 cached" "$OUT" "a new Apple colour table rebuilds"

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

# ── System wallpapers (DOTFILES_THEME_SYSTEM=1, under a fake system root) ──
# sys_os <Darwin|Linux>: make uname report that OS.
sys_os() {
  printf '#!%s\necho %s\n' "$REAL_BASH" "$1" >"$W/stubs/uname"
  chmod +x "$W/stubs/uname"
}

test_start "rebuild_macos_system_prefers_explicit_variants"
setup
sys_os Darwin
d="$W/sys/System/Library/Desktop Pictures"
mkdir -p "$d/.thumbnails"
for f in "Big Sur Graphic.heic" "Monterey.heic" "Sonoma.heic" "notes.txt"; do printf i >"$d/$f"; done
for f in "Big Sur Graphic Dark.heic" "Big Sur Graphic Light.heic" "Monterey.heic" "Sonoma Light.heic"; do
  printf i >"$d/.thumbnails/$f"
done
rt --list
listed="$(printf '%s\n' "$OUT" | awk '$2 == "system" {print $1}' | tr '\n' ' ')"
assert_equals "big-sur-graphic-dark big-sur-graphic-light monterey sonoma-light " "$listed" \
  "bases with a -dark or -light variant are dropped; others stay"

test_start "rebuild_macos_system_keeps_the_top_level_file_over_a_thumbnail"
assert_contains "Desktop Pictures/Monterey.heic" "$(printf '%s\n' "$OUT" | grep '^monterey ')" "the thumbnail does not replace it"

test_start "rebuild_macos_system_without_thumbnails"
rm -rf "$d/.thumbnails"
rt --list
assert_contains "Total: 3 wallpapers" "$OUT" "top-level files only, none dropped"

test_start "rebuild_linux_system_images_get_both_modes"
setup
sys_os Linux
mkdir -p "$W/sys/usr/share/backgrounds" "$W/sys/usr/share/wallpapers/gnome"
for f in "Ubuntu_Default.png" "night-dark.jpg" "---.png"; do printf i >"$W/sys/usr/share/backgrounds/$f"; done
printf i >"$W/sys/usr/share/wallpapers/gnome/Adwaita Morning.jpg"
rt --list
listed="$(printf '%s\n' "$OUT" | awk '$2 == "system" {print $1}' | tr '\n' ' ')"
assert_equals "adwaita-morning-dark adwaita-morning-light night-dark ubuntu-default-dark ubuntu-default-light " "$listed" \
  "statics become pairs, an explicit -dark stays single, an empty name is skipped"

test_start "rebuild_custom_wallpaper_overrides_a_system_one"
printf img >"$W/home/Pictures/Wallpapers/Ubuntu Default.png"
rt --list
assert_contains "custom" "$(printf '%s\n' "$OUT" | grep '^ubuntu-default-dark ')" "the custom file wins"

# ── File names that would break out of TOML or shell ───────────────────────
test_start "rebuild_skips_wallpapers_with_dangerous_names"
setup 'x$(y).png' 'tick`t`.png' 'q"uote.png' "$(printf 'ctl\tx.png')" plain.png
rt
assert_equals "0" "$RC" "the rebuild still succeeds"
assert_contains 'skipping x$(y).png' "$OUT" "the \$ name is named as skipped"
assert_contains 'skipping tick`t`.png' "$OUT" "the backtick name is named as skipped"
assert_contains 'skipping q"uote.png' "$OUT" "the quote name is named as skipped"
assert_contains "$(printf 'skipping ctl\tx.png')" "$OUT" "the control-character name is named as skipped"
assert_contains 'unsafe character' "$OUT" "the reason is given"
assert_equals "yes:no:no:no:no" "$(has "$(themes)" '[themes.plain-dark]'):$(has "$(themes)" 'xy-'):$(has "$(themes)" 'tickt-'):$(has "$(themes)" 'quote-'):$(has "$(themes)" 'ctlx-')" \
  "only the safe wallpaper is themed"

test_start "rebuild_skips_dangerous_linux_system_names"
setup
sys_os Linux
mkdir -p "$W/sys/usr/share/backgrounds"
for f in 'sys$(y).png' 'fine.png'; do printf i >"$W/sys/usr/share/backgrounds/$f"; done
rt --list
assert_equals "fine-dark fine-light " "$(printf '%s\n' "$OUT" | awk '$2 == "system" {print $1}' | tr '\n' ' ')" "the \$ name is not listed"
assert_contains 'skipping sys$(y).png' "$OUT" "and is named as skipped"

test_start "extractor_writes_valid_toml_for_any_value"
# Called directly (not through rebuild), a quote in the path must stay data.
got="$(
  python3 - "$REPO_ROOT/scripts/theme" <<'PY'
import importlib.util, sys, tomllib
spec = importlib.util.spec_from_file_location("et", sys.argv[1] + "/extract-theme.py")
et = importlib.util.module_from_spec(spec)
spec.loader.exec_module(et)
clusters = [((22.0, 18.0, 20.0), 500), ((55.0, 45.0, 50.0), 300), ((60.0, -20.0, -40.0), 200), ((70.0, -40.0, 30.0), 100)]
theme = et.generate_theme(clusters, "q-dark", True)
wp = '/w/a"b\\c\n$(id).png'
theme["wallpaper"] = wp
theme["source"] = 'cu"stom'
theme["app"]["nvim"] = 'x")vim.fn.system("id'
doc = tomllib.loads(et.theme_to_toml(theme))["themes"]["q-dark"]
print(doc["wallpaper"] == wp, doc["source"] == 'cu"stom', doc["app"]["nvim"] == theme["app"]["nvim"],
      doc["mode"], doc["family"], doc["term"]["bg"] == theme["term"]["bg"], doc["ui"]["accent"] == theme["ui"]["accent"],
      sorted(doc) == sorted(["mode", "family", "macos_accent", "wallpaper", "source", "term", "ui", "app"]))
for bad in ("Bad", "a.b", "a]x", "-a", "", "a b"):
    theme["name"] = bad
    try:
        et.theme_to_toml(theme)
        print("accepted", repr(bad))
    except ValueError:
        pass
PY
)"
assert_equals "True True True dark q True True True" "$got" "values round-trip through tomllib; bad names are refused"

test_start "extractor_cli_refuses_a_bad_theme_name"
out="$(
  python3 - "$REPO_ROOT/scripts/theme" <<'PY' 2>&1
import importlib.util, sys
spec = importlib.util.spec_from_file_location("et", sys.argv[1] + "/extract-theme.py")
et = importlib.util.module_from_spec(spec)
spec.loader.exec_module(et)
et.extract_pixels = lambda path: [(10, 20, 30)] * 50 + [(200, 100, 50)] * 50
sys.argv = ["extract-theme.py", "img.png", "--name", "evil]\n[x"]
try:
    et.main()
except SystemExit as e:
    print("exit", e.code)
PY
)"
assert_contains "exit 1" "$out" "exits 1"
assert_contains "invalid theme name" "$out" "and says why"

# ── Dependencies, the cache, and the job limit ─────────────────────────────
test_start "rebuild_without_the_extractor_is_an_error"
setup ok.png
rm "$W/s/extract-theme.py"
rt
assert_equals "1:yes" "$RC:$(has "$OUT" 'extract-theme.py not found')" "a missing extractor stops the rebuild"

test_start "rebuild_without_python3_is_an_error"
setup ok.png
mkdir -p "$W/tools"
for t in head tr basename find sort wc grep mkdir cat rm date awk dirname sed shasum sha256sum; do
  p="$(command -v "$t" 2>/dev/null)" && ln -s "$p" "$W/tools/$t"
done
OUT="$(env -i HOME="$W/home" XDG_CACHE_HOME="$W/home/.cache" PATH="$W/stubs:$W/tools" TERM=dumb \
  "$REAL_BASH" "$W/s/rebuild-themes.sh" </dev/null 2>&1)"
RC=$?
assert_equals "1:yes" "$RC:$(has "$OUT" 'python3 required')" "python3 is required"

test_start "rebuild_all_cached_starts_no_jobs"
setup ok.png
rt
rt
assert_equals "no:yes" "$(has "$OUT" 'Processing'):$(has "$OUT" '0 generated, 2 cached')" "nothing to do, nothing started"

test_start "rebuild_runs_at_most_four_jobs_at_once"
setup a.png b.png c.png d.png e.png f.png g.png h.png
mkdir -p "$W/conc"
cat >"$W/s/extract-theme.py" <<PY
import os, sys, time
d = "$W/conc"
me = os.path.join(d, str(os.getpid()))
open(me, "w").close()
n = len([f for f in os.listdir(d) if not f.endswith(".max")])
open(me + ".max", "w").write(str(n) + "\n")
time.sleep(0.4)
os.remove(me)
a = sys.argv[1:]
print("[themes." + a[a.index("--name") + 1] + "]")
PY
rt
peak="$(cat "$W/conc/"*.max | sort -n | tail -1)"
assert_equals "0:yes" "$RC:$([[ "$peak" -ge 2 && "$peak" -le 4 ]] && echo yes)" "parallel, but never more than 4 (peak $peak)"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
