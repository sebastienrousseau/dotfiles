#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Behavioural tests for `dot theme ambient` time-of-day resolution.
# Exercises the sunrise/sunset resolution ladder, mode target
# computation, and the no-op / apply decision — without touching any
# real systemd timers.
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/cmd_test_helpers.sh"

SWITCH_SH="$REPO_ROOT/scripts/theme/switch.sh"

# --- Sandbox -----------------------------------------------------------------
TMPHOME="$(mktemp -d)"
trap 'rm -rf "$TMPHOME"' EXIT
export HOME="$TMPHOME"
export XDG_STATE_HOME="$TMPHOME/state"
export XDG_CONFIG_HOME="$TMPHOME/.config"
mkdir -p "$XDG_STATE_HOME/dot" "$XDG_CONFIG_HOME"

# Fake dotfiles source with two paired families so ambient has something
# to apply.
mkdir -p "$TMPHOME/dotfiles/.chezmoidata"
export CHEZMOI_SOURCE_DIR="$TMPHOME/dotfiles"
cat > "$TMPHOME/dotfiles/.chezmoidata.toml" <<'EOF'
theme = "Solar-dark"
EOF
cat > "$TMPHOME/dotfiles/.chezmoidata/themes.toml" <<'EOF'
[themes.Solar-dark]
mode = "dark"
family = "Solar"
[themes.Solar-light]
mode = "light"
family = "Solar"
EOF

# --- Mocks -------------------------------------------------------------------
MOCK_BIN="$TMPHOME/mocks"
mkdir -p "$MOCK_BIN"
export PATH="$MOCK_BIN:$PATH"
LOG="$TMPHOME/mock.log"

for cmd in gsettings kreadconfig6 kwriteconfig6 systemctl qdbus; do
  cat > "$MOCK_BIN/$cmd" <<EOF
#!/usr/bin/env bash
printf '$cmd %s\n' "\$*" >> "$LOG"
exit 0
EOF
  chmod +x "$MOCK_BIN/$cmd"
done

# dot-theme-sync mock — records theme name it was applied with.
cat > "$MOCK_BIN/dot-theme-sync" <<EOF
#!/usr/bin/env bash
printf 'dot-theme-sync %s\n' "\$*" >> "$LOG"
exit 0
EOF
chmod +x "$MOCK_BIN/dot-theme-sync"

_run() { ( bash "$SWITCH_SH" "$@" ); }
_reset_log() { : > "$LOG"; }

# ---------------------------------------------------------------------------
# Sunrise/sunset resolution ladder
# ---------------------------------------------------------------------------

test_start "ambient_uses_env_sunrise_when_set"
_reset_log
# Current theme is Solar-dark. Set sunrise = 00:00 so any current time
# is *after* sunrise. Sunset = 23:59 so we're always before sunset ->
# light target. Currently on dark -> switch expected.
out="$(DOT_THEME_SUNRISE=00:00 DOT_THEME_SUNSET=23:59 _run ambient run 2>&1)"
_contains "env sunrise=00:00" "$out" "labels env resolution"

test_start "ambient_default_labels_when_no_env"
_reset_log
out="$(unset DOT_THEME_SUNRISE DOT_THEME_SUNSET; _run ambient run 2>&1)"
_contains "defaults sunrise=07:00" "$out" "falls back to defaults"

test_start "ambient_sunwait_labels_when_location_and_binary_present"
_reset_log
# Mock sunwait to always return known times.
cat > "$MOCK_BIN/sunwait" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  list)
    case "$2" in
      rise) echo "06:00" ;;
      set)  echo "18:00" ;;
    esac
    ;;
esac
exit 0
EOF
chmod +x "$MOCK_BIN/sunwait"
out="$(unset DOT_THEME_SUNRISE DOT_THEME_SUNSET; \
       DOT_THEME_LOCATION="51.5N,0.13W" _run ambient run 2>&1)"
_contains "sunwait(51.5N,0.13W)" "$out" "labels sunwait resolution"
_contains "sunrise=06:00" "$out" "uses sunwait sunrise value"
_contains "sunset=18:00" "$out" "uses sunwait sunset value"

test_start "ambient_ignores_bad_sunwait_output"
_reset_log
# Sunwait returns garbage — should fall through to defaults, not blow up.
cat > "$MOCK_BIN/sunwait" <<'EOF'
#!/usr/bin/env bash
echo "not a time"
exit 0
EOF
chmod +x "$MOCK_BIN/sunwait"
out="$(unset DOT_THEME_SUNRISE DOT_THEME_SUNSET; \
       DOT_THEME_LOCATION="1N,1E" _run ambient run 2>&1)"
_contains "defaults sunrise=07:00" "$out" "falls through when sunwait output invalid"

# ---------------------------------------------------------------------------
# ambient status / enable / disable — units under XDG_CONFIG_HOME
# ---------------------------------------------------------------------------

test_start "ambient_enable_writes_service_and_timer_units"
_reset_log
_run ambient enable > /dev/null 2>&1
if [[ -f "$XDG_CONFIG_HOME/systemd/user/dot-theme-ambient.service" ]] \
   && [[ -f "$XDG_CONFIG_HOME/systemd/user/dot-theme-ambient.timer" ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s (units not written)\n' "$CURRENT_TEST"
fi

test_start "ambient_timer_has_hourly_reactivation_and_startup_delay"
grep -q "OnUnitActiveSec=1h" "$XDG_CONFIG_HOME/systemd/user/dot-theme-ambient.timer"
_r1=$?
grep -q "OnStartupSec=30" "$XDG_CONFIG_HOME/systemd/user/dot-theme-ambient.timer"
_r2=$?
grep -q "Persistent=true" "$XDG_CONFIG_HOME/systemd/user/dot-theme-ambient.timer"
_r3=$?
assert_equals 0 $((_r1 + _r2 + _r3)) "hourly + 30s + Persistent all present"

test_start "ambient_disable_removes_units"
_run ambient disable > /dev/null 2>&1
if [[ ! -f "$XDG_CONFIG_HOME/systemd/user/dot-theme-ambient.service" ]] \
   && [[ ! -f "$XDG_CONFIG_HOME/systemd/user/dot-theme-ambient.timer" ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

test_start "ambient_rejects_unknown_subcommand"
out="$(_run ambient rotate 2>&1)"
_contains "Unknown" "$out"

echo ""
printf '  Tests: %d  \033[0;32mPassed: %d\033[0m  \033[0;31mFailed: %d\033[0m\n' \
  "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
