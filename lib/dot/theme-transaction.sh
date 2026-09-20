#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Portable transaction primitives for dot-theme-sync.
# Sourced by dot-theme-sync; inherits set -euo pipefail

# This file is sourced by bin/dot-theme-sync. Keep it compatible with the
# Bash 3.2 shipped by macOS: no associative arrays, mapfile, or declare -g.

THEME_TXN_SCHEMA_VERSION="1.0"
THEME_TXN_ACTIVE=0
THEME_TXN_FINALIZED=0
THEME_TXN_LOCK_DIR=""
THEME_TXN_OPERATION_DIR=""
THEME_TXN_OPERATION_ID=""
THEME_TXN_MANIFEST=""
THEME_TXN_STARTED_AT=""
THEME_TXN_PREVIOUS=""
THEME_TXN_DESIRED=""
THEME_TXN_PREFERENCE=""

_theme_txn_json_escape() {
  local value="${1:-}"
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  value=${value//$'\r'/\\r}
  value=${value//$'\t'/\\t}
  printf '%s' "$value"
}

_theme_txn_now() {
  date -u '+%Y-%m-%dT%H:%M:%SZ'
}

_theme_txn_new_id() {
  printf 'theme-%s-%s-%s' "$(date -u '+%Y%m%dT%H%M%SZ')" "$$" "${RANDOM:-0}"
}

_theme_txn_state_root() {
  printf '%s' "${DOT_THEME_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/dot/theme-transactions}"
}

_theme_txn_lock_root() {
  local root="${DOT_THEME_LOCK_ROOT:-${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}}"
  printf '%s' "$root"
}

_theme_txn_hash() {
  local path="${1:-}"
  [[ -f "$path" ]] || return 0
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$path" | awk '{print $1}'
  else
    shasum -a 256 "$path" | awk '{print $1}'
  fi
}

_theme_txn_lock_owner_pid() {
  local owner_file="$1/owner"
  [[ -f "$owner_file" ]] || return 0
  sed -n 's/^pid=//p' "$owner_file" | head -1
}

_theme_txn_acquire_lock() {
  local timeout="${1:-${DOT_THEME_LOCK_TIMEOUT:-10}}"
  local lock_root lock_dir started now owner_pid
  case "$timeout" in
    '' | *[!0-9]*)
      printf 'dot-theme-sync: invalid lock timeout: %s\n' "$timeout" >&2
      return 2
      ;;
  esac

  lock_root="$(_theme_txn_lock_root)"
  umask 077
  mkdir -p "$lock_root"
  lock_dir="$lock_root/dot-theme-${UID:-$(id -u)}.lock.d"
  started="$(date +%s)"

  while ! mkdir "$lock_dir" 2>/dev/null; do
    owner_pid="$(_theme_txn_lock_owner_pid "$lock_dir")"
    if [[ -n "$owner_pid" ]] && ! kill -0 "$owner_pid" 2>/dev/null; then
      rm -f "$lock_dir/owner"
      rmdir "$lock_dir" 2>/dev/null || true
      continue
    fi
    now="$(date +%s)"
    if ((now - started >= timeout)); then
      # A process can die in the tiny window between mkdir and writing owner.
      # Reclaim only an ownerless, empty directory; rmdir fails safely if a
      # live contender has populated it in the meantime.
      if [[ -z "$owner_pid" ]] && rmdir "$lock_dir" 2>/dev/null; then
        continue
      fi
      printf 'dot-theme-sync: theme operation is locked' >&2
      [[ -n "$owner_pid" ]] && printf ' by PID %s' "$owner_pid" >&2
      printf '\n' >&2
      return 1
    fi
    sleep 1
  done

  THEME_TXN_LOCK_DIR="$lock_dir"
  {
    printf 'pid=%s\n' "$$"
    printf 'operation_id=%s\n' "$THEME_TXN_OPERATION_ID"
    printf 'started_at=%s\n' "$THEME_TXN_STARTED_AT"
  } >"$lock_dir/owner"
}

_theme_txn_release_lock() {
  [[ -n "$THEME_TXN_LOCK_DIR" ]] || return 0
  local owner_pid
  owner_pid="$(_theme_txn_lock_owner_pid "$THEME_TXN_LOCK_DIR")"
  if [[ -z "$owner_pid" || "$owner_pid" == "$$" ]]; then
    rm -f "$THEME_TXN_LOCK_DIR/owner"
    rmdir "$THEME_TXN_LOCK_DIR" 2>/dev/null || true
  fi
  THEME_TXN_LOCK_DIR=""
}

_theme_txn_snapshot_targets() {
  local index=0 path target_type hash snapshot
  : >"$THEME_TXN_MANIFEST"
  for path in "$@"; do
    [[ -n "$path" ]] || continue
    index=$((index + 1))
    target_type="absent"
    # A non-empty sentinel keeps Bash 3.2's whitespace-IFS reader from
    # collapsing the empty field and shifting paths into the hash column.
    hash="-"
    snapshot=""
    if [[ -L "$path" ]]; then
      target_type="symlink"
      snapshot="$THEME_TXN_OPERATION_DIR/snapshots/$index"
      readlink "$path" >"$snapshot" || return 1
    elif [[ -f "$path" ]]; then
      target_type="file"
      hash="$(_theme_txn_hash "$path")"
      snapshot="$THEME_TXN_OPERATION_DIR/snapshots/$index"
      cp -p "$path" "$snapshot" || return 1
    fi
    printf '%s\t%s\t%s\t%s\n' "$index" "$target_type" "$hash" "$path" >>"$THEME_TXN_MANIFEST"
  done
}

_theme_txn_begin() {
  local previous="$1" desired="$2" preference="$3" timeout="$4"
  shift 4

  THEME_TXN_OPERATION_ID="${DOT_THEME_OPERATION_ID:-$(_theme_txn_new_id)}"
  if [[ -z "$THEME_TXN_OPERATION_ID" || ${#THEME_TXN_OPERATION_ID} -gt 128 || "$THEME_TXN_OPERATION_ID" =~ [^a-zA-Z0-9._-] ]]; then
    printf 'dot-theme-sync: invalid operation ID\n' >&2
    return 2
  fi
  THEME_TXN_STARTED_AT="$(_theme_txn_now)"
  THEME_TXN_PREVIOUS="$previous"
  THEME_TXN_DESIRED="$desired"
  THEME_TXN_PREFERENCE="$preference"

  _theme_txn_acquire_lock "$timeout" || return $?

  local root
  root="$(_theme_txn_state_root)"
  umask 077
  if ! mkdir -p "$root"; then
    _theme_txn_release_lock
    return 1
  fi
  THEME_TXN_OPERATION_DIR="$root/$THEME_TXN_OPERATION_ID"
  if ! mkdir "$THEME_TXN_OPERATION_DIR" 2>/dev/null; then
    printf 'dot-theme-sync: operation directory already exists: %s\n' "$THEME_TXN_OPERATION_DIR" >&2
    _theme_txn_release_lock
    return 1
  fi
  if ! mkdir "$THEME_TXN_OPERATION_DIR/snapshots"; then
    rmdir "$THEME_TXN_OPERATION_DIR" 2>/dev/null || true
    _theme_txn_release_lock
    return 1
  fi
  THEME_TXN_MANIFEST="$THEME_TXN_OPERATION_DIR/manifest.tsv"
  if ! _theme_txn_snapshot_targets "$@"; then
    rm -rf "$THEME_TXN_OPERATION_DIR"
    _theme_txn_release_lock
    return 1
  fi
  THEME_TXN_ACTIVE=1
}

_theme_txn_restore_files() {
  [[ -f "$THEME_TXN_MANIFEST" ]] || return 0
  local index target_type before_hash path snapshot restore_tmp link_target
  while IFS=$'\t' read -r index target_type before_hash path; do
    [[ -n "$path" ]] || continue
    snapshot="$THEME_TXN_OPERATION_DIR/snapshots/$index"
    case "$target_type" in
      file)
        [[ -f "$snapshot" ]] || return 1
        mkdir -p "$(dirname "$path")"
        restore_tmp="$(umask 077 && mktemp "$(dirname "$path")/.dot-theme-restore.XXXXXX")"
        cp -p "$snapshot" "$restore_tmp"
        mv "$restore_tmp" "$path"
        if [[ "$before_hash" != "-" && "$(_theme_txn_hash "$path")" != "$before_hash" ]]; then
          return 1
        fi
        ;;
      symlink)
        [[ -f "$snapshot" ]] || return 1
        link_target="$(cat "$snapshot")"
        mkdir -p "$(dirname "$path")"
        rm -f "$path"
        ln -s "$link_target" "$path"
        ;;
      absent) rm -f "$path" ;;
      *) return 1 ;;
    esac
  done < <(awk '{ lines[NR]=$0 } END { for (i=NR; i>=1; i--) print lines[i] }' "$THEME_TXN_MANIFEST")
}

_theme_txn_write_journal() {
  local status="$1" reason="${2:-}" completed_at journal tmp
  completed_at="$(_theme_txn_now)"
  journal="$THEME_TXN_OPERATION_DIR/journal.json"
  tmp="$journal.tmp"
  {
    printf '{\n'
    printf '  "schema_version": "%s",\n' "$THEME_TXN_SCHEMA_VERSION"
    printf '  "operation_id": "%s",\n' "$(_theme_txn_json_escape "$THEME_TXN_OPERATION_ID")"
    printf '  "kind": "theme.apply",\n'
    printf '  "status": "%s",\n' "$(_theme_txn_json_escape "$status")"
    printf '  "started_at": "%s",\n' "$THEME_TXN_STARTED_AT"
    printf '  "completed_at": "%s",\n' "$completed_at"
    printf '  "previous_theme": "%s",\n' "$(_theme_txn_json_escape "$THEME_TXN_PREVIOUS")"
    printf '  "desired_theme": "%s",\n' "$(_theme_txn_json_escape "$THEME_TXN_DESIRED")"
    printf '  "preference": "%s",\n' "$(_theme_txn_json_escape "$THEME_TXN_PREFERENCE")"
    printf '  "manifest": "manifest.tsv",\n'
    printf '  "reason": "%s"\n' "$(_theme_txn_json_escape "$reason")"
    printf '}\n'
  } >"$tmp"
  mv "$tmp" "$journal"
}

_theme_txn_prune() {
  local root keep="${DOT_THEME_TRANSACTION_RETENTION:-20}"
  root="$(_theme_txn_state_root)"
  case "$keep" in '' | *[!0-9]*) keep=20 ;; esac
  [[ "$keep" -gt 0 ]] || keep=1
  [[ -d "$root" ]] || return 0
  local stale count=0
  while IFS= read -r stale; do
    [[ -n "$stale" && "$stale" == "$root"/theme-* ]] || continue
    count=$((count + 1))
    [[ "$count" -le "$keep" ]] || rm -rf "$stale"
  done < <(
    for stale in "$root"/theme-*; do
      [[ -d "$stale" ]] && printf '%s\n' "$stale"
    done | sort -r
  )
}

_theme_txn_finalize() {
  local status="${1:-succeeded}" reason="${2:-}"
  [[ "$THEME_TXN_ACTIVE" == "1" ]] || return 0
  _theme_txn_write_journal "$status" "$reason"
  THEME_TXN_FINALIZED=1
  THEME_TXN_ACTIVE=0
  _theme_txn_release_lock
  _theme_txn_prune
}

_theme_txn_rollback() {
  local reason="${1:-operation failed}"
  [[ "$THEME_TXN_ACTIVE" == "1" ]] || return 0
  local rollback_status="rolled_back"
  if ! _theme_txn_restore_files; then
    rollback_status="rollback_failed"
  fi
  _theme_txn_write_journal "$rollback_status" "$reason" || true
  THEME_TXN_FINALIZED=1
  THEME_TXN_ACTIVE=0
  _theme_txn_release_lock
  _theme_txn_prune
  [[ "$rollback_status" == "rolled_back" ]]
}

_theme_txn_exit_guard() {
  local status="${1:-1}"
  if [[ "$THEME_TXN_ACTIVE" == "1" && "$THEME_TXN_FINALIZED" != "1" ]]; then
    _theme_txn_rollback "process exited with status $status" || true
  else
    _theme_txn_release_lock
  fi
}
