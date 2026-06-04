#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Regression: theme scripts resolve .chezmoidata.toml via .chezmoiroot.
#
# Phase 4b (v0.2.503) put the chezmoi-tracked content under defaults/.
# The theme sync chain had hardcoded $SRC_DIR/.chezmoidata.toml paths
# that bypassed the .chezmoiroot descent — symptom was that `dot theme`
# silently kept reading stale state from before the reorg. This test
# stands up a synthetic chezmoi-root layout in a tmpdir, points the
# scripts at it via CHEZMOI_SOURCE_DIR, and asserts each one reads the
# theme out of defaults/ as the source of truth.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

SWITCH="$REPO_ROOT/scripts/theme/switch.sh"
WALLPAPER_SYNC="$REPO_ROOT/scripts/theme/wallpaper-sync.sh"
THEME_SYNC="$REPO_ROOT/bin/dot-theme-sync"

# --- Synthesize a sandboxed chezmoi-root layout ----------------------------
# Layout matches the real v0.2.503 repo: .chezmoiroot at the top says
# "defaults", and the actual data lives under defaults/.

sandbox="$(mktemp -d -t theme-paths.XXXXXX)"
trap 'rm -rf "$sandbox"' EXIT

mkdir -p "$sandbox/defaults/.chezmoidata"
printf 'defaults\n' >"$sandbox/.chezmoiroot"

# Theme set to a unique sentinel so we can prove the scripts read THIS
# file and not, e.g., the real repo's defaults/.chezmoidata.toml.
SENTINEL_THEME="sandbox-theme-$(date +%s%N | tr -d '\n' | tail -c8)-dark"

cat >"$sandbox/defaults/.chezmoidata.toml" <<EOF
dotfiles_version = "0.0.0-test"
theme = "${SENTINEL_THEME}"

[features]
test = true

[profile]
name = "minimal"
EOF

cat >"$sandbox/defaults/.chezmoidata/themes.toml" <<EOF
[themes.${SENTINEL_THEME}]
family = "sandbox-theme"
mode = "dark"
wallpaper = ""

[themes.${SENTINEL_THEME}.app]
gtk_theme = "Adwaita-dark"
gtk_icon = "Adwaita"
EOF

# Honey-trap: also create a .chezmoidata.toml at the sandbox ROOT with a
# *different* theme. If the scripts ever regress to reading from the
# root (bypassing the .chezmoiroot descent), they'd pick this up and
# the assertions below would fail with the trap value, not the
# sentinel. That makes regressions point-the-finger explicit.
TRAP_THEME="ROOT-LEVEL-BYPASS-MUST-NOT-BE-READ-dark"
cat >"$sandbox/.chezmoidata.toml" <<EOF
theme = "${TRAP_THEME}"
EOF

# Symlink lib/, bin/, scripts/ from the real repo so the theme scripts
# can still source ui.sh, lookup dot-theme-sync, etc. We don't run any
# write paths (we only call `current` / inspect functions), so the
# real repo isn't mutated.
ln -s "$REPO_ROOT/lib" "$sandbox/lib"
ln -s "$REPO_ROOT/bin" "$sandbox/bin"
ln -s "$REPO_ROOT/scripts" "$sandbox/scripts"

# wallpaper-sync.sh resolves the source dir via $HOME/.dotfiles rather
# than CHEZMOI_SOURCE_DIR, so wire ~/.dotfiles to the sandbox in the
# fake HOME. That matches how a real user is set up.
mkdir -p "$sandbox/fake-home"
ln -s "$sandbox" "$sandbox/fake-home/.dotfiles"

# --- Test: switch.sh `current` reads from defaults/ ------------------------
test_start "switch_sh_current_reads_from_defaults"
out="$(CHEZMOI_SOURCE_DIR="$sandbox" HOME="$sandbox/fake-home" \
  XDG_CONFIG_HOME="$sandbox/fake-home/.config" \
  XDG_STATE_HOME="$sandbox/fake-home/.local/state" \
  XDG_CACHE_HOME="$sandbox/fake-home/.cache" \
  "$BASH" "$SWITCH" current 2>&1)" || out="${out} [exit=$?]"
if [[ "$out" == *"$SENTINEL_THEME"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: switch.sh current → sentinel"
elif [[ "$out" == *"$TRAP_THEME"* ]]; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: REGRESSION — switch.sh read root .chezmoidata.toml, ignoring .chezmoiroot"
  printf '%b\n' "    Output: $out"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: switch.sh didn't print the sentinel theme"
  printf '%b\n' "    Output: $out"
fi

# --- Test: dot-theme-sync (no args) reports the sandbox theme --------------
# dot-theme-sync without args reads the current theme and reports it
# in its "Theme" info line. We DON'T want to run the full reload chain
# (it would try to talk to ghostty/tmux/wallpaper agents on the host),
# so we mock chezmoi as a no-op and direct everything to the sandbox.
# The script should at minimum print our sentinel as the active theme.
test_start "dot_theme_sync_reads_from_defaults"
mockbin="$sandbox/mock-bin"
mkdir -p "$mockbin"
for cmd in chezmoi tmux niri busctl dms gsettings nvim osascript \
  wallpaper killall pgrep defaults open xdg-open ghostty; do
  cat >"$mockbin/$cmd" <<EOF
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$mockbin/$cmd"
done

out="$(PATH="$mockbin:$PATH" CHEZMOI_SOURCE_DIR="$sandbox" \
  HOME="$sandbox/fake-home" \
  XDG_CONFIG_HOME="$sandbox/fake-home/.config" \
  XDG_STATE_HOME="$sandbox/fake-home/.local/state" \
  XDG_CACHE_HOME="$sandbox/fake-home/.cache" \
  "$BASH" "$THEME_SYNC" 2>&1)" || out="${out} [exit=$?]"
if [[ "$out" == *"$SENTINEL_THEME"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: dot-theme-sync read sentinel from defaults/"
elif [[ "$out" == *"$TRAP_THEME"* ]]; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: REGRESSION — dot-theme-sync read root .chezmoidata.toml"
  printf '%b\n' "    Output: ${out:0:400}"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dot-theme-sync output missing sentinel"
  printf '%b\n' "    Output: ${out:0:400}"
fi

# --- Test: switch.sh `list` enumerates themes from defaults/ ---------------
# `list` walks themes.toml under .chezmoidata/. If the descent is wrong
# it'd find an empty list (no themes defined at the sandbox root).
# The sentinel theme is unpaired (no -light counterpart in our fixture),
# so `list` will report 0 paired families — that's fine; the assertion
# is that the script doesn't crash and prints the "Current" line with
# our sentinel.
test_start "switch_sh_list_reads_themes_from_defaults"
out="$(CHEZMOI_SOURCE_DIR="$sandbox" HOME="$sandbox/fake-home" \
  XDG_CONFIG_HOME="$sandbox/fake-home/.config" \
  XDG_STATE_HOME="$sandbox/fake-home/.local/state" \
  XDG_CACHE_HOME="$sandbox/fake-home/.cache" \
  "$BASH" "$SWITCH" list 2>&1)" || out="${out} [exit=$?]"
if [[ "$out" == *"$SENTINEL_THEME"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: list shows the sandbox theme"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: list didn't print the sentinel"
  printf '%b\n' "    Output: ${out:0:400}"
fi

# --- Test: wallpaper-sync.sh resolves themes.toml from defaults/ -----------
# wallpaper-sync.sh runs the full Darwin/Linux apply chain at the end,
# which we don't want firing against a real host. We sidestep that by
# pointing DOTFILES_WALLPAPER_DIR at an empty dir — wallpaper-sync
# detects no wallpaper match and bails with the "skipping" path before
# touching the host. The header still prints the resolved theme.
test_start "wallpaper_sync_reads_theme_from_defaults"
empty_wp="$sandbox/empty-wallpapers"
mkdir -p "$empty_wp"
out="$(PATH="$mockbin:$PATH" CHEZMOI_SOURCE_DIR="$sandbox" \
  HOME="$sandbox/fake-home" \
  XDG_CONFIG_HOME="$sandbox/fake-home/.config" \
  XDG_STATE_HOME="$sandbox/fake-home/.local/state" \
  XDG_CACHE_HOME="$sandbox/fake-home/.cache" \
  DOTFILES_WALLPAPER_DIR="$empty_wp" \
  "$BASH" "$WALLPAPER_SYNC" 2>&1)" || out="${out} [exit=$?]"
# When no wallpaper file matches, the script prints
#   "no wallpaper for <theme> (skipping ...)" with the resolved theme.
if [[ "$out" == *"$SENTINEL_THEME"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: wallpaper-sync resolved theme from defaults/"
elif [[ "$out" == *"$TRAP_THEME"* ]]; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: REGRESSION — wallpaper-sync read root .chezmoidata.toml"
  printf '%b\n' "    Output: ${out:0:400}"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: wallpaper-sync output missing sentinel"
  printf '%b\n' "    Output: ${out:0:400}"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
