#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Sourced by plugins/ai/libexec/ai.sh; inherits set -euo pipefail.
# `dot ai watch service on|off|status`: keep `dot-ai-tui watch` (dot ai
# watch) running from login, opt-in, as a launchd agent on macOS or a
# systemd user service on Linux. on writes and loads it, off unloads and
# deletes it, status (the default) says whether it is loaded. Restarted
# when it fails; a clean exit (SIGTERM, another watch already listening)
# stays down.
#
# The hook finds the watcher's socket under $XDG_RUNTIME_DIR, else $TMPDIR,
# so the launchd agent gets this shell's TMPDIR (macOS has no
# XDG_RUNTIME_DIR); the systemd user manager sets XDG_RUNTIME_DIR itself.
#
# launchctl, systemctl, the OS and the job directories come from
# DOT_LAUNCHCTL, DOT_SYSTEMCTL, DOT_SYSTEM_OS, DOT_LAUNCH_AGENTS and
# DOT_SYSTEMD_USER, as for `dot system schedule`, so tests never touch the
# real agents.
# Bash 3.2 compatible (macOS /bin/bash).

DOT_AI_WATCH_LABEL="com.sebastienrousseau.dot-ai-watch"
DOT_AI_WATCH_UNIT="dot-ai-watch.service"

_ai_watch_os() { printf '%s' "${DOT_SYSTEM_OS:-$(uname -s)}"; }
_ai_watch_plist() { printf '%s/%s.plist' "${DOT_LAUNCH_AGENTS:-$HOME/Library/LaunchAgents}" "$DOT_AI_WATCH_LABEL"; }
_ai_watch_unit() { printf '%s/%s' "${DOT_SYSTEMD_USER:-${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user}" "$DOT_AI_WATCH_UNIT"; }
_ai_watch_log() { printf '%s' "${XDG_STATE_HOME:-$HOME/.local/state}/dot/ai/watch.log"; }
_ai_watch_launchctl() { "${DOT_LAUNCHCTL:-launchctl}" "$@"; }
_ai_watch_systemctl() { "${DOT_SYSTEMCTL:-systemctl}" --user "$@"; }

# _ai_watch_backend: launchd, systemd, or nothing (and status 1).
_ai_watch_backend() {
  case "$(_ai_watch_os)" in
    Darwin) printf 'launchd' ;;
    Linux)
      command -v "${DOT_SYSTEMCTL:-systemctl}" >/dev/null 2>&1 || return 1
      printf 'systemd'
      ;;
    *) return 1 ;;
  esac
}

# _ai_watch_plist_body BIN: the launchd agent running BIN watch.
_ai_watch_plist_body() {
  local tmp="${TMPDIR:-$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null || true)}"
  cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>$DOT_AI_WATCH_LABEL</string>
	<key>ProgramArguments</key>
	<array>
		<string>$1</string>
		<string>watch</string>
	</array>
	<key>EnvironmentVariables</key>
	<dict>
		<key>TMPDIR</key>
		<string>$tmp</string>
	</dict>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<dict>
		<key>SuccessfulExit</key>
		<false/>
	</dict>
	<key>ThrottleInterval</key>
	<integer>30</integer>
	<key>StandardOutPath</key>
	<string>$(_ai_watch_log)</string>
	<key>StandardErrorPath</key>
	<string>$(_ai_watch_log)</string>
	<key>ProcessType</key>
	<string>Background</string>
</dict>
</plist>
EOF
}

# _ai_watch_unit_body BIN: the systemd user service running BIN watch.
_ai_watch_unit_body() {
  cat <<EOF
[Unit]
Description=dot ai watch: agent states, a notification when one is blocked

[Service]
ExecStart=$1 watch
Restart=on-failure
RestartSec=30

[Install]
WantedBy=default.target
EOF
}

# _ai_watch_on BACKEND BIN: write the job and load it.
_ai_watch_on() {
  local f
  if [[ "$1" == launchd ]]; then
    f="$(_ai_watch_plist)"
    mkdir -p "${f%/*}" "$(dirname "$(_ai_watch_log)")"
    _ai_watch_plist_body "$2" >"$f"
    _ai_watch_launchctl bootout "gui/$(id -u)/$DOT_AI_WATCH_LABEL" >/dev/null 2>&1 || true
    _ai_watch_launchctl bootstrap "gui/$(id -u)" "$f"
  else
    f="$(_ai_watch_unit)"
    mkdir -p "${f%/*}"
    _ai_watch_unit_body "$2" >"$f"
    _ai_watch_systemctl daemon-reload
    _ai_watch_systemctl enable --now "$DOT_AI_WATCH_UNIT"
  fi
}

# _ai_watch_off BACKEND: unload the job and delete it.
_ai_watch_off() {
  if [[ "$1" == launchd ]]; then
    _ai_watch_launchctl bootout "gui/$(id -u)/$DOT_AI_WATCH_LABEL" >/dev/null 2>&1 || true
    rm -f "$(_ai_watch_plist)"
  else
    _ai_watch_systemctl disable --now "$DOT_AI_WATCH_UNIT" >/dev/null 2>&1 || true
    rm -f "$(_ai_watch_unit)"
    _ai_watch_systemctl daemon-reload
  fi
}

# _ai_watch_loaded BACKEND: whether the job is loaded right now.
_ai_watch_loaded() {
  if [[ "$1" == launchd ]]; then
    _ai_watch_launchctl print "gui/$(id -u)/$DOT_AI_WATCH_LABEL" >/dev/null 2>&1
  else
    _ai_watch_systemctl is-enabled --quiet "$DOT_AI_WATCH_UNIT" >/dev/null 2>&1
  fi
}

# cmd_ai_watch_service [on|off|status]: 1 for a bad word, no service
# manager, or (for on) no cockpit binary.
cmd_ai_watch_service() {
  local word="${1:-status}" backend bin state=loaded
  case "$word" in
    on | off | status) ;;
    *)
      ui_err "Usage" "dot ai watch service on|off|status" >&2
      return 1
      ;;
  esac
  if ! backend="$(_ai_watch_backend)"; then
    ui_err "dot ai watch" "a service needs launchd (macOS) or systemd (Linux)" >&2
    return 1
  fi
  case "$word" in
    on)
      bin="$(command -v dot-ai-tui)" || {
        ui_err "dot ai watch" "needs the cockpit binary: DOTFILES_AI=1 chezmoi apply builds it (Go from mise)" >&2
        return 1
      }
      _ai_watch_on "$backend" "$bin"
      state=on
      ;;
    off)
      _ai_watch_off "$backend"
      state=off
      ;;
    status) _ai_watch_loaded "$backend" || state="not loaded" ;;
  esac
  printf 'dot ai watch: %s (%s)\n' "$state" "$backend"
}
