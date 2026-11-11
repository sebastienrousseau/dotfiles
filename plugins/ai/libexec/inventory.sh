#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# dot ai inventory show [--json] — what this machine runs (plan P1.5): each
# installed agent's version, its pin in [ai_tools], how it is signed in, and
# whether dot's hooks are wired into it; the AI policy's SHA-256; and the
# drift among them: a version off its pin, hooks missing. --json prints it
# as ai/inventory.v1, which dot doctor and dot fleet drift agents read.
#
# Sign-in is where each agent keeps it, looked at, never read: an API key in
# the environment (key), else its credentials file or keychain item (login),
# else none. An agent dot does not know how to ask is unknown.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../lib/dot/sdk.sh
source "${DOT_SDK:-$SCRIPT_DIR/../../../lib/dot}/sdk.sh"
# shellcheck source=ai/ai-install.sh
source "$SCRIPT_DIR/ai/ai-install.sh"
# shellcheck source=ai/ai-probe.sh
source "$SCRIPT_DIR/ai/ai-probe.sh"

inv_usage() {
  echo "Usage: dot ai inventory show [--json]"
  exit 1
}

# inv_version BIN: the first dotted number in BIN's version line, or nothing.
inv_version() {
  local to=""
  ! has_command timeout || to="timeout 8"
  _ai_probe_version "$1" "$to" | awk 'match($0, /[0-9]+(\.[0-9]+)+/) { print substr($0, RSTART, RLENGTH); exit }'
}

# inv_pin BIN: BIN's pin in [ai_tools]; nothing for a native install.
inv_pin() {
  local pkg
  pkg="$(ai_roster_package "$1" || true)"
  [[ -z "$pkg" ]] || _ai_pinned_version "$pkg"
}

# inv_keychain SERVICE: login, none (no such item) or unknown (macOS only).
inv_keychain() {
  local rc=0
  has_command security || {
    echo none
    return
  }
  security find-generic-password -s "$1" >/dev/null 2>&1 || rc=$?
  case "$rc" in
    0) echo login ;;
    44) echo none ;;
    *) echo unknown ;;
  esac
}

# inv_auth NAME: key, login, none or unknown.
inv_auth() {
  case "$1" in
    claude)
      if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then echo key; elif [[ -s "$HOME/.claude/.credentials.json" ]]; then echo login; else inv_keychain "Claude Code-credentials"; fi
      ;;
    codex)
      if [[ -n "${OPENAI_API_KEY:-}" ]]; then echo key; elif [[ -s "${CODEX_HOME:-$HOME/.codex}/auth.json" ]]; then echo login; else echo none; fi
      ;;
    *) echo unknown ;;
  esac
}

# inv_hooks NAME UNWIRED LEFT: wired, missing, unknown (a configuration the
# installer could not read: it names the agent in LEFT) or n/a (an agent
# dot does not hook, or one never configured).
inv_hooks() {
  case "$1" in
    claude | codex) ;;
    *)
      echo n/a
      return
      ;;
  esac
  if [[ ! -d "$HOME/.$1" ]]; then
    echo n/a
  elif [[ $'\n'"$3" == *$'\n'"dot cli hook: $1:"* ]]; then
    echo unknown
  elif [[ $'\n'"$2"$'\n' == *$'\n'"$1"$'\n'* ]]; then
    echo missing
  else
    echo wired
  fi
}

# inv_rows DIR: one "name<TAB>version<TAB>pin<TAB>auth<TAB>hooks" line per
# installed agent, in roster order; the versions are probed at once.
inv_rows() {
  local dir="$1" i name bin unwired
  for i in "${!AI_ROSTER_NAMES[@]}"; do
    bin="${AI_ROSTER_BINS[$i]}"
    has_command "$bin" || continue
    inv_version "$bin" >"$dir/$i" &
  done
  wait
  # Exit 3 names each agent whose configuration it could not read, on stderr.
  unwired="$(bash "$SCRIPT_DIR/../../cli/libexec/hook-install.sh" unwired 2>"$dir/left")" || true
  for i in "${!AI_ROSTER_NAMES[@]}"; do
    [[ -f "$dir/$i" ]] || continue
    name="${AI_ROSTER_NAMES[$i]}"
    printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$(cat "$dir/$i")" "$(inv_pin "${AI_ROSTER_BINS[$i]}")" \
      "$(inv_auth "$name")" "$(inv_hooks "$name" "$unwired" "$(cat "$dir/left")")"
  done
}

# inv_policy: "<sha256>\t<path>" of the AI policy; an empty digest when
# there is none.
inv_policy() {
  local file="${DOT_AI_POLICY:-${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/ai-policy.toml}" sha=""
  [[ ! -f "$file" ]] || sha="$( (shasum -a 256 "$file" 2>/dev/null || sha256sum "$file" 2>/dev/null) | awk '{print $1}')" || true
  printf '%s\t%s\n' "$sha" "$file"
}

# The rows and the policy line as ai/inventory.v1; drift is derived here.
read -r -d '' INV_JSON <<'EOF' || true
def nul: if . == "" then null else . end;
($rows | split("\n") | map(select(. != "") | split("\t")
  | {name: .[0], version: (.[1] | nul), pin: (.[2] | nul), auth: .[3], hooks: .[4]})) as $agents
| ($policy | split("\t")) as $p
| {schema: "ai/inventory.v1", host: $host, time: $time,
   policy: {path: $p[1], sha256: ($p[0] | nul)},
   agents: $agents,
   drift: [$agents[]
     | (select(.version and .pin and .version != .pin)
         | {agent: .name, kind: "version", message: "\(.name): \(.version) is off its pin \(.pin)"}),
       (select(.hooks == "missing")
         | {agent: .name, kind: "hooks", message: "\(.name): hooks missing (dot cli hook install)"})]}
EOF

# The report as a table; one row per agent, then the policy and the drift.
read -r -d '' INV_TABLE <<'EOF' || true
def col($n): (. // "-") + (" " * $n) | .[:$n];
"\("AGENT" | col(14)) \("VERSION" | col(12)) \("PIN" | col(12)) \("AUTH" | col(8)) HOOKS",
(.agents[] | "\(.name | col(14)) \(.version | col(12)) \(.pin | col(12)) \(.auth | col(8)) \(.hooks)"),
"",
"\("policy" | col(14)) \(if .policy.sha256 then "sha256:\(.policy.sha256[:12]) \(.policy.path)" else "none" end)",
(.drift[] | "\("drift" | col(14)) \(.message)")
EOF

inv_show() {
  local dir rows
  has_command jq || {
    ui_err "dot ai inventory" "needs jq" >&2
    exit 1
  }
  dir="$(mktemp -d "${TMPDIR:-/tmp}/dot-ai-inventory.XXXXXX")"
  rows="$(inv_rows "$dir")"
  rm -rf "$dir"
  jq -n --arg rows "$rows" --arg policy "$(inv_policy)" --arg host "$(hostname -s 2>/dev/null || hostname)" \
    --arg time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$INV_JSON" |
    if [[ "$1" == --json ]]; then jq -c .; else jq -r "$INV_TABLE"; fi
}

case "${1:-}:${2:-}" in
  show: | show:--json) inv_show "${2:-}" ;;
  *) inv_usage ;;
esac
