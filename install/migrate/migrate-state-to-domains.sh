#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# migrate-state-to-domains.sh: move the dot CLI's state from
# $XDG_STATE_HOME/dotfiles/ to the per-domain directories of ADR-020 N12,
# $XDG_STATE_HOME/dot/<domain>/. Run once per host, before `chezmoi apply`
# (defaults/run_before_migrate-state.sh.tmpl and install.sh
# run it); safe to run again.
#
#   bash install/migrate/migrate-state-to-domains.sh [--dry-run] [--verbose]
#
# Every move is recorded in a manifest, so rollback-state-to-domains.sh can
# put each entry back. A directory whose destination exists is merged entry
# by entry; a log whose destination exists is prepended to it. Any other
# entry whose name is taken keeps the new one, and the old one is set aside
# in dot/cli/migrations/superseded/ at its old path. An entry it cannot
# move yet (the AI gateway while it runs, a move that fails) stays where it
# is, and the run is not marked done, so the next apply tries again. The old directory keeps v0_2_503-migration, which its
# own script reads, and anything this script does not know.
#
# Exit codes: 0 done, already done or nothing to move; 1 bad usage;
# 3 something was left behind (listed on stderr).

set -euo pipefail

STATE="${XDG_STATE_HOME:-$HOME/.local/state}"
OLD="$STATE/dotfiles"
NEW="$STATE/dot"
MARKER="$NEW/cli/migrations/state-domains.done"
MANIFEST="$NEW/cli/migrations/state-domains.manifest"
SUPERSEDED="$NEW/cli/migrations/superseded"

# Legacy name, then its path under $NEW. dot.log, metrics.jsonl and
# agent-sessions.jsonl predate log.v1 and are kept, unread, in cli/legacy.
MAP=(
  checkpoints agent/checkpoints
  snapshots config/snapshots
  update config/update
  attestations attest/attestations
  fleet fleet
  ai-serve ai/serve
  registry cli/registry
  eval-timings.jsonl shell/eval-timings.jsonl
  debug.log shell/debug.log
  audit-bypass.log security/audit-bypass.log
  security-audit.log security/security-audit.log
  security-report.md security/security-report.md
  rollback.log doctor/rollback.log
  heal.log doctor/heal.log
  orphans doctor/orphans
  icloud-symlinks.log system/icloud-symlinks.log
  dot.log cli/legacy/dot.log
  metrics.jsonl cli/legacy/metrics.jsonl
  agent-sessions.jsonl cli/legacy/agent-sessions.jsonl
)

DRY_RUN=0
VERBOSE=0
LEFT=0

usage() {
  sed -n '5,13p' "$0" | sed 's/^# \{0,1\}//'
}

say() {
  [[ "$VERBOSE" == 1 || "$DRY_RUN" == 1 ]] || return 0
  printf 'migrate-state: %s\n' "$*"
}

left() {
  printf 'migrate-state: left %s: %s\n' "$1" "$2" >&2
  LEFT=1
}

# private_dir DIR...: mkdir -p, every directory it makes 0700 (mkdir -m
# would set only the deepest).
private_dir() {
  (umask 077 && mkdir -p "$@")
}

# record SRC DST: one manifest line per completed move.
record() {
  printf '%s\t%s\n' "$1" "$2" >>"$MANIFEST"
}

# serve_running DIR: true when DIR/serve.pid names a live process.
serve_running() {
  local pid
  pid="$(cat "$1/serve.pid" 2>/dev/null || true)"
  [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null
}

# move_new SRC DST: DST does not exist yet. A move that fails is left, and
# the rest still run.
move_new() {
  say "move $1 -> $2"
  [[ "$DRY_RUN" == 0 ]] || return 0
  if private_dir "$(dirname "$2")" && mv "$1" "$2"; then
    record "$1" "$2"
  else
    left "$1" "could not move it to $2"
  fi
}

# supersede SRC DST: DST's name is taken, and DST is kept. SRC moves to its
# old path under $SUPERSEDED, a move the manifest records for rollback.
supersede() {
  local aside="$SUPERSEDED/${1#"$OLD"/}"
  if [[ -e "$aside" || -L "$aside" ]]; then
    left "$1" "$2 exists, and so does $aside"
    return 0
  fi
  move_new "$1" "$aside"
  [[ "$DRY_RUN" == 1 || -e "$1" || -L "$1" ]] ||
    printf 'migrate-state: superseded %s: kept %s, the old one is in %s\n' "$1" "$2" "$aside" >&2
}

# merge_dir SRC DST: move each entry of SRC that DST lacks; set aside the
# rest.
merge_dir() {
  local entry name
  for entry in "$1"/* "$1"/.[!.]*; do
    [[ -e "$entry" || -L "$entry" ]] || continue
    name="${entry##*/}"
    if [[ -e "$2/$name" ]]; then
      supersede "$entry" "$2/$name"
    else
      move_new "$entry" "$2/$name"
    fi
  done
  [[ "$DRY_RUN" == 1 ]] || rmdir "$1" 2>/dev/null || true
}

# merge_log SRC DST: the old lines go first, then the file is gone. The
# merged file is written over a copy of DST, so it keeps DST's mode.
merge_log() {
  local tmp="$2.migrate.$$"
  say "prepend $1 -> $2"
  [[ "$DRY_RUN" == 0 ]] || return 0
  if cp -p "$2" "$tmp" && cat "$1" "$2" >"$tmp" && mv -f "$tmp" "$2" && rm -f "$1"; then
    printf '%s\t%s\tprepended\n' "$1" "$2" >>"$MANIFEST"
  else
    rm -f "$tmp"
    left "$1" "could not prepend it to $2"
  fi
}

# merge_existing NAME SRC DST: DST exists; merge SRC into it if it can.
merge_existing() {
  if [[ -d "$2" && -d "$3" ]]; then
    merge_dir "$2" "$3"
  elif [[ -f "$2" && -f "$3" && ("$1" == *.log || "$1" == *.jsonl) ]]; then
    merge_log "$2" "$3"
  else
    supersede "$2" "$3"
  fi
}

# migrate_one NAME PATH: move $OLD/NAME to $NEW/PATH.
migrate_one() {
  local src="$OLD/$1" dst="$NEW/$2"
  [[ -e "$src" || -L "$src" ]] || return 0
  if [[ "$1" == ai-serve ]] && serve_running "$src"; then
    left "$src" "the AI gateway is running; stop it with dot-ai-proxy stop"
  elif [[ -e "$dst" || -L "$dst" ]]; then
    merge_existing "$1" "$src" "$dst"
  else
    move_new "$src" "$dst"
  fi
}

# parse_args ARG...: set DRY_RUN and VERBOSE; --help prints the usage and
# exits 0, an unknown option exits 1.
parse_args() {
  local arg
  for arg in "$@"; do
    case "$arg" in
      --dry-run | -n) DRY_RUN=1 ;;
      --verbose | -v) VERBOSE=1 ;;
      --help | -h)
        usage
        exit 0
        ;;
      *)
        printf 'migrate-state: unknown option %s\n' "$arg" >&2
        exit 1
        ;;
    esac
  done
}

main() {
  local i
  parse_args "$@"
  [[ ! -e "$MARKER" ]] || return 0
  [[ "$DRY_RUN" == 1 ]] || private_dir "$(dirname "$MARKER")"
  if [[ -d "$OLD" ]]; then
    for ((i = 0; i < ${#MAP[@]}; i += 2)); do
      migrate_one "${MAP[i]}" "${MAP[i + 1]}"
    done
  fi
  [[ "$LEFT" == 0 ]] || return 3
  [[ "$DRY_RUN" == 1 ]] || date -u +%Y-%m-%dT%H:%M:%SZ >"$MARKER"
}

main "$@"
