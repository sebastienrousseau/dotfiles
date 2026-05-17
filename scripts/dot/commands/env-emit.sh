#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
#
# `dot env emit` — render a portable workstation-environment
# manifest. The output is the canonical "what is installed on this
# machine + at what version + from which source" record that
# downstream tooling (CycloneDX SBOM aggregators, AgentSpec /
# AAIF agents, EU CRA compliance reports) consumes.
#
# v1 schema at docs/schema/dot-env-v1.json. Conforming to a fixed
# schema lets us re-render this manifest into any downstream format
# (AGENTS.md, devcontainer-feature.json, Brewfile, mise.toml) from
# a single source of truth — see docs/operations/MANIFEST.md.
#
# Usage:
#   dot env emit                       # default: json
#   dot env emit --format json
#   dot env emit --output env.json
#   dot env emit --pretty              # default; --compact for one-line
#
# Exit codes:
#   0  manifest written / printed
#   1  bad usage
#   2  jq or mise missing
#   3  mise call failed

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../lib/dot/utils.sh
source "$SCRIPT_DIR/../../../lib/dot/utils.sh"

dot_env_emit() {
  local format="json"
  local output=""
  local pretty=1

  while (($#)); do
    case "$1" in
      --format)
        format="${2:-}"
        shift 2 || {
          ui_err "--format needs a value"
          return 1
        }
        ;;
      --format=*)
        format="${1#*=}"
        shift
        ;;
      --output | -o)
        output="${2:-}"
        shift 2 || {
          ui_err "--output needs a value"
          return 1
        }
        ;;
      --output=*)
        output="${1#*=}"
        shift
        ;;
      --pretty)
        pretty=1
        shift
        ;;
      --compact)
        pretty=0
        shift
        ;;
      -h | --help)
        cat <<-EOF
	Usage: dot env emit [--format <fmt>] [--output <path>] [--pretty|--compact]

	  Render the workstation-environment manifest (v1 schema).

	Formats:
	  json     (default) v1 canonical form per docs/schema/dot-env-v1.json
	  ndjson   one JSON object per tool — easier to grep / pipe

	Output:
	  --output FILE   write to FILE (atomic mktemp + mv)
	  default         stdout

	Examples:
	  dot env emit                     # print to stdout
	  dot env emit --output env.json   # write atomically
	  dot env emit --format ndjson | grep '^{"name":"node"'
	EOF
        return 0
        ;;
      *)
        ui_err "unknown flag: $1"
        return 1
        ;;
    esac
  done

  case "$format" in
    json | ndjson) ;;
    *)
      ui_err "unsupported format: $format (json, ndjson)"
      return 1
      ;;
  esac

  has_command jq || {
    ui_err "jq required (brew install jq / apt install jq)"
    return 2
  }
  has_command mise || {
    ui_err "mise required (the manifest's source of truth)"
    return 2
  }

  local mise_raw
  mise_raw="$(mise ls --json 2>/dev/null)" || {
    ui_err "mise ls --json failed"
    return 3
  }

  # Static fields we want in every manifest: schema version + emit
  # timestamp + emitter version + repo URL + the host fingerprint
  # bits chezmoi already records (os, machine).
  local emitter_version
  emitter_version="$(grep -E '^dotfiles_version[[:space:]]*=' \
    "$(require_source_dir)/.chezmoidata.toml" 2>/dev/null |
    head -1 | sed -E 's/.*"([^"]+)".*/\1/' || echo "unknown")"
  local timestamp
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local os_type machine_arch
  os_type="$(uname -s 2>/dev/null || echo unknown)"
  machine_arch="$(uname -m 2>/dev/null || echo unknown)"
  local hostname
  hostname="$(uname -n 2>/dev/null || echo unknown)"

  # Build the manifest. jq does the heavy lifting: take the raw
  # `mise ls --json` shape (an object keyed by tool name → array of
  # installed versions) and flatten to a normalised array of tool
  # records. Each record carries: name, version, source (config
  # file or "orphan"), requested (semver/range/latest spec), and
  # install_path (auditable absolute path).
  local body
  body="$(printf '%s' "$mise_raw" | jq --arg ev "$emitter_version" \
    --arg ts "$timestamp" \
    --arg os "$os_type" \
    --arg arch "$machine_arch" \
    --arg host "$hostname" '
      {
        schema_version: "https://sebastienrousseau.github.io/dotfiles/schema/dot-env-v1.json",
        manifest_version: "1.0.0",
        emitted_at: $ts,
        emitter: {
          name: "dot env emit",
          version: $ev,
          repo: "github.com/sebastienrousseau/dotfiles"
        },
        host: {
          hostname: $host,
          os: $os,
          arch: $arch
        },
        tools: [
          to_entries[] as $t
          | $t.value[]
          | {
              name: $t.key,
              version: (.version // null),
              source: (.source.path // "orphan"),
              source_type: (.source.type // null),
              requested_version: (.requested_version // null),
              install_path: (.install_path // null),
              active: (.active // false)
            }
        ]
      }
    ')"

  local rendered
  if [[ "$format" == "ndjson" ]]; then
    # NDJSON: header object on line 1, one tool per subsequent line.
    rendered="$(
      printf '%s' "$body" |
        jq -c '
        ({schema_version, manifest_version, emitted_at, emitter, host}),
        (.tools[])'
    )"
  elif ((pretty)); then
    rendered="$(printf '%s' "$body" | jq '.')"
  else
    rendered="$(printf '%s' "$body" | jq -c '.')"
  fi

  if [[ -n "$output" ]]; then
    local tmp
    tmp="$(mktemp "${output}.XXXXXX")"
    printf '%s\n' "$rendered" >|"$tmp"
    mv "$tmp" "$output"
    ui_ok "manifest" "wrote $(printf '%s' "$rendered" | jq -r '.tools | length' 2>/dev/null || echo '?') tools → $output"
  else
    printf '%s\n' "$rendered"
  fi
}
