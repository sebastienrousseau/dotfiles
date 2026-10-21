#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# `dot system status` and the scheduled maintenance job, `dot system
# schedule list|set|run`. The job runs `dot system schedule run` from a
# systemd user timer on Linux or a launchd agent on macOS: `set` writes and
# loads it, `set off` unloads and deletes it, and `run` records its time
# and exit code under $XDG_STATE_HOME/dot/system.
#
# launchctl, systemctl, the OS, the job directories and the dot that the
# job runs come from DOT_LAUNCHCTL, DOT_SYSTEMCTL, DOT_SYSTEM_OS,
# DOT_LAUNCH_AGENTS, DOT_SYSTEMD_USER and DOT_SYSTEM_DOT, so tests never
# touch the real agents.
# Sourced by scripts/dot/commands/system.sh; inherits set -euo pipefail.
# Bash 3.2 compatible (macOS /bin/bash).

[[ -n "${_DOT_SYSTEM_LOADED:-}" ]] && return 0
_DOT_SYSTEM_LOADED=1

DOT_SYSTEM_LABEL="com.sebastienrousseau.dot-maintenance"
DOT_SYSTEM_UNIT="dot-maintenance"

_dot_system_state() { printf '%s' "${XDG_STATE_HOME:-$HOME/.local/state}/dot/system"; }
_dot_system_os() { printf '%s' "${DOT_SYSTEM_OS:-$(uname -s)}"; }
_dot_system_plist() { printf '%s/%s.plist' "${DOT_LAUNCH_AGENTS:-$HOME/Library/LaunchAgents}" "$DOT_SYSTEM_LABEL"; }
_dot_system_unit_dir() { printf '%s' "${DOT_SYSTEMD_USER:-${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user}"; }
_dot_system_dot() { printf '%s' "${DOT_SYSTEM_DOT:-$(resolve_source_dir)/bin/dot}"; }
_dot_system_path() { printf '%s' "$HOME/.local/share/mise/shims:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"; }
_dot_launchctl() { "${DOT_LAUNCHCTL:-launchctl}" "$@"; }
_dot_systemctl() { "${DOT_SYSTEMCTL:-systemctl}" --user "$@"; }

# _dot_system_backend: launchd, systemd, or nothing (and status 1) on a
# system with neither.
_dot_system_backend() {
  case "$(_dot_system_os)" in
    Darwin) printf 'launchd' ;;
    Linux)
      command -v "${DOT_SYSTEMCTL:-systemctl}" >/dev/null 2>&1 || return 1
      printf 'systemd'
      ;;
    *) return 1 ;;
  esac
}

# dot_system_schedule: the schedule `set` recorded (weekly, daily or off).
dot_system_schedule() {
  local f
  f="$(_dot_system_state)/schedule"
  if [[ -s "$f" ]]; then cat "$f"; else printf 'off'; fi
}

# dot_system_last_run: "<time> exit <code>" of the last run, or "never".
dot_system_last_run() {
  local f when rc
  f="$(_dot_system_state)/last-run"
  if [[ -s "$f" ]] && read -r when rc <"$f"; then
    printf '%s, exit %s' "$when" "$rc"
  else
    printf 'never'
  fi
}

# _dot_system_plist_body SCHEDULE: the launchd agent. A calendar interval
# missed while the Mac slept runs at the next wake.
_dot_system_plist_body() {
  local cal='<key>Hour</key><integer>10</integer><key>Minute</key><integer>0</integer>'
  [[ "$1" == daily ]] || cal="<key>Weekday</key><integer>0</integer>$cal"
  cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$DOT_SYSTEM_LABEL</string>
	<key>ProgramArguments</key>
	<array>
		<string>$(_dot_system_dot)</string>
		<string>system</string>
		<string>schedule</string>
		<string>run</string>
	</array>
	<key>EnvironmentVariables</key>
	<dict>
		<key>PATH</key>
		<string>$(_dot_system_path)</string>
	</dict>
	<key>StartCalendarInterval</key>
	<dict>$cal</dict>
	<key>ProcessType</key>
	<string>Background</string>
</dict>
</plist>
EOF
}

# _dot_system_units SCHEDULE: write the systemd service and timer.
_dot_system_units() {
  local dir
  dir="$(_dot_system_unit_dir)"
  mkdir -p "$dir"
  cat >"$dir/$DOT_SYSTEM_UNIT.service" <<EOF
[Unit]
Description=dot scheduled maintenance

[Service]
Type=oneshot
ExecStart=$(_dot_system_dot) system schedule run
Environment=PATH=$(_dot_system_path)
EOF
  cat >"$dir/$DOT_SYSTEM_UNIT.timer" <<EOF
[Unit]
Description=dot scheduled maintenance, $1

[Timer]
OnCalendar=$1
Persistent=true
RandomizedDelaySec=1h

[Install]
WantedBy=timers.target
EOF
}

# _dot_system_install BACKEND SCHEDULE: write the job and load it.
_dot_system_install() {
  local plist
  if [[ "$1" == launchd ]]; then
    plist="$(_dot_system_plist)"
    mkdir -p "${plist%/*}"
    _dot_system_plist_body "$2" >"$plist"
    _dot_launchctl bootout "gui/$(id -u)/$DOT_SYSTEM_LABEL" >/dev/null 2>&1 || true
    _dot_launchctl bootstrap "gui/$(id -u)" "$plist"
  else
    _dot_system_units "$2"
    _dot_systemctl daemon-reload
    _dot_systemctl enable --now "$DOT_SYSTEM_UNIT.timer"
  fi
}

# _dot_system_uninstall BACKEND: unload the job and delete it.
_dot_system_uninstall() {
  local dir
  if [[ "$1" == launchd ]]; then
    _dot_launchctl bootout "gui/$(id -u)/$DOT_SYSTEM_LABEL" >/dev/null 2>&1 || true
    rm -f "$(_dot_system_plist)"
  else
    dir="$(_dot_system_unit_dir)"
    _dot_systemctl disable --now "$DOT_SYSTEM_UNIT.timer" >/dev/null 2>&1 || true
    rm -f "$dir/$DOT_SYSTEM_UNIT.timer" "$dir/$DOT_SYSTEM_UNIT.service"
    _dot_systemctl daemon-reload
  fi
}

# dot_system_schedule_set weekly|daily|off: install, replace or remove the
# job and record the schedule. 1 for a bad word or no scheduler.
dot_system_schedule_set() {
  local when="${1:-}" backend dir
  case "$when" in
    weekly | daily | off) ;;
    *)
      printf 'Usage: dot system schedule set weekly|daily|off\n' >&2
      return 1
      ;;
  esac
  if ! backend="$(_dot_system_backend)"; then
    printf 'dot: scheduling needs launchd (macOS) or systemd (Linux)\n' >&2
    return 1
  fi
  if [[ "$when" == off ]]; then
    _dot_system_uninstall "$backend"
  else
    _dot_system_install "$backend" "$when"
  fi
  dir="$(_dot_system_state)"
  mkdir -p "$dir"
  printf '%s\n' "$when" >"$dir/schedule"
  printf 'Maintenance: %s (%s)\n' "$when" "$backend"
}

# _dot_system_loaded BACKEND: whether the job is loaded right now.
_dot_system_loaded() {
  if [[ "$1" == launchd ]]; then
    _dot_launchctl print "gui/$(id -u)/$DOT_SYSTEM_LABEL" >/dev/null 2>&1
  else
    _dot_systemctl is-enabled --quiet "$DOT_SYSTEM_UNIT.timer" >/dev/null 2>&1
  fi
}

# dot_system_schedule_list: the maintenance job, its schedule and state.
dot_system_schedule_list() {
  local backend state="not loaded"
  backend="$(_dot_system_backend)" || backend="none"
  if [[ "$backend" != none ]] && _dot_system_loaded "$backend"; then
    state="loaded"
  fi
  printf '%-14s %-8s %-8s %s\n' JOB WHEN RUNNER STATE
  printf '%-14s %-8s %-8s %s\n' maintenance "$(dot_system_schedule)" "$backend" "$state"
}

# _dot_system_step NAME COMMAND...: run one maintenance step into the log
# and report it; status 1 when it failed.
_dot_system_step() {
  local name="$1"
  shift
  printf '== %s\n' "$name" >>"$DOT_SYSTEM_LOG"
  if "$@" >>"$DOT_SYSTEM_LOG" 2>&1; then
    printf 'ok    %s\n' "$name"
  else
    printf 'fail  %s (see %s)\n' "$name" "$DOT_SYSTEM_LOG"
    return 1
  fi
}

# dot_system_schedule_run: every maintenance step, even after one fails;
# the time and exit code go to the state directory for `status`.
dot_system_schedule_run() {
  local dir rc=0
  dir="$(_dot_system_state)"
  mkdir -p "$dir"
  DOT_SYSTEM_LOG="$dir/last-run.log"
  : >"$DOT_SYSTEM_LOG"
  _dot_system_step "shell caches" "$(_dot_system_dot)" shell clean || rc=1
  _dot_system_step "log rotation" bash "$(resolve_source_dir)/scripts/tools/log-rotate.sh" || rc=1
  printf '%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$rc" >"$dir/last-run"
  return "$rc"
}

# _dot_system_os_name: the OS and its release.
_dot_system_os_name() {
  local name=""
  case "$(_dot_system_os)" in
    Darwin) name="macOS $(sw_vers -productVersion 2>/dev/null || true)" ;;
    Linux)
      # shellcheck source=/dev/null
      name="$(. /etc/os-release 2>/dev/null && printf '%s' "${PRETTY_NAME:-}")"
      ;;
  esac
  printf '%s' "${name:-$(_dot_system_os)}"
}

# dot_system_status: OS, free space in $HOME, schedule and last run.
dot_system_status() {
  local disk
  disk="$(df -Ph "$HOME" 2>/dev/null | awk 'NR == 2 { print $4 " free of " $2 }')"
  printf '%-10s %s\n' OS "$(_dot_system_os_name)"
  printf '%-10s %s\n' Disk "${disk:-unknown}"
  printf '%-10s %s\n' Schedule "$(dot_system_schedule)"
  printf '%-10s %s\n' "Last run" "$(dot_system_last_run)"
}
