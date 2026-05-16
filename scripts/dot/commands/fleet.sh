#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Dotfiles CLI - Fleet Commands
# fleet status|nodes|drift|events|namespace

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"
# shellcheck source=../lib/log.sh
source "$SCRIPT_DIR/../lib/log.sh"

dot_ui_command_banner "Fleet" "${1:-}"

_FLEET_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/fleet"
_FLEET_EVENTS_FILE="$_FLEET_STATE_DIR/events.jsonl"

_fleet_enabled() {
  local data_file
  data_file="$(resolve_source_dir)/.chezmoidata.toml"
  if [[ -f "$data_file" ]] && grep -q '^enabled = true' "$data_file" 2>/dev/null; then
    return 0
  fi
  return 1
}

_fleet_node_id() {
  local data_file node_id=""
  data_file="$(resolve_source_dir)/.chezmoidata.toml"
  if [[ -f "$data_file" ]]; then
    node_id="$(sed -n 's/^node_id = "\(.*\)"/\1/p' "$data_file" | head -1)"
  fi
  if [[ -z "$node_id" ]]; then
    node_id="$(hostname -s 2>/dev/null || echo "unknown")"
  fi
  printf '%s\n' "$node_id"
}

_fleet_namespace() {
  local data_file ns=""
  data_file="$(resolve_source_dir)/.chezmoidata.toml"
  if [[ -f "$data_file" ]]; then
    ns="$(sed -n 's/^namespace = "\(.*\)"/\1/p' "$data_file" | head -1)"
  fi
  printf '%s\n' "${ns:-default}"
}

_fleet_emit_event() {
  local event="$1" status="${2:-ok}"
  shift 2 || true
  local ts node_id namespace
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  node_id="$(_fleet_node_id)"
  namespace="$(_fleet_namespace)"
  mkdir -p "$_FLEET_STATE_DIR" 2>/dev/null || return 0
  local payload
  payload=$(printf '{"time":"%s","event":"%s","status":"%s","node_id":"%s","namespace":"%s","trace_id":"%s"' \
    "$ts" "$event" "$status" "$node_id" "$namespace" "$DOT_TRACE_ID")
  while [[ $# -gt 0 ]]; do
    payload+=$(printf ',"%s":"%s"' "${1%%=*}" "${1#*=}")
    shift
  done
  payload+='}'
  printf '%s\n' "$payload" >>"$_FLEET_EVENTS_FILE" 2>/dev/null || true

  # Forward to endpoint if configured
  local endpoint=""
  local data_file
  data_file="$(resolve_source_dir)/.chezmoidata.toml"
  if [[ -f "$data_file" ]]; then
    endpoint="$(sed -n 's/^endpoint = "\(.*\)"/\1/p' "$data_file" | head -1)"
  fi
  if [[ -n "$endpoint" ]] && [[ "$endpoint" == https://* ]]; then
    curl -fsSL -X POST -H "Content-Type: application/json" \
      -d "$payload" "$endpoint" >/dev/null 2>&1 || true
  fi
}

cmd_fleet_status() {
  local json_mode=0
  [[ "${1:-}" == "--json" || "${1:-}" == "-j" ]] && json_mode=1

  local node_id namespace version os_type kernel shell_type
  node_id="$(_fleet_node_id)"
  namespace="$(_fleet_namespace)"
  version="$(dotfiles_version)"
  os_type="$(uname -s)"
  kernel="$(uname -r)"
  shell_type="${SHELL##*/}"

  local drift_status="clean"
  if has_command chezmoi; then
    local drift_output
    drift_output="$(chezmoi status 2>/dev/null || true)"
    if [[ -n "$drift_output" ]]; then
      drift_status="drifted"
    fi
  fi

  local last_apply=""
  local state_log="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/dot.log"
  if [[ -f "$state_log" ]]; then
    last_apply="$(grep 'apply' "$state_log" 2>/dev/null | tail -1 | sed -n 's/^\[\([^]]*\)\].*/\1/p')"
  fi

  if [[ "$json_mode" -eq 1 ]]; then
    printf '{"node_id":"%s","namespace":"%s","version":"%s","os":"%s","kernel":"%s","shell":"%s","drift":"%s","last_apply":"%s"}\n' \
      "$node_id" "$namespace" "$version" "$os_type" "$kernel" "$shell_type" "$drift_status" "$last_apply"
    return 0
  fi

  ui_header "Fleet Node Status"
  echo ""
  ui_ok "Node ID" "$node_id"
  ui_ok "Namespace" "$namespace"
  ui_ok "Version" "v$version"
  ui_ok "OS" "$os_type $kernel"
  ui_ok "Shell" "$shell_type"
  if [[ "$drift_status" == "clean" ]]; then
    ui_ok "Drift" "$drift_status"
  else
    ui_warn "Drift" "$drift_status"
  fi
  if [[ -n "$last_apply" ]]; then
    ui_info "Last Apply" "$last_apply"
  fi

  _fleet_emit_event "status" "ok" "version=$version" "drift=$drift_status"
}

_DRIFT_HISTORY_FILE="$_FLEET_STATE_DIR/drift-history.jsonl"

_fleet_drift_append_history() {
  local drift_output="$1"
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  mkdir -p "$_FLEET_STATE_DIR" 2>/dev/null || return 0
  if [[ -z "$drift_output" ]]; then
    printf '{"time":"%s","status":"clean","files":[]}\n' "$ts" >>"$_DRIFT_HISTORY_FILE" 2>/dev/null || true
  else
    local files_json
    files_json="$(printf '%s\n' "$drift_output" | awk '{print $NF}' | jq -R . | jq -s . 2>/dev/null || echo '[]')"
    printf '{"time":"%s","status":"drifted","files":%s}\n' "$ts" "$files_json" >>"$_DRIFT_HISTORY_FILE" 2>/dev/null || true
  fi
}

cmd_fleet_drift() {
  local subcommand="${1:-check}"
  if [[ "${1:-}" == --* ]] || [[ -z "${1:-}" ]]; then
    subcommand="check"
  else
    shift || true
  fi

  case "$subcommand" in
    check)
      ui_header "Fleet Drift Report"
      echo ""

      if ! has_command chezmoi; then
        ui_err "chezmoi" "not installed"
        return 1
      fi

      local drift_output
      drift_output="$(chezmoi status 2>/dev/null || true)"

      _fleet_drift_append_history "$drift_output"

      if [[ -z "$drift_output" ]]; then
        ui_ok "Status" "No drift detected"
        _fleet_emit_event "drift_check" "clean"
        return 0
      fi

      ui_warn "Status" "Configuration drift detected"
      echo ""
      printf '%s\n' "$drift_output" | while IFS= read -r line; do
        local change_type="${line:0:2}"
        local file_path="${line:3}"
        case "$change_type" in
          "MM" | "A " | " M")
            ui_warn "$change_type" "$file_path"
            ;;
          *)
            ui_info "$change_type" "$file_path"
            ;;
        esac
      done

      _fleet_emit_event "drift_check" "drifted" "count=$(echo "$drift_output" | wc -l | tr -d ' ')"
      ;;
    history)
      ui_header "Drift History"
      echo ""
      if [[ ! -f "$_DRIFT_HISTORY_FILE" ]]; then
        ui_info "No drift history recorded yet."
        return 0
      fi
      local count="${1:-20}"
      tail -n "$count" "$_DRIFT_HISTORY_FILE" | while IFS= read -r line; do
        local time status file_count
        time="$(printf '%s' "$line" | jq -r '.time' 2>/dev/null || echo "?")"
        status="$(printf '%s' "$line" | jq -r '.status' 2>/dev/null || echo "?")"
        file_count="$(printf '%s' "$line" | jq '.files | length' 2>/dev/null || echo 0)"
        if [[ "$status" == "clean" ]]; then
          ui_ok "$time" "clean"
        else
          ui_warn "$time" "drifted ($file_count files)"
        fi
      done
      ;;
    predict)
      ui_header "Drift Prediction"
      echo ""
      if [[ ! -f "$_DRIFT_HISTORY_FILE" ]]; then
        ui_info "Not enough history for prediction."
        return 0
      fi
      # Simple heuristic: files that drifted in >50% of the last 10 checks
      local threshold=5
      jq -r '.files[]?' "$_DRIFT_HISTORY_FILE" | tail -n 1000 | sort | uniq -c | sort -rn | while read -r count file; do
        if [[ "$count" -ge "$threshold" ]]; then
          ui_warn "Likely to drift" "$file (drifted $count times recently)"
        fi
      done
      local total_checks
      total_checks="$(wc -l <"$_DRIFT_HISTORY_FILE" | tr -d ' ')"
      ui_info "History" "$total_checks checks recorded"
      ;;
    *)
      die "Usage: dot fleet drift [check|history|predict]"
      ;;
  esac
}

cmd_fleet_events() {
  local count="${1:-20}"
  if [[ ! -f "$_FLEET_EVENTS_FILE" ]]; then
    ui_info "No fleet events recorded yet."
    ui_info "Events file" "$_FLEET_EVENTS_FILE"
    return 0
  fi

  ui_header "Fleet Events (last $count)"
  echo ""

  if has_command jq; then
    tail -n "$count" "$_FLEET_EVENTS_FILE" | jq -r '"\(.time)\t\(.event)\t\(.status)\t\(.node_id)"' | while IFS=$'\t' read -r time event status node; do
      if [[ "$status" == "ok" || "$status" == "clean" ]]; then
        ui_ok "$event" "$time ($node)"
      else
        ui_warn "$event" "$time ($node)"
      fi
    done
  else
    tail -n "$count" "$_FLEET_EVENTS_FILE"
  fi
}

cmd_fleet_namespace() {
  local subcommand="${1:-show}"
  shift || true

  case "$subcommand" in
    show)
      local ns
      ns="$(_fleet_namespace)"
      ui_header "Fleet Namespace"
      ui_ok "Active" "$ns"

      local data_file
      data_file="$(resolve_source_dir)/.chezmoidata.toml"
      if [[ -f "$data_file" ]]; then
        echo ""
        ui_section "Available Namespaces"
        grep '^\[namespaces\.' "$data_file" | sed 's/\[namespaces\.\(.*\)\]/\1/' | while IFS= read -r name; do
          if [[ "$name" == "$ns" ]]; then
            ui_ok "$name" "[active]"
          else
            ui_info "$name" ""
          fi
        done
      fi
      ;;
    set)
      local new_ns="${1:-}"
      [[ -n "$new_ns" ]] || die "Usage: dot fleet namespace set <name>"
      validate_name "$new_ns" "namespace"
      local data_file
      data_file="$(resolve_source_dir)/.chezmoidata.toml"
      if grep -q "^namespace = " "$data_file" 2>/dev/null; then
        # Atomic write: render into a tempfile + mv so concurrent
        # `dot fleet namespace set` callers can't corrupt the TOML.
        # Avoids `sed -i` portability dance (GNU `-i` vs BSD `-i ''`).
        local _tmp
        _tmp="$(mktemp "${data_file}.XXXXXX")" || die "Cannot create tempfile"
        # Explicit if/else instead of A && B || C — the latter (SC2015)
        # silently runs C when B itself fails, masking real mv errors.
        if sed "s/^namespace = \".*\"/namespace = \"$new_ns\"/" "$data_file" >"$_tmp"; then
          if ! mv "$_tmp" "$data_file"; then
            rm -f "$_tmp"
            die "Failed to commit namespace update"
          fi
        else
          rm -f "$_tmp"
          die "Failed to render namespace update"
        fi
      fi
      ui_ok "Namespace" "Set to '$new_ns'. Run 'dot sync' to apply."
      _fleet_emit_event "namespace_set" "ok" "namespace=$new_ns"
      ;;
    *)
      die "Usage: dot fleet namespace [show|set <name>]"
      ;;
  esac
}

cmd_fleet_enforce() {
  local subcommand="${1:-status}"
  shift || true

  local repo_root
  repo_root="$(resolve_source_dir)"
  local profiles_file="$repo_root/dot_config/dotfiles/agent-profiles.json"

  case "$subcommand" in
    status)
      if [[ ! -f "$profiles_file" ]]; then
        ui_err "Profiles" "agent-profiles.json not found"
        return 1
      fi
      local enforcement
      enforcement="$(jq -r '.rbac.enforcement // "advisory"' "$profiles_file")"
      ui_header "RBAC Enforcement"
      ui_ok "Mode" "$enforcement"
      ui_ok "Default role" "$(jq -r '.rbac.defaultRole // "developer"' "$profiles_file")"
      jq -r '.rbac.roles | to_entries[] | "\(.key)\t\(.value.allowedProfiles | join(", "))"' "$profiles_file" | while IFS=$'\t' read -r role profiles; do
        ui_info "$role" "$profiles"
      done
      ;;
    set)
      local mode="${1:-}"
      [[ -n "$mode" ]] || die "Usage: dot fleet enforce set <advisory|strict>"
      case "$mode" in
        advisory | strict) ;;
        *) die "Invalid enforcement mode: $mode (use advisory or strict)" ;;
      esac
      [[ -f "$profiles_file" ]] || die "agent-profiles.json not found"
      local tmp
      tmp="$(jq --arg mode "$mode" '.rbac.enforcement = $mode' "$profiles_file")"
      printf '%s\n' "$tmp" >"$profiles_file"
      ui_ok "Enforcement" "set to '$mode'"
      _fleet_emit_event "enforcement_set" "ok" "mode=$mode"
      ;;
    *)
      die "Usage: dot fleet enforce [status|set <advisory|strict>]"
      ;;
  esac
}

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

# SSH-based "dot fleet apply" — push the local dotfiles state out to
# each registered host. The §3 hero-feature: nobody else owns the
# "Ansible for personal devices" niche.
cmd_fleet_apply() {
  local dry_run=0 only_host="" cmd="" jobs=4 verify_hosts=0
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
        return 0
        ;;
      *)
        ui_err "Unknown arg" "$1"
        return 1
        ;;
    esac
  done

  local hosts_file
  hosts_file="$(_fleet_hosts_file)"
  if [[ ! -f "$hosts_file" ]]; then
    ui_err "Fleet" "no hosts file at $hosts_file"
    ui_info "Hint" "create it with stanzas like '[hosts.laptop]\\nssh = \"user@laptop.local\"'"
    return 1
  fi

  local entries
  entries="$(_fleet_hosts_iter)"
  if [[ -z "$entries" ]]; then
    ui_err "Fleet" "hosts file is empty: $hosts_file"
    return 1
  fi
  if [[ -n "$only_host" ]]; then
    entries="$(printf '%s\n' "$entries" | awk -F'\t' -v h="$only_host" '$1 == h')"
    [[ -n "$entries" ]] || {
      ui_err "Fleet" "host not found: $only_host"
      return 1
    }
  fi

  local default_cmd='dot sync && dot doctor --quiet'
  local effective_cmd="${cmd:-$default_cmd}"

  ui_header "Fleet apply"
  ui_info "Hosts file" "$hosts_file"
  ui_info "Command" "$effective_cmd"
  ui_info "Parallel" "$jobs"

  if [[ "$dry_run" -eq 1 ]]; then
    printf '%s\n' "$entries" | while IFS=$'\t' read -r name ssh profile; do
      ui_info "$name" "$ssh  profile=$profile  cmd=$effective_cmd"
    done
    ui_ok "Dry-run" "no SSH connections opened"
    return 0
  fi

  if ! command -v ssh >/dev/null 2>&1; then
    ui_err "ssh" "not installed"
    return 127
  fi

  local total=0 ok=0 fail=0
  local tmpdir
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
  local _cleanup
  printf -v _cleanup 'rm -rf %q' "$tmpdir"
  # shellcheck disable=SC2064
  trap "$_cleanup" RETURN

  # Validate every hostname against a conservative regex BEFORE fan-out.
  # `user@host:port` characters only — refuses single quotes, backticks,
  # `$()`, semicolons, spaces, any shell metacharacter. Closes the
  # round-2 audit's hostname-injection finding.
  while IFS=$'\t' read -r name ssh profile; do
    [[ -n "$name" ]] || continue
    if [[ ! "$ssh" =~ ^[a-zA-Z0-9._@:+/-]+$ ]]; then
      ui_err "$name" "invalid ssh target ($ssh) — only [a-zA-Z0-9._@:+/-] allowed"
      return 1
    fi
  done <<<"$entries"

  # --verify-hosts: refuse the apply when any target host is missing
  # from ~/.ssh/known_hosts. Closes the R3 audit N4 TOFU-window gap.
  if (( verify_hosts == 1 )); then
    local known_hosts="${HOME}/.ssh/known_hosts"
    if [[ ! -f "$known_hosts" ]]; then
      ui_err "verify-hosts" "no $known_hosts — populate before --verify-hosts"
      return 1
    fi
    local unknown_count=0
    while IFS=$'\t' read -r name ssh profile; do
      [[ -n "$name" && -n "$ssh" ]] || continue
      # Strip `user@` prefix and `:port` suffix for the lookup.
      local hostpart="${ssh#*@}"
      hostpart="${hostpart%%:*}"
      if ! ssh-keygen -F "$hostpart" -f "$known_hosts" >/dev/null 2>&1; then
        ui_err "$name" "no known_hosts entry for $hostpart — would TOFU on first connect"
        unknown_count=$((unknown_count + 1))
      fi
    done <<<"$entries"
    if (( unknown_count > 0 )); then
      ui_err "verify-hosts" "$unknown_count host(s) missing from known_hosts — aborting"
      return 1
    fi
    ui_ok "verify-hosts" "all hosts found in known_hosts"
  fi

  # Run one SSH per host, parallelised via background jobs with a
  # semaphore. We DO NOT use `xargs -d` because that flag is GNU-only
  # and the §3 hero feature must work on macOS BSD xargs too. Also
  # avoids embedding `{}` substitution into a `bash -c` (the previous
  # implementation had a quoting hazard around TOML hostnames).
  _fleet_apply_one() {
    local _name="$1" _ssh="$2" _cmd="$3" _tmp="$4"
    if ssh -o BatchMode=yes -o ConnectTimeout=10 \
      -o StrictHostKeyChecking=accept-new \
      "$_ssh" "$_cmd" </dev/null \
      >"$_tmp/$_name.out" 2>"$_tmp/$_name.err"; then
      printf 'ok\n' >"$_tmp/$_name.status"
    else
      printf 'fail %d\n' "$?" >"$_tmp/$_name.status"
    fi
  }

  local running=0
  while IFS=$'\t' read -r name ssh profile; do
    [[ -n "$name" && -n "$ssh" ]] || continue
    total=$((total + 1))
    while ((running >= jobs)); do
      wait -n 2>/dev/null || break
      running=$((running - 1))
    done
    _fleet_apply_one "$name" "$ssh" "$effective_cmd" "$tmpdir" &
    running=$((running + 1))
  done <<<"$entries"
  wait

  # `while < <(printf ...)` instead of `printf ... | while` — the
  # pipe form runs the loop body in a subshell, so the ok/fail
  # counters never propagate back to the parent. Caught by
  # tests/unit/fleet/test_fleet_apply_mocked_ssh.sh which exercised
  # the full apply path (the dry-run test missed this).
  while IFS=$'\t' read -r name ssh profile; do
    [[ -n "$name" ]] || continue
    if [[ -s "$tmpdir/$name.status" ]] && head -1 "$tmpdir/$name.status" | grep -q '^ok'; then
      ui_ok "$name" "$ssh"
      ok=$((ok + 1))
    else
      local err_summary=""
      [[ -s "$tmpdir/$name.err" ]] && err_summary=" — $(head -1 "$tmpdir/$name.err")"
      ui_err "$name" "$ssh${err_summary}"
      fail=$((fail + 1))
    fi
    local _evt_status="unknown"
    [[ -s "$tmpdir/$name.status" ]] && _evt_status="$(head -1 "$tmpdir/$name.status")"
    _fleet_emit_event "apply" "$_evt_status" "host=$name" "cmd=$effective_cmd"
  done < <(printf '%s\n' "$entries")

  ui_info "Summary" "$ok ok / $fail failed / $total total"
  [[ "$fail" -eq 0 ]]
}

cmd_fleet() {
  local subcommand="${1:-status}"
  if [[ "${1:-}" == --* ]] || [[ -z "${1:-}" ]]; then
    subcommand="status"
  else
    shift || true
  fi

  case "$subcommand" in
    status)
      cmd_fleet_status "$@"
      ;;
    drift)
      cmd_fleet_drift "$@"
      ;;
    events)
      cmd_fleet_events "$@"
      ;;
    namespace | ns)
      cmd_fleet_namespace "$@"
      ;;
    enforce)
      cmd_fleet_enforce "$@"
      ;;
    apply | push)
      cmd_fleet_apply "$@"
      ;;
    *)
      ui_header "Fleet Commands"
      echo ""
      ui_info "Usage" "dot fleet [command]"
      echo ""
      ui_ok "status" "Show this node's fleet status (--json for machine output)"
      ui_ok "drift" "Check for configuration drift"
      ui_ok "events" "Show recent fleet events"
      ui_ok "namespace" "Show or set the active namespace"
      ui_ok "enforce" "Show or set RBAC enforcement mode (advisory|strict)"
      ui_ok "apply" "SSH out to every host in fleet.toml and run 'dot sync'"
      ;;
  esac
}

# Dispatch
case "${1:-}" in
  fleet)
    shift
    cmd_fleet "$@"
    ;;
  *)
    cmd_fleet "$@"
    ;;
esac
