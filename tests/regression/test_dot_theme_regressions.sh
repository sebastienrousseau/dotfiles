#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Regression tests for the dot theme bugs fixed during v0.2.503
# development. Each test pins a specific past regression so we never
# ship it again.
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

SWITCH_SH="$REPO_ROOT/scripts/theme/switch.sh"
THEMES_FILE="$REPO_ROOT/defaults/.chezmoidata/themes.toml"
DOT_THEME_SYNC="$REPO_ROOT/bin/dot-theme-sync"

# ---------------------------------------------------------------------------
# Regression 1: mixed-case theme names must appear in `dot theme list`
#
# Bug: `all_theme_names` used sed with `[a-z0-9-]*` which silently dropped
# 226 custom-wallpaper themes with capitalised names (Altai, Bauhaus, etc.).
# `dot theme list` reported "0 wallpaper themes available" on Linux.
# Fix: widen the character class to `[a-zA-Z0-9-]*`.
# ---------------------------------------------------------------------------
test_start "regression: dot theme list includes capitalised names"
if [[ -f "$THEMES_FILE" ]]; then
  extracted="$(sed -n 's/^\[themes\.\([a-zA-Z0-9-]*\)\]$/\1/p' "$THEMES_FILE" | sort -u)"
  # Should include at least one Uppercase-starting family.
  if grep -qE '^[A-Z]' <<<"$extracted"; then
    ((TESTS_PASSED++)) || true
    printf '  \e[32m✓\e[0m %s\n' "$CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '  \e[31m✗\e[0m %s (no capitalised themes found)\n' "$CURRENT_TEST"
  fi
else
  ((TESTS_PASSED++)) || true
  printf '  \e[33m~\e[0m %s (themes.toml missing — skipped)\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# Regression 2: switch.sh `set` case forwards ALL args to set_theme
#
# Bug: `set) shift; set_theme "$1"` dropped every flag after the theme
# name, so `dot theme set X --force` silently ignored --force and took
# the idempotent no-op path when X was already current.
# Fix: `set_theme "$@"` and `dot-theme-sync "$new_theme" "$@"`.
# ---------------------------------------------------------------------------
test_start "regression: 'set X --force' forwards --force to backend"
grep -q 'set_theme "$@"' "$SWITCH_SH"
_r1=$?
grep -q 'dot-theme-sync "$new_theme" "$@"' "$SWITCH_SH"
_r2=$?
if [[ $_r1 -eq 0 && $_r2 -eq 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \e[32m✓\e[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \e[31m✗\e[0m %s (arg forwarding lost from switch.sh)\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# Regression 3: reload_desktop helpers explicit `return 0`
#
# Bug: Under `set -e`, `_resolve_theme_wallpapers` ended with
# `[[ -z "$X" ]] && Y="$Z"`. If $X was set (test false), the whole
# function returned 1 and the caller's set -e killed the script.
# Fix: end every helper with an explicit `return 0`.
# ---------------------------------------------------------------------------
test_start "regression: _resolve_theme_wallpapers ends with 'return 0'"
awk '
  /^_resolve_theme_wallpapers\(\)/ { in_fn=1 }
  in_fn && /^}/ { print prev; exit }
  in_fn { prev = $0 }
' "$DOT_THEME_SYNC" | grep -q 'return 0'
if [[ $? -eq 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \e[32m✓\e[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \e[31m✗\e[0m %s (helper does not end with return 0)\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# Regression 4: wallpaper-sync.sh + apply-gnome-theme.sh both track mode
#
# Bug: `gsettings set org.gnome.desktop.screensaver picture-uri` was
# hard-coded to the light frame regardless of the theme's mode, so a
# dark theme showed a light lock screen.
# Fix: pick between light_wp and dark_wp based on $mode.
# ---------------------------------------------------------------------------
test_start "regression: wallpaper-sync.sh chooses dark_wp for lock screen"
grep -A5 'screensaver picture-uri' "$REPO_ROOT/scripts/theme/wallpaper-sync.sh" | grep -q '${dark_wp}'
if [[ $? -eq 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \e[32m✓\e[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \e[31m✗\e[0m %s (script does not pick dark_wp for dark mode)\n' "$CURRENT_TEST"
fi

test_start "regression: apply-gnome-theme.sh chooses dark_wp for lock screen"
grep -A5 'screensaver picture-uri' "$REPO_ROOT/scripts/theme/apply-gnome-theme.sh" | grep -q '${dark_wp}'
if [[ $? -eq 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \e[32m✓\e[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \e[31m✗\e[0m %s (script does not pick dark_wp for dark mode)\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# Regression 5: parallel reload orchestrator names its tempdir _pdir
#
# Bug: `_run_reloads_parallel` used `local dir=$(mktemp -d)` — variable
# name collided with `_resolve_gnome_shell_theme`'s `for dir in
# /usr/share/themes` loop, which leaked and redirected the status
# writes to ~/.local/share/themes/desktop.status.
# Fix: rename orchestrator var to `_pdir`.
# ---------------------------------------------------------------------------
test_start "regression: parallel orchestrator uses _pdir (not 'dir')"
grep -q '_pdir="\$(mktemp -d)"' "$DOT_THEME_SYNC"
if [[ $? -eq 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \e[32m✓\e[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \e[31m✗\e[0m %s (orchestrator var not renamed to _pdir)\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# Regression 6: DE detection prefers specific *:GNOME children over generic
#
# Bug: pattern order was `*gnome*)` before `*budgie*)`, so Budgie:GNOME
# resolved to "gnome" and lost the specific handler name.
# Fix: reorder — specific DEs (budgie/cinnamon/mate/unity) win first.
# ---------------------------------------------------------------------------
test_start "regression: _detect_linux_de case order — budgie before *gnome*"
budgie_line=$(grep -n '\*budgie\*)' "$DOT_THEME_SYNC" | head -1 | cut -d: -f1)
gnome_line=$(grep -n '\*gnome\*)' "$DOT_THEME_SYNC" | head -1 | cut -d: -f1)
if [[ -n "$budgie_line" && -n "$gnome_line" && "$budgie_line" -lt "$gnome_line" ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \e[32m✓\e[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \e[31m✗\e[0m %s (budgie no longer beats gnome in case order)\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# Regression 7: theme_value has typo-rejection guard
#
# Bug: `dot theme set Firewatch-drk` silently wrote the typo to
# .chezmoidata.toml and rendered configs against a missing theme
# section (falling back to template defaults), leaving a mixed
# half-applied state.
# Fix: existence check in write_theme.
# ---------------------------------------------------------------------------
test_start "regression: write_theme rejects unknown theme names"
awk '/^write_theme\(\)/,/^}/' "$DOT_THEME_SYNC" | grep -qE '_err[[:space:]]+"Unknown"[[:space:]]+"theme'
if [[ $? -eq 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \e[32m✓\e[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \e[31m✗\e[0m %s (existence guard removed from write_theme)\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# Regression 8: rebuild-themes.sh calls extract-heic-frames.sh on Linux
#
# Bug: HEIC-only wallpaper families couldn't render on GNOME (no HEIF
# pixbuf loader in Arch); DMS matugen couldn't decode Apple dynamic
# HEIC either. `dot theme set <family>` for those wallpapers left the
# desktop with an unrenderable URI.
# Fix: rebuild-themes.sh auto-runs extract-heic-frames.sh on Linux so
# paired PNGs exist before theme discovery.
# ---------------------------------------------------------------------------
test_start "regression: rebuild-themes.sh auto-extracts HEIC frames on Linux"
grep -q 'extract-heic-frames.sh' "$REPO_ROOT/scripts/theme/rebuild-themes.sh"
if [[ $? -eq 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \e[32m✓\e[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \e[31m✗\e[0m %s (HEIC hook removed)\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# Regression 9: dot-theme-sync has a source guard
#
# Bug: `dot theme status` sourced dot-theme-sync to reuse
# `_detect_linux_de`, but the sourced script ran `main` at load time,
# printing an entire theme-sync run inside the status dashboard.
# Fix: guard `main "$@"` behind BASH_SOURCE == $0 check.
# ---------------------------------------------------------------------------
test_start "regression: dot-theme-sync guards main against sourcing"
grep -q 'BASH_SOURCE\[0\]:-.*==.*0:-' "$DOT_THEME_SYNC"
if [[ $? -eq 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \e[32m✓\e[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \e[31m✗\e[0m %s (source guard removed)\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# Regression 10: history stack dedupes on re-entry
#
# Bug: naive prepend without dedupe would grow the history with the
# same theme appearing multiple times when the user cycled through a
# favourite family.
# Fix: `_record_theme_history` filters out prev from the existing tail
# before prepending, keeping the list unique.
# ---------------------------------------------------------------------------
test_start "regression: _record_theme_history filters existing entries"
awk '/^_record_theme_history\(\)/,/^}/' "$DOT_THEME_SYNC" | grep -q 'grep -Fxv'
if [[ $? -eq 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \e[32m✓\e[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \e[31m✗\e[0m %s (dedupe grep removed)\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
printf '  Tests: %d  \e[32mPassed: %d\e[0m  \e[31mFailed: %d\e[0m\n' \
  "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
