#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# dot cli hook install [--agent <id>]... [--dry-run]
# dot cli hook remove [--agent <id>]... [--dry-run]
# hook-install.sh unwired [--agent <id>]...
#
# Wire `dot cli hook run` (the state receiver) and `dot cli hook check`
# (the policy check, ADR-025) into each agent's own configuration, or take
# them out again:
#
#   claude  ~/.claude/settings.json  hooks for every event the receiver maps;
#                                    check on PreToolUse
#   gemini  ~/.gemini/settings.json  hooks for its agent and session events;
#                                    check on BeforeTool
#   codex   ~/.codex/config.toml     notify (Codex passes the event as an
#                                    argument)
#           ~/.codex/hooks.json      check on PreToolUse (Codex runs it once
#                                    trusted in its /hooks)
#
# With no --agent, the agents whose configuration directory exists. The hook
# command is the absolute path of dot, so an agent started without
# ~/.local/bin on its PATH still finds it. Installing replaces any entry of
# ours (a dot that moved) and leaves everything else in the file as it was;
# removing takes out only ours. A file it cannot read as JSON, or a Codex
# notify someone else set, is left untouched and reported.
#
# unwired prints, one per line, each agent whose hook an install would add
# or change, and writes nothing: dot doctor and dot system update read it.
#
# Exit codes: 0 done (or nothing to do); 1 bad usage; 2 jq is missing;
# 3 an agent was left as it was (listed on stderr).

set -uo pipefail

CLAUDE_EVENTS='["SessionStart","UserPromptSubmit","PreToolUse","PostToolUse","PermissionRequest","Notification","Elicitation","Stop","StopFailure","SessionEnd"]'
GEMINI_EVENTS='["SessionStart","BeforeAgent","AfterAgent","Notification","SessionEnd"]'

DRY_RUN=0
LEFT=0
UNWIRED=""
AGENTS=()

say() { printf '%s\n' "$*"; }

left() {
  printf 'dot cli hook: %s: %s; left as it was\n' "$1" "$2" >&2
  LEFT=1
}

# hi_dot: the dot an agent should run, as an absolute path. The one on PATH
# counts only when it is a script: Graphviz installs a binary named dot.
hi_dot() {
  local dot magic=""
  dot="$(command -v dot 2>/dev/null || true)"
  [[ "$dot" != /* ]] || magic="$(head -c 2 "$dot" 2>/dev/null || true)"
  [[ "$magic" == '#!' ]] || dot="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)/bin/dot"
  printf '%s\n' "$dot"
}

# hi_target FILE: FILE with its symlinks followed, so a config another tool
# links into place stays a link and its target is what changes.
hi_target() {
  local f="$1" link n=0
  while [[ -L "$f" && "$n" -lt 40 ]]; do
    link="$(readlink "$f")"
    [[ "$link" == /* ]] || link="$(dirname "$f")/$link"
    f="$link"
    n=$((n + 1))
  done
  printf '%s\n' "$f"
}

# hi_write FILE CONTENT: replace FILE (or what it links to) with CONTENT,
# keeping its mode (a new file is private), through a temporary file beside
# it.
hi_write() {
  local file tmp
  file="$(hi_target "$1")"
  tmp="$file.dot-hook.$$"
  mkdir -p "$(dirname "$file")" || return 1
  if [[ -f "$file" ]]; then cp -p "$file" "$tmp" || return 1; else (umask 077 && : >"$tmp") || return 1; fi
  printf '%s\n' "$2" >"$tmp" && mv -f "$tmp" "$file" || {
    rm -f "$tmp"
    return 1
  }
}

# hi_json_edit AGENT FILE EVENTS MODE CHECK: add (install) or drop (remove)
# the hook entries of ours for AGENT in a settings.json: the receiver on
# each of EVENTS, the policy check on the CHECK event. Prints the new JSON.
hi_json_edit() {
  local dot
  dot="$(hi_dot)"
  jq --arg agent "$1" --arg run "'$dot' cli hook run --agent $1" --arg chk "'$dot' cli hook check --agent $1" \
    --argjson events "$3" --arg mode "$4" --arg check "$5" '
    def ours: (.command // "") as $c
      | ($c | endswith(" cli hook run --agent " + $agent)) or ($c | endswith(" cli hook check --agent " + $agent));
    def drop: map(.hooks |= map(select(ours | not))) | map(select((.hooks | length) > 0));
    def entry($cmd; $name): {hooks: [{type: "command", command: $cmd}
      + (if $agent == "gemini" then {name: $name} else {} end)]};
    def add($e; $x): .[$e] = ((.[$e] // []) + [$x]);
    (.hooks // {} | with_entries(.value |= drop) | with_entries(select((.value | length) > 0))) as $kept
    | if $mode == "install" then .hooks = (reduce $events[] as $e ($kept; add($e; entry($run; "dot-cli-hook")))
        | add($check; entry($chk; "dot-cli-hook-check")))
      elif ($kept | length) > 0 then .hooks = $kept
      else del(.hooks) end' "$2"
}

# hi_json AGENT FILE EVENTS MODE CHECK: install or remove in one
# settings.json.
hi_json() {
  local before after
  before='{}'
  if [[ -f "$2" ]]; then
    before="$(jq . "$2" 2>/dev/null)" || {
      left "$1" "$2 is not valid JSON"
      return 0
    }
  fi
  [[ "$4" == remove && ! -f "$2" ]] && {
    say "$1: not installed"
    return 0
  }
  after="$(hi_json_edit "$1" <(printf '%s\n' "$before") "$3" "$4" "$5")" || {
    left "$1" "could not edit $2"
    return 0
  }
  hi_apply "$1" "$2" "$before" "$after" "$4"
}

# hi_apply AGENT FILE BEFORE AFTER MODE: write AFTER when it differs.
hi_apply() {
  if [[ "$DRY_RUN" == unwired ]]; then
    # Once per agent, though Codex has two files.
    [[ "$3" == "$4" || " $UNWIRED " == *" $1 "* ]] || {
      say "$1"
      UNWIRED+=" $1"
    }
  elif [[ "$3" == "$4" ]]; then
    [[ "$5" == install ]] && say "$1: already installed in $2" || say "$1: not installed"
  elif [[ "$DRY_RUN" == 1 ]]; then
    say "$1: would ${5} the hook in $2"
  elif hi_write "$2" "$4"; then
    say "$1: hook ${5/%e/}ed in $2"
  else
    left "$1" "could not write $2"
  fi
}

# hi_codex_line: the notify line that runs the receiver for Codex.
hi_codex_line() {
  printf 'notify = ["%s", "cli", "hook", "run", "--agent", "codex"]\n' "$(hi_dot)"
}

# hi_codex_without BEFORE LINE: BEFORE with LINE taken out (BEFORE as it is
# when LINE is empty).
hi_codex_without() {
  if [[ -z "$2" ]]; then
    printf '%s' "$1"
  else
    grep -v -F -x -- "$2" <<<"$1" || true
  fi
}

# hi_codex FILE MODE: the top-level notify of a Codex config.toml. Ours is
# replaced or removed; one someone else set is left.
hi_codex() {
  local current before after
  before="$(cat "$1" 2>/dev/null || true)"
  current="$(awk '/^[[:space:]]*\[/ { exit } /^[[:space:]]*notify[[:space:]]*=/ { print; exit }' <<<"$before")"
  if [[ -n "$current" && "$current" != *'"cli", "hook", "run"'* ]]; then
    [[ "$2" == install ]] && left codex "$1 already has a notify of its own" || say "codex: not installed"
    return 0
  fi
  after="$(hi_codex_without "$before" "$current")"
  [[ "$2" == remove ]] || after="$(hi_codex_line)${after:+$'\n'$after}"
  hi_apply codex "$1" "$before" "$after" "$2"
}

# hi_agent AGENT MODE: install or remove for one agent.
hi_agent() {
  case "$1" in
    claude) hi_json claude "$HOME/.claude/settings.json" "$CLAUDE_EVENTS" "$2" PreToolUse ;;
    gemini) hi_json gemini "$HOME/.gemini/settings.json" "$GEMINI_EVENTS" "$2" BeforeTool ;;
    codex)
      hi_codex "$HOME/.codex/config.toml" "$2"
      hi_json codex "$HOME/.codex/hooks.json" '[]' "$2" PreToolUse
      ;;
  esac
}

# hi_parse ARG...: set AGENTS and DRY_RUN; bad usage exits 1.
hi_parse() {
  while (($#)); do
    case "$1" in
      --agent)
        [[ "${2:-}" =~ ^(claude|gemini|codex)$ ]] || {
          printf 'dot cli hook: --agent takes claude, gemini or codex\n' >&2
          exit 1
        }
        AGENTS+=("$2")
        shift
        ;;
      --dry-run | -n) DRY_RUN=1 ;;
      *)
        printf 'dot cli hook: unknown option %s\n' "$1" >&2
        exit 1
        ;;
    esac
    shift
  done
}

# hi_default_agents: the agents whose configuration directory exists.
hi_default_agents() {
  local a
  for a in claude gemini codex; do
    [[ -d "$HOME/.$a" ]] && AGENTS+=("$a")
  done
}

# hi_none MODE: no agent is configured. Said in a sentence, except by
# unwired, whose output is a list.
hi_none() {
  [[ "$DRY_RUN" == unwired ]] ||
    say "No agent configuration found (~/.claude, ~/.gemini, ~/.codex): nothing to $1."
}

main() {
  local mode="${1:-}" a
  shift || true
  hi_parse "$@"
  [[ "$mode" != unwired ]] || mode=install DRY_RUN=unwired
  ((${#AGENTS[@]})) || hi_default_agents
  if ((${#AGENTS[@]} == 0)); then
    hi_none "$mode"
    return 0
  fi
  if ! command -v jq >/dev/null 2>&1; then
    printf 'dot cli hook: jq is needed to edit the agents'"'"' hook files; install it with mise or your package manager\n' >&2
    return 2
  fi
  for a in "${AGENTS[@]}"; do hi_agent "$a" "$mode" || LEFT=1; done
  [[ "$LEFT" == 0 ]] || return 3
}

main "$@"
