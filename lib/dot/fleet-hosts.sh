#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck shell=bash
# Sourced by the fleet and ai plugins (through $DOT_SDK); inherits
# set -euo pipefail. Bash 3.2 compatible.
# The fleet's hosts (~/.config/dotfiles/fleet.toml, or
# $DOTFILES_FLEET_HOSTS) and the one way to reach them:
#
#   [hosts.laptop]
#   ssh = "user@laptop.local"
#   profile = "workstation"
#
# fleet_hosts prints one record per host; fleet_host_check refuses a name
# or target that is not plain before any connection opens; fleet_ssh runs
# a command on one host, non-interactively.

[[ "${_DOT_FLEET_HOSTS_LOADED:-0}" == "1" ]] && return 0
_DOT_FLEET_HOSTS_LOADED=1

# fleet_hosts_file: the hosts file's path.
fleet_hosts_file() {
  printf '%s\n' "${DOTFILES_FLEET_HOSTS:-$HOME/.config/dotfiles/fleet.toml}"
}

# fleet_hosts: one "<name>\t<ssh-target>\t<profile>" line per host, in
# file order; nothing when there is no hosts file.
fleet_hosts() {
  local f
  f="$(fleet_hosts_file)"
  [[ -f "$f" ]] || return 0
  awk '
    BEGIN { name = ""; ssh = ""; profile = "" }
    /^\[hosts\./ {
      if (name != "") { printf "%s\t%s\t%s\n", name, ssh, profile }
      gsub(/[\[\]]/, "", $0); sub(/^hosts\./, "", $0); name = $0
      ssh = ""; profile = ""
      next
    }
    /^ssh[[:space:]]*=/    { sub(/^ssh[[:space:]]*=[[:space:]]*/, ""); gsub(/"/, ""); ssh = $0; next }
    /^profile[[:space:]]*=/ { sub(/^profile[[:space:]]*=[[:space:]]*/, ""); gsub(/"/, ""); profile = $0; next }
    END {
      if (name != "") { printf "%s\t%s\t%s\n", name, ssh, profile }
    }
  ' "$f"
}

# fleet_host_check NAME TARGET: 0 when both are plain; else 1, with why on
# stdout. A name becomes a file name, so [a-zA-Z0-9._-] with no leading
# '.'; a target is user@host:port characters only, never a leading '-'
# (ssh would read it as an option) and no shell metacharacter.
fleet_host_check() {
  if [[ ! "$1" =~ ^[a-zA-Z0-9._-]+$ || "$1" == .* ]]; then
    printf "invalid host name — only [a-zA-Z0-9._-] allowed, no leading '.'\n"
    return 1
  fi
  if [[ ! "$2" =~ ^[a-zA-Z0-9._@:+/-]+$ || "$2" == -* ]]; then
    printf "invalid ssh target (%s) — only [a-zA-Z0-9._@:+/-] allowed, no leading '-'\n" "$2"
    return 1
  fi
}

# fleet_ssh TARGET COMMAND: run COMMAND on TARGET with no prompt (batch
# mode), giving up on a host that does not answer in 10 s. First contact
# trusts the host's key (accept-new); dot fleet apply --verify-hosts
# refuses that. Stdin is the caller's.
fleet_ssh() {
  ssh -o BatchMode=yes -o ConnectTimeout="${DOT_FLEET_CONNECT_TIMEOUT:-10}" \
    -o ServerAliveInterval=15 -o ServerAliveCountMax=3 \
    -o StrictHostKeyChecking=accept-new \
    -- "$1" "$2"
}
