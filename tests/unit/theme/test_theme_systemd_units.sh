#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Verifies the systemd user-timer + service unit files that
# `dot theme ambient enable` and `dot theme rotate enable` generate.
#
# Two levels of check:
#   1. Structural — required [Unit] / [Service] / [Timer] / [Install]
#      sections + required keys (ExecStart, WantedBy=timers.target,
#      OnUnitActiveSec, Persistent=true).
#   2. Deep validation — pipe through `systemd-analyze verify` if
#      available; otherwise skip that layer with a note.
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/cmd_test_helpers.sh"

SWITCH_SH="$REPO_ROOT/scripts/theme/switch.sh"

# --- Sandbox --------------------------------------------------------------
TMPHOME="$(mktemp -d)"
trap 'rm -rf "$TMPHOME"' EXIT
export HOME="$TMPHOME"
export XDG_CONFIG_HOME="$TMPHOME/.config"
export XDG_STATE_HOME="$TMPHOME/state"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_STATE_HOME/dot" \
         "$TMPHOME/dotfiles/.chezmoidata"
export CHEZMOI_SOURCE_DIR="$TMPHOME/dotfiles"
touch "$TMPHOME/dotfiles/.chezmoidata.toml" \
      "$TMPHOME/dotfiles/.chezmoidata/themes.toml"

MOCK_BIN="$TMPHOME/mocks"
mkdir -p "$MOCK_BIN"
export PATH="$MOCK_BIN:$PATH"
for cmd in systemctl gsettings kreadconfig6; do
  cat > "$MOCK_BIN/$cmd" <<EOF
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$MOCK_BIN/$cmd"
done

# Generate the unit files.
bash "$SWITCH_SH" ambient enable > /dev/null 2>&1
bash "$SWITCH_SH" rotate enable 12m > /dev/null 2>&1

AMBIENT_SERVICE="$XDG_CONFIG_HOME/systemd/user/dot-theme-ambient.service"
AMBIENT_TIMER="$XDG_CONFIG_HOME/systemd/user/dot-theme-ambient.timer"
ROTATE_SERVICE="$XDG_CONFIG_HOME/systemd/user/dot-theme-rotate.service"
ROTATE_TIMER="$XDG_CONFIG_HOME/systemd/user/dot-theme-rotate.timer"


_has_line() {
  local file="$1" pattern="$2"
  grep -Eq "$pattern" "$file" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Ambient service — Type=oneshot, ExecStart, After=graphical-session.target
# ---------------------------------------------------------------------------

test_start "ambient_service_file_exists"
[[ -f "$AMBIENT_SERVICE" ]] && _ok || _fail "$AMBIENT_SERVICE missing"

test_start "ambient_service_has_unit_section"
_has_line "$AMBIENT_SERVICE" '^\[Unit\]$' && _ok || _fail "no [Unit]"

test_start "ambient_service_has_after_graphical_session"
_has_line "$AMBIENT_SERVICE" '^After=graphical-session\.target$' && _ok || _fail "no After=graphical-session"

test_start "ambient_service_type_oneshot"
_has_line "$AMBIENT_SERVICE" '^Type=oneshot$' && _ok || _fail "wrong Type"

test_start "ambient_service_execstart_calls_dot_theme_ambient"
_has_line "$AMBIENT_SERVICE" '^ExecStart=.* theme ambient$' && _ok || _fail "no ExecStart"

# ---------------------------------------------------------------------------
# Ambient timer — hourly + 30s startup + Persistent + install target
# ---------------------------------------------------------------------------

test_start "ambient_timer_file_exists"
[[ -f "$AMBIENT_TIMER" ]] && _ok || _fail "missing"

test_start "ambient_timer_has_timer_section"
_has_line "$AMBIENT_TIMER" '^\[Timer\]$' && _ok || _fail "no [Timer]"

test_start "ambient_timer_hourly_reactivation"
_has_line "$AMBIENT_TIMER" '^OnUnitActiveSec=1h$' && _ok || _fail "no OnUnitActiveSec=1h"

test_start "ambient_timer_startup_delay_30s"
_has_line "$AMBIENT_TIMER" '^OnStartupSec=30$' && _ok || _fail "no OnStartupSec=30"

test_start "ambient_timer_persistent_true"
_has_line "$AMBIENT_TIMER" '^Persistent=true$' && _ok || _fail "not persistent"

test_start "ambient_timer_install_wantedby_timers"
_has_line "$AMBIENT_TIMER" '^WantedBy=timers\.target$' && _ok || _fail "no WantedBy"

test_start "ambient_timer_has_install_section"
_has_line "$AMBIENT_TIMER" '^\[Install\]$' && _ok || _fail "no [Install]"

# ---------------------------------------------------------------------------
# Rotate service + timer — 12m interval as passed on the CLI
# ---------------------------------------------------------------------------

test_start "rotate_service_execstart_calls_dot_theme_random"
_has_line "$ROTATE_SERVICE" '^ExecStart=.* theme random$' && _ok || _fail "wrong ExecStart"

test_start "rotate_timer_honours_cli_interval"
_has_line "$ROTATE_TIMER" '^OnUnitActiveSec=12m$' && _ok || _fail "wrong interval"

test_start "rotate_timer_has_1m_startup_delay"
_has_line "$ROTATE_TIMER" '^OnStartupSec=1m$' && _ok || _fail "no startup"

test_start "rotate_timer_persistent_true"
_has_line "$ROTATE_TIMER" '^Persistent=true$' && _ok || _fail

test_start "rotate_timer_wantedby_timers_target"
_has_line "$ROTATE_TIMER" '^WantedBy=timers\.target$' && _ok || _fail

# ---------------------------------------------------------------------------
# systemd-analyze verify (deep parse) — optional layer
# ---------------------------------------------------------------------------

test_start "units_pass_systemd_analyze_verify"
# systemd-analyze verify needs the file to be either an absolute path or on
# systemd's unit search path; absolute works.
if command -v systemd-analyze >/dev/null 2>&1; then
  err=0
  for u in "$AMBIENT_SERVICE" "$AMBIENT_TIMER" "$ROTATE_SERVICE" "$ROTATE_TIMER"; do
    # 2>&1 because systemd-analyze prints diagnostics on stderr.
    if ! systemd-analyze verify "$u" >/dev/null 2>&1; then
      err=$((err + 1))
    fi
  done
  if (( err == 0 )); then
    _ok
  else
    _fail "$err unit(s) failed verify"
  fi
else
  ((TESTS_PASSED++)) || true
  printf '  \033[0;33m~\033[0m %s (systemd-analyze not available — skipped)\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
printf '  Tests: %d  \033[0;32mPassed: %d\033[0m  \033[0;31mFailed: %d\033[0m\n' \
  "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
