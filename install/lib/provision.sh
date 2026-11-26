#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# install/lib/provision.sh — run the install/provision scripts on change.
#
# Sourced by install.sh --provision. run_provision runs a script only when
# its content (a template's rendered output) differs from the content of
# its last successful run, as chezmoi's run_onchange_ does; --all runs them
# all. Each script's last exit status is written to the status file, and a
# failure fails the whole run once every script has had its turn.
#
# State, under ${XDG_STATE_HOME:-$HOME/.local/state}/dot/provision:
#   hashes  "<script> <sha256>" of each script's last successful run
#   status  "<script> <exit status|skipped>" from the latest run

_provision_state_dir() {
  printf '%s/dot/provision' "${XDG_STATE_HOME:-$HOME/.local/state}"
}

_provision_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum <"$1" | awk '{print $1}'
  else
    shasum -a 256 <"$1" | awk '{print $1}'
  fi
}

# _provision_runnable <script> <work>: the path to run: a template is
# rendered by chezmoi into <work>; any other script runs in place, so it
# can still find the repo from its own path.
_provision_runnable() {
  if [[ "$1" == *.tmpl ]]; then
    chezmoi execute-template <"$1" >"$2/run.sh" || return 1
    printf '%s' "$2/run.sh"
  else
    printf '%s' "$1"
  fi
}

# _provision_recorded <hashes> <name>: the hash of <name>'s last success.
_provision_recorded() {
  [[ -f "$1" ]] || return 0
  awk -v n="$2" '$1 == n { print $2 }' "$1"
}

# _provision_record <hashes> <name> <hash>: replace <name>'s entry.
_provision_record() {
  local tmp="$1.tmp.$$"
  { [[ ! -f "$1" ]] || awk -v n="$2" '$1 != n' "$1"; } >"$tmp"
  printf '%s %s\n' "$2" "$3" >>"$tmp"
  mv "$tmp" "$1"
}

# _provision_scripts <dir>: the numbered run_onchange_* in order, then the
# run_once_install_* shell scripts, one path per line. The shell scripts make
# zsh or fish the login shell, so they run once the package scripts have
# installed it: run first, they found no zsh on Linux and, being run-once,
# never set it.
_provision_scripts() {
  local f pattern
  for pattern in "run_onchange_*" "run_once_install_*"; do
    for f in "$1"/$pattern; do
      [[ -f "$f" ]] && printf '%s\n' "$f"
    done | LC_ALL=C sort
  done
}

# _provision_one <script> <state_dir> <all> <work>: run one script unless
# it is unchanged (and <all> is 0). Sets _PROVISION_RESULT to "skipped"
# or its exit status (1 when a template cannot be rendered); fails when
# the script did.
_provision_one() {
  local script="$1" state="$2" all="$3" name run hash
  name="$(basename "$script")"
  _PROVISION_RESULT=1
  if ! run="$(_provision_runnable "$script" "$4")"; then
    echo "     ($name could not be rendered)" >&2
    return 1
  fi
  hash="$(_provision_sha256 "$run")"
  if [[ "$all" != 1 && "$hash" == "$(_provision_recorded "$state/hashes" "$name")" ]]; then
    _PROVISION_RESULT=skipped
    return 0
  fi
  echo "   → $name"
  _PROVISION_RESULT=0
  DOTFILES_SOURCE_DIR="$_PROVISION_SOURCE" bash "$run" || _PROVISION_RESULT=$?
  [[ $_PROVISION_RESULT -eq 0 ]] || return 1
  _provision_record "$state/hashes" "$name" "$hash"
}

# _provision_report <failed>: name each failed script (one per line).
_provision_report() {
  printf 'Provisioning failed for:\n%s' "$1" >&2
  return 1
}

# run_provision <source_dir> [--all]: run the source's provisioning
# scripts. Returns non-zero, after naming each one, if any script failed.
# Scripts keep the caller's stdin (the list is read from fd 3).
run_provision() {
  local prov_dir="$1/install/provision" all=0 state work script name
  local failed="" _PROVISION_SOURCE="$1"
  [[ "${2:-}" == "--all" ]] && all=1
  [[ -d "$prov_dir" ]] || return 0
  state="$(_provision_state_dir)"
  mkdir -p "$state"
  work="$(mktemp -d)"
  : >"$state/status"
  while IFS= read -r script <&3; do
    name="$(basename "$script")"
    _provision_one "$script" "$state" "$all" "$work" ||
      failed+="  $name (exit $_PROVISION_RESULT)"$'\n'
    printf '%s %s\n' "$name" "$_PROVISION_RESULT" >>"$state/status"
  done 3< <(_provision_scripts "$prov_dir")
  rm -rf "$work"
  [[ -z "$failed" ]] && return 0
  _provision_report "$failed"
}
