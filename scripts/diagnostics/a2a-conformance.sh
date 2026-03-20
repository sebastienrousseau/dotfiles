#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
## A2A and agent card conformance validation.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"

JSON_MODE=0
STRICT_MODE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json | -j)
      JSON_MODE=1
      shift
      ;;
    --strict | -s)
      STRICT_MODE=1
      shift
      ;;
    *)
      shift
      ;;
  esac
done

command -v jq >/dev/null 2>&1 || {
  echo "jq is required for A2A conformance checks." >&2
  exit 1
}

agent_doc="$REPO_ROOT/.well-known/agent.json"
agent_card="$REPO_ROOT/dot_config/dotfiles/agent-card.json"
agent_profiles="$REPO_ROOT/dot_config/dotfiles/agent-profiles.json"
status="healthy"
issues=()

if [[ ! -f "$agent_doc" ]]; then
  issues+=("missing:.well-known/agent.json")
fi
if [[ ! -f "$agent_card" ]]; then
  issues+=("missing:agent-card.json")
fi
if [[ ! -f "$agent_profiles" ]]; then
  issues+=("missing:agent-profiles.json")
fi

if [[ "${#issues[@]}" -eq 0 ]]; then
  agent_name="$(jq -r '.name // empty' "$agent_doc")"
  card_name="$(jq -r '.name // empty' "$agent_card")"
  card_pointer="$(jq -r '.card // empty' "$agent_doc")"
  default_profile="$(jq -r '.defaultProfile // empty' "$agent_card")"

  [[ "$card_pointer" == "dot_config/dotfiles/agent-card.json" ]] || issues+=("card-pointer:mismatch")
  [[ -n "$agent_name" && "$agent_name" == "$card_name" ]] || issues+=("name:mismatch")
  jq -e '.protocols | index("mcp")' "$agent_doc" >/dev/null || issues+=("protocols:mcp-missing")
  jq -e '.protocols | index("a2a-ready")' "$agent_doc" >/dev/null || issues+=("protocols:a2a-ready-missing")
  jq -e '.capabilities | index("replayable-checkpoints")' "$agent_doc" >/dev/null || issues+=("capabilities:replayable-checkpoints-missing")
  jq -e '.capabilities | index("fleet-attestation-export")' "$agent_doc" >/dev/null || issues+=("capabilities:fleet-attestation-export-missing")
  jq -e '.capabilities | index("policy-bundle-releases")' "$agent_doc" >/dev/null || issues+=("capabilities:policy-bundle-releases-missing")
  jq -e '.entrypoints.attestation == "dot attest --json"' "$agent_card" >/dev/null || issues+=("entrypoint:attestation-mismatch")
  jq -e '.entrypoints.mcp == "dot mcp --strict --json"' "$agent_card" >/dev/null || issues+=("entrypoint:mcp-mismatch")
  jq -e '.security.replayableCheckpoints == true' "$agent_card" >/dev/null || issues+=("security:replayable-checkpoints-missing")
  jq -e '.security.fleetAttestationExport == true' "$agent_card" >/dev/null || issues+=("security:fleet-attestation-export-missing")
  jq -e --arg profile "$default_profile" '.profiles[$profile]' "$agent_profiles" >/dev/null || issues+=("default-profile:missing")
fi

if [[ "${#issues[@]}" -gt 0 ]]; then
  status="issues"
fi

payload="$(jq -n \
  --arg status "$status" \
  --arg agent_doc "$agent_doc" \
  --arg agent_card "$agent_card" \
  --arg agent_profiles "$agent_profiles" \
  --argjson strict "$([[ "$STRICT_MODE" -eq 1 ]] && echo true || echo false)" \
  --argjson issues "$(printf '%s\n' "${issues[@]}" | jq -R . | jq -s .)" \
  '{status: $status, strict: $strict, files: {agent_json: $agent_doc, agent_card: $agent_card, agent_profiles: $agent_profiles}, issues: $issues}')"

if [[ "$JSON_MODE" -eq 1 ]]; then
  printf '%s\n' "$payload"
else
  ui_dot_banner "AI and Agents"
  ui_header "A2A Conformance"
  if [[ "$status" == "healthy" ]]; then
    ui_ok "Status" "healthy"
    ui_ok "Agent discovery" "$agent_doc"
    ui_ok "Agent card" "$agent_card"
  else
    ui_warn "Status" "issues"
    while IFS= read -r issue; do
      [[ -n "$issue" ]] || continue
      ui_warn "Issue" "$issue"
    done < <(printf '%s' "$payload" | jq -r '.issues[]')
  fi
fi

if [[ "$STRICT_MODE" -eq 1 && "$status" != "healthy" ]]; then
  exit 1
fi
