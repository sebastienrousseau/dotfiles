#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck shell=bash
# Sourced by fleet.sh; inherits set -euo pipefail
# `dot fleet apply`: push dotfiles state to every host in fleet.toml over
# SSH. Helpers stop the command by setting _fleet_stop (the status to
# return) rather than through their own exit status, so errexit still
# applies inside them and cmd_fleet_apply alone returns (its RETURN trap
# removes the scratch directory).

_fleet_hosts_file() {
  printf '%s\n' "${DOTFILES_FLEET_HOSTS:-$HOME/.config/dotfiles/fleet.toml}"
}

# Parse the hosts file. Format:
#   [hosts.laptop]
#   ssh = "user@laptop.local"
#   profile = "workstation"
#
# Echoes one record per line: "<name>\t<ssh-target>\t<profile>".
_fleet_hosts_iter() {
  local f
  f="$(_fleet_hosts_file)"
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

_fleet_apply_help() {
  cat <<EOF
Usage: dot fleet apply [--host <name>] [--cmd <shell>] [--dry-run] [--jobs <n>]

Push dotfiles state to every host registered in:
  ${DOTFILES_FLEET_HOSTS:-\$HOME/.config/dotfiles/fleet.toml}

Format of fleet.toml:
  [hosts.laptop]
  ssh     = "user@laptop.local"
  profile = "workstation"

Hostnames are validated against [A-Za-z0-9._@:+/-]+ before any SSH
fan-out; invalid entries abort the apply.

First-time SSH connections use StrictHostKeyChecking=accept-new (TOFU).
If your threat model requires no TOFU window, pre-populate
~/.ssh/known_hosts before running this command.

Behavior:
  By default each host runs:  dot sync && dot doctor --quiet
  Override with --cmd "<shell>" to run an arbitrary command on every
  host (e.g. --cmd "uptime").

  WARNING: --cmd is the trust boundary. Whatever string you pass
  executes on every remote host with the credentials your SSH key
  carries. Verify the command before running.

Flags:
  --host <name>      Apply to a single host only.
  --cmd <shell>      Run a custom command instead of 'dot sync'.
  --dry-run, -n      Print resolved hosts + planned command; don't SSH.
  --jobs <n>         Parallelism (default 4).
  --verify-hosts     Refuse to open any SSH connection unless every
                     target host already has a key in ~/.ssh/known_hosts.
                     Use when your threat model excludes the TOFU window.
EOF
}

# Sets cmd_fleet_apply's dry_run / verify_hosts / only_host / cmd / jobs.
_fleet_apply_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run | -n)
        dry_run=1
        shift
        ;;
      --verify-hosts)
        # Pre-flight check that every host already has a known_hosts
        # entry, closing the TOFU window before any SSH connection.
        # R3 audit N4. Without this, accept-new is the default and a
        # first-connection MITM can seed an attacker key.
        verify_hosts=1
        shift
        ;;
      --host)
        only_host="$2"
        shift 2
        ;;
      --cmd)
        cmd="$2"
        shift 2
        ;;
      --jobs | -j)
        jobs="$2"
        shift 2
        ;;
      --help | -h)
        _fleet_apply_help
        _fleet_stop=0
        return 0
        ;;
      *)
        ui_err "Unknown arg" "$1"
        _fleet_stop=1
        return 0
        ;;
    esac
  done
}

# Validates --jobs, then loads the hosts (filtered by --host) into entries.
_fleet_apply_load() {
  # The throttle loop waits while the running-job count is >= jobs, so 0 or
  # a non-number would spin forever.
  if [[ ! "$jobs" =~ ^[1-9][0-9]*$ ]]; then
    ui_err "--jobs" "expected a positive integer, got '$jobs'"
    _fleet_stop=2
    return 0
  fi
  hosts_file="$(_fleet_hosts_file)"
  if [[ ! -f "$hosts_file" ]]; then
    ui_err "Fleet" "no hosts file at $hosts_file"
    ui_info "Hint" "create it with stanzas like '[hosts.laptop]\\nssh = \"user@laptop.local\"'"
    _fleet_stop=1
    return 0
  fi
  entries="$(_fleet_hosts_iter)"
  if [[ -z "$entries" ]]; then
    ui_err "Fleet" "hosts file is empty: $hosts_file"
    _fleet_stop=1
    return 0
  fi
  [[ -n "$only_host" ]] || return 0
  entries="$(printf '%s\n' "$entries" | awk -F'\t' -v h="$only_host" '$1 == h')"
  if [[ -z "$entries" ]]; then
    ui_err "Fleet" "host not found: $only_host"
    _fleet_stop=1
  fi
}

_fleet_apply_dry_run() {
  local name ssh profile
  printf '%s\n' "$entries" | while IFS=$'\t' read -r name ssh profile; do
    ui_info "$name" "$ssh  profile=$profile  cmd=$effective_cmd"
  done
  ui_ok "Dry-run" "no SSH connections opened"
}

# Validate every hostname against a conservative regex BEFORE fan-out.
# `user@host:port` characters only — refuses single quotes, backticks,
# `$()`, semicolons, spaces, any shell metacharacter. Closes the
# round-2 audit's hostname-injection finding.
# A leading '-' would be parsed by ssh as an option (e.g. -F/-o), and
# the host name becomes a temp-file name, so it may not contain '/'.
_fleet_apply_validate() {
  local name ssh profile
  while IFS=$'\t' read -r name ssh profile; do
    [[ -n "$name" ]] || continue
    if [[ ! "$name" =~ ^[a-zA-Z0-9._-]+$ || "$name" == .* ]]; then
      ui_err "$name" "invalid host name — only [a-zA-Z0-9._-] allowed, no leading '.'"
      _fleet_stop=1
      return 0
    fi
    if [[ ! "$ssh" =~ ^[a-zA-Z0-9._@:+/-]+$ || "$ssh" == -* ]]; then
      ui_err "$name" "invalid ssh target ($ssh) — only [a-zA-Z0-9._@:+/-] allowed, no leading '-'"
      _fleet_stop=1
      return 0
    fi
  done <<<"$entries"
}

# --verify-hosts: refuse the apply when any target host is missing
# from ~/.ssh/known_hosts. Closes the R3 audit N4 TOFU-window gap.
_fleet_apply_verify() {
  local known_hosts="${HOME}/.ssh/known_hosts" name ssh profile hostpart unknown_count=0
  if [[ ! -f "$known_hosts" ]]; then
    ui_err "verify-hosts" "no $known_hosts — populate before --verify-hosts"
    _fleet_stop=1
    return 0
  fi
  while IFS=$'\t' read -r name ssh profile; do
    [[ -n "$name" && -n "$ssh" ]] || continue
    # Strip `user@` prefix and `:port` suffix for the lookup.
    hostpart="${ssh#*@}"
    hostpart="${hostpart%%:*}"
    if ! ssh-keygen -F "$hostpart" -f "$known_hosts" >/dev/null 2>&1; then
      ui_err "$name" "no known_hosts entry for $hostpart — would TOFU on first connect"
      unknown_count=$((unknown_count + 1))
    fi
  done <<<"$entries"
  if ((unknown_count > 0)); then
    ui_err "verify-hosts" "$unknown_count host(s) missing from known_hosts — aborting"
    _fleet_stop=1
    return 0
  fi
  ui_ok "verify-hosts" "all hosts found in known_hosts"
}

# Run one SSH per host, parallelised via background jobs with a
# semaphore. We DO NOT use `xargs -d` because that flag is GNU-only
# and the §3 hero feature must work on macOS BSD xargs too. Also
# avoids embedding `{}` substitution into a `bash -c` (the previous
# implementation had a quoting hazard around TOML hostnames).
_fleet_apply_one() {
  local _name="$1" _ssh="$2" _cmd="$3" _tmp="$4"
  if ssh -o BatchMode=yes -o ConnectTimeout=10 \
    -o ServerAliveInterval=15 -o ServerAliveCountMax=3 \
    -o StrictHostKeyChecking=accept-new \
    -- "$_ssh" "$_cmd" </dev/null \
    >"$_tmp/$_name.out" 2>"$_tmp/$_name.err"; then
    printf 'ok\n' >"$_tmp/$_name.status"
  else
    printf 'fail %d\n' "$?" >"$_tmp/$_name.status"
  fi
}

# Throttle to `jobs` concurrent workers. `wait -n` (wait for the next
# job to finish) is bash 4.3+, but macOS ships bash 3.2 — there it
# silently fails and the throttle collapses to unbounded parallelism.
# Track PIDs and block on the oldest when at capacity instead; works on
# bash 3.2 and 4+ alike. Counts cmd_fleet_apply's total.
_fleet_apply_run() {
  local name ssh profile
  local _pids=()
  while IFS=$'\t' read -r name ssh profile; do
    [[ -n "$name" && -n "$ssh" ]] || continue
    total=$((total + 1))
    while ((${#_pids[@]} >= jobs)); do
      wait "${_pids[0]}" 2>/dev/null || true
      _pids=("${_pids[@]:1}")
    done
    _fleet_apply_one "$name" "$ssh" "$effective_cmd" "$tmpdir" &
    _pids+=("$!")
  done <<<"$entries"
  wait
}

# One host's result line and event; counts cmd_fleet_apply's ok / fail.
_fleet_apply_result() {
  local name="$1" ssh="$2" err_summary="" _evt_status="unknown"
  if [[ -s "$tmpdir/$name.status" ]] && head -1 "$tmpdir/$name.status" | grep -q '^ok'; then
    ui_ok "$name" "$ssh"
    ok=$((ok + 1))
  else
    [[ -s "$tmpdir/$name.err" ]] && err_summary=" — $(head -1 "$tmpdir/$name.err")"
    ui_err "$name" "$ssh${err_summary}"
    fail=$((fail + 1))
  fi
  [[ -s "$tmpdir/$name.status" ]] && _evt_status="$(head -1 "$tmpdir/$name.status")"
  _fleet_emit_event "apply" "$_evt_status" "host=$name" "cmd=$effective_cmd"
}

# SSH-based "dot fleet apply" — push the local dotfiles state out to
# each registered host. The §3 hero-feature: nobody else owns the
# "Ansible for personal devices" niche.
cmd_fleet_apply() {
  local dry_run=0 only_host="" cmd="" jobs=4 verify_hosts=0 _fleet_stop=""
  local hosts_file entries effective_cmd total=0 ok=0 fail=0 tmpdir _cleanup name ssh profile
  _fleet_apply_args "$@"
  [[ -z "$_fleet_stop" ]] || return "$_fleet_stop"
  _fleet_apply_load
  [[ -z "$_fleet_stop" ]] || return "$_fleet_stop"

  effective_cmd="${cmd:-dot sync && dot doctor --quiet}"
  ui_header "Fleet apply"
  ui_info "Hosts file" "$hosts_file"
  ui_info "Command" "$effective_cmd"
  ui_info "Parallel" "$jobs"
  if [[ "$dry_run" -eq 1 ]]; then
    _fleet_apply_dry_run
    return 0
  fi
  if ! command -v ssh >/dev/null 2>&1; then
    ui_err "ssh" "not installed"
    return 127
  fi

  # `-t` template includes PID + random, so two concurrent `dot fleet
  # apply` invocations from the same user can't collide on $tmpdir.
  tmpdir="$(mktemp -d -t dotfiles-fleet.XXXXXX)"
  # Capture tmpdir's value at trap-definition time (via the eval-on-
  # define `printf -v`), NOT at trap-fire time. A naive
  # `trap 'rm -rf "$tmpdir"' RETURN` is unsafe under set -u because
  # `local tmpdir` is destroyed before the RETURN trap evaluates.
  # The SC2064 warning ("Use single quotes, otherwise this expands now
  # rather than when signalled") is exactly the behaviour we want here —
  # we explicitly want eager expansion. Suppress per-line.
  printf -v _cleanup 'rm -rf %q' "$tmpdir"
  # shellcheck disable=SC2064
  trap "$_cleanup" RETURN

  _fleet_apply_validate
  if [[ -z "$_fleet_stop" ]] && ((verify_hosts == 1)); then
    _fleet_apply_verify
  fi
  [[ -z "$_fleet_stop" ]] || return "$_fleet_stop"
  _fleet_apply_run

  # `while < <(printf ...)` instead of `printf ... | while` — the
  # pipe form runs the loop body in a subshell, so the ok/fail
  # counters never propagate back to the parent. Caught by
  # tests/unit/fleet/test_fleet_apply_mocked_ssh.sh which exercised
  # the full apply path (the dry-run test missed this).
  while IFS=$'\t' read -r name ssh profile; do
    [[ -n "$name" ]] || continue
    _fleet_apply_result "$name" "$ssh"
  done < <(printf '%s\n' "$entries")

  ui_info "Summary" "$ok ok / $fail failed / $total total"
  [[ "$fail" -eq 0 ]]
}
