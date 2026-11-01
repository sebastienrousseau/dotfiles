#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck shell=bash
# Sourced by bin/dot before a write or destructive command (ADR-020 N17),
# and by plugins that lock a domain themselves; inherits set -euo pipefail.
#
# dot_lock <domain> — hold $XDG_STATE_HOME/dot/<domain>/lock for as long as
# this process runs. The lock is a symlink whose target is the holder's PID:
# `ln -s` creates it atomically on macOS and Linux, and there is no moment
# when it exists without naming its holder. bin/dot execs the command under
# the same PID, so the lock ends with the command, however it ends; a link
# naming a dead PID is stale, and the next run takes it over.
#
# A second run exits 75 (EX_TEMPFAIL, N10) naming the holder, or waits up to
# DOT_LOCK_WAIT seconds for it. DOT_LOCKED lists the domains this process
# and its parents hold, so a command that runs another `dot` command in the
# same domain does not wait on itself.

[[ "${_DOT_LOCK_LOADED:-0}" == "1" ]] && return 0
_DOT_LOCK_LOADED=1

# _dot_lock_alive PID: true while PID runs (kill -0 cannot signal another
# user's process; ps still sees it).
_dot_lock_alive() {
  [[ "$1" =~ ^[0-9]+$ ]] || return 1
  kill -0 "$1" 2>/dev/null || ps -p "$1" >/dev/null 2>&1
}

# _dot_lock_reclaim LINK HOLDER: remove LINK if it still names the dead
# HOLDER. It is renamed first, so a link another run made in the meantime
# is never removed: a renamed link that names someone else is put back
# with ln, which, unlike mv, cannot overwrite a lock taken since.
_dot_lock_reclaim() {
  local moved="$1.stale.$$" target
  mv -f "$1" "$moved" 2>/dev/null || return 0
  target="$(readlink "$moved" 2>/dev/null || true)"
  rm -f "$moved"
  [[ "$target" == "$2" ]] || ln -s "$target" "$1" 2>/dev/null || true
}

dot_lock() {
  local domain="$1" link holder ticks=0 limit="${DOT_LOCK_WAIT:-0}"
  [[ "$domain" =~ ^[a-z][a-z0-9-]*$ ]] || return 64
  case " ${DOT_LOCKED:-} " in *" $domain "*) return 0 ;; esac
  [[ "$limit" =~ ^[0-9]+$ ]] || limit=0
  link="${XDG_STATE_HOME:-$HOME/.local/state}/dot/$domain/lock"
  mkdir -p "${link%/*}" 2>/dev/null || return 0 # no state dir: run unlocked
  # Each pass takes the lock, reclaims a stale one or waits 0.2 s; a stale
  # link that cannot be removed counts as a wait, so the loop always ends.
  while ! ln -s "$$" "$link" 2>/dev/null; do
    holder="$(readlink "$link" 2>/dev/null || true)"
    if ((ticks > limit * 5)); then
      _dot_lock_busy "$domain" "$holder" "$link"
      return 75
    fi
    if [[ -n "$holder" ]] && ! _dot_lock_alive "$holder"; then
      _dot_lock_reclaim "$link" "$holder"
    else
      sleep 0.2
    fi
    ticks=$((ticks + 1))
  done
  export DOT_LOCKED="${DOT_LOCKED:+$DOT_LOCKED }$domain"
}

_dot_lock_busy() {
  printf 'dot %s: busy: PID %s holds %s (another dot %s command is running).\n' \
    "$1" "${2:-?}" "$3" "$1" >&2
  printf 'Run it again when that one ends, or wait for it with DOT_LOCK_WAIT=<seconds>.\n' >&2
}
