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

# Keyed on HOME alone: the launchd auto-sync agent sees neither the shell's
# XDG_RUNTIME_DIR nor its TMPDIR, so either would split one lock in two.
_theme_txn_lock_root() {
  local root="${DOT_THEME_LOCK_ROOT:-$HOME/.local/state/dot}"
  printf '%s' "$root"
}

# _theme_txn_preference <new theme> <target theme> <--auto?>
# The appearance preference a run commits and later reads back. --auto always
# wins. A re-apply with no theme argument names no preference and writes none,
# so it must expect the stored one (e.g. "auto"), not the mode implied by the
# theme's name — that mismatch rolled back every bare --force. Uses
# current_theme_mode and _theme_mode_for_name from dot-theme-sync, which
# sources this file.
_theme_txn_preference() {
  if [[ "$3" == true ]]; then
    printf 'auto\n'
  elif [[ -z "$1" ]]; then
    current_theme_mode
  else
    _theme_mode_for_name "$2"
  fi
}

# emit_theme_plan <json?> <target> <preference> <operation id>
# Prints the pure --plan report through dot-theme-sync's JSON or human emitter.
emit_theme_plan() {
  local as_json="$1"
  shift
  if [[ "$as_json" == true ]]; then
    emit_theme_plan_json "$@"
  else
    emit_theme_plan_human "$@"
  fi
}

# _theme_nvim_scheme <theme>: the colourscheme to push to running Neovims.
# The palette scheme rendered for the active theme (colors/dotfiles.lua, the
# same Apple AAA colours as the terminal) wins over the theme's app.nvim.
# Uses theme_app_value from dot-theme-sync, which sources this file.
_theme_nvim_scheme() {
  if [[ -f "$HOME/.config/nvim/colors/dotfiles.lua" ]]; then
    printf 'dotfiles\n'
  else
    theme_app_value "$1" "nvim" 2>/dev/null || true
  fi
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

_theme_txn_owner_dead() {
  [[ -n "$1" ]] && ! kill -0 "$1" 2>/dev/null
}

# _theme_txn_reclaim_stale <lock dir> <dead pid>: clear a lock whose owner
# died. Several waiters can see the same dead owner, so one at a time: only
# the waiter whose mkdir of the .reclaim token succeeds goes on, and only
# while the dead PID still owns the lock (another waiter may have reclaimed
# it, and a new owner taken it, since this one read the PID). Nothing else
# removes a non-empty lock, so the checked lock is the one that is moved.
_theme_txn_reclaim_stale() {
  local lock_dir="$1" stale="$1.stale.$$"
  mkdir "$lock_dir/.reclaim" 2>/dev/null || return 1
  if [[ "$(_theme_txn_lock_owner_pid "$lock_dir")" != "$2" ]]; then
    rmdir "$lock_dir/.reclaim"
    return 1
  fi
  mv "$lock_dir" "$stale" && rm -rf "$stale"
}

# _theme_txn_reclaim_expired <lock dir> <owner pid>: once the wait is over,
# clear what no live process holds. A process can die in the tiny window
# between mkdir and writing owner: reclaim only an ownerless, empty
# directory (rmdir fails safely if a live contender has populated it in the
# meantime). A waiter killed mid-reclaim leaves its token behind under a
# dead owner: remove the token so the next pass can reclaim.
_theme_txn_reclaim_expired() {
  if [[ -z "$2" ]]; then
    rmdir "$1" 2>/dev/null
  else
    _theme_txn_owner_dead "$2" && rmdir "$1/.reclaim" 2>/dev/null
  fi
}

# _theme_txn_mkdir_private <mkdir args...>: mkdir under umask 077, in a
# subshell. A bare `umask 077` made every file the rest of dot-theme-sync
# wrote 0600.
_theme_txn_mkdir_private() {
  (umask 077 && mkdir "$@")
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
  _theme_txn_mkdir_private -p "$lock_root"
  lock_dir="$lock_root/dot-theme-${UID:-$(id -u)}.lock.d"
  started="$(date +%s)"

  while ! _theme_txn_mkdir_private "$lock_dir" 2>/dev/null; do
    owner_pid="$(_theme_txn_lock_owner_pid "$lock_dir")"
    if _theme_txn_owner_dead "$owner_pid" && _theme_txn_reclaim_stale "$lock_dir" "$owner_pid"; then
      continue
    fi
    now="$(date +%s)"
    if ((now - started >= timeout)); then
      if _theme_txn_reclaim_expired "$lock_dir" "$owner_pid"; then
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
  (
    umask 077
    {
      printf 'pid=%s\n' "$$"
      printf 'operation_id=%s\n' "$THEME_TXN_OPERATION_ID"
      printf 'started_at=%s\n' "$THEME_TXN_STARTED_AT"
    } >"$lock_dir/owner"
  )
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

# chezmoi records what it last wrote to each target and, on a later apply,
# asks before overwriting a target that no longer matches its record. The
# theme apply rewrites those records, so restoring the file snapshots alone
# leaves every restored target looking hand-edited, and the next apply with
# no terminal to ask on (dot upgrade) dies on the question. The transaction
# therefore snapshots the records for its targets with the files and puts
# them back on rollback.

# _theme_txn_chezmoi_records: chezmoi's records, one "<target>\t<JSON>"
# line each; nothing when chezmoi is not installed.
_theme_txn_chezmoi_records() {
  command -v chezmoi >/dev/null 2>&1 || return 0
  chezmoi state get-bucket --bucket=entryState 2>/dev/null | awk '
    /^  "/ { target = $0; sub(/^  "/, "", target); sub(/": \{$/, "", target); body = ""; next }
    /^  \},?$/ { if (target != "") print target "\t{" body "}"; target = ""; next }
    target != "" { sub(/^[ \t]+/, ""); sub(/,$/, ""); body = body (body == "" ? "" : ",") $0 }
  '
}

# _theme_txn_snapshot_chezmoi_records: the records for the manifest's
# targets, saved beside the file snapshots. Left absent when they could not
# be read, so the rollback leaves chezmoi's records alone rather than guess.
_theme_txn_snapshot_chezmoi_records() {
  local table="$THEME_TXN_OPERATION_DIR/chezmoi-records.tsv"
  command -v chezmoi >/dev/null 2>&1 || return 0
  if ! _theme_txn_chezmoi_records | awk -F'\t' '
    FILENAME == ARGV[1] { want[$4] = 1; next }
    ($1 in want)
  ' "$THEME_TXN_MANIFEST" - >"$table"; then
    rm -f "$table"
  fi
}

# _theme_txn_chezmoi_record_changes: "set\t<target>\t<saved record>" for
# each manifest target whose record the apply changed, "delete\t<target>"
# for one the apply recorded that had no record before.
_theme_txn_chezmoi_record_changes() {
  local table="$THEME_TXN_OPERATION_DIR/chezmoi-records.tsv"
  _theme_txn_chezmoi_records | awk -F'\t' -v OFS='\t' '
    FILENAME == ARGV[1] { want[$4] = 1; next }
    FILENAME == ARGV[2] { before[$1] = $2; next }
    ($1 in want) { after[$1] = $2 }
    END {
      for (target in want) {
        if (target in before) {
          if (before[target] != after[target]) print "set", target, before[target]
        } else if (target in after) {
          print "delete", target
        }
      }
    }
  ' "$THEME_TXN_MANIFEST" "$table" -
}

# _theme_txn_restore_chezmoi_records: put the saved records back, naming
# each target still recorded as the failed apply wrote it. Fails when any.
_theme_txn_restore_chezmoi_records() {
  local table="$THEME_TXN_OPERATION_DIR/chezmoi-records.tsv" action target record failed=0
  [[ -f "$table" ]] && command -v chezmoi >/dev/null 2>&1 || return 0
  while IFS=$'\t' read -r action target record; do
    [[ -n "$target" ]] || continue
    if [[ "$action" == set ]]; then
      chezmoi state set --bucket=entryState --key="$target" --value="$record" 2>/dev/null && continue
    else
      chezmoi state delete --bucket=entryState --key="$target" 2>/dev/null && continue
    fi
    failed=$((failed + 1))
    printf 'dot-theme-sync: chezmoi still records the failed apply for %s\n' "$target" >&2
  done < <(_theme_txn_chezmoi_record_changes)
  [[ "$failed" -eq 0 ]]
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
  # Private dirs: everything the transaction writes lives inside them.
  if ! _theme_txn_mkdir_private -p "$root"; then
    _theme_txn_release_lock
    return 1
  fi
  THEME_TXN_OPERATION_DIR="$root/$THEME_TXN_OPERATION_ID"
  if ! _theme_txn_mkdir_private "$THEME_TXN_OPERATION_DIR" 2>/dev/null; then
    printf 'dot-theme-sync: operation directory already exists: %s\n' "$THEME_TXN_OPERATION_DIR" >&2
    _theme_txn_release_lock
    return 1
  fi
  if ! _theme_txn_mkdir_private "$THEME_TXN_OPERATION_DIR/snapshots"; then
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
  _theme_txn_snapshot_chezmoi_records
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
  elif ! _theme_txn_restore_chezmoi_records; then
    reason="$reason; chezmoi records not restored, run chezmoi apply to review"
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
