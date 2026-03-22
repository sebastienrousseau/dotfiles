#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
## A2A v0.3 and agent card conformance validation.

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

a2a_card="$REPO_ROOT/.well-known/agent-card.json"
legacy_doc="$REPO_ROOT/.well-known/agent.json"
internal_card="$REPO_ROOT/dot_config/dotfiles/agent-card.json"
agent_profiles="$REPO_ROOT/dot_config/dotfiles/agent-profiles.json"
status="healthy"
issues=()

# Check primary A2A v0.3 card
if [[ ! -f "$a2a_card" ]]; then
  issues+=("missing:.well-known/agent-card.json")
fi

# Check legacy agent.json
if [[ ! -f "$legacy_doc" ]]; then
  issues+=("missing:.well-known/agent.json")
fi

# Check internal card
if [[ ! -f "$internal_card" ]]; then
  issues+=("missing:agent-card.json")
fi

# Check agent profiles
if [[ ! -f "$agent_profiles" ]]; then
  issues+=("missing:agent-profiles.json")
fi

if [[ "${#issues[@]}" -eq 0 ]]; then
  # Validate A2A v0.3 card
  spec_version="$(jq -r '.specVersion // empty' "$a2a_card")"
  [[ "$spec_version" == "0.3" ]] || issues+=("specVersion:expected 0.3, got $spec_version")

  # Skills array
  jq -e '.skills | type == "array"' "$a2a_card" >/dev/null 2>&1 || issues+=("skills:missing or not array")
  skills_count="$(jq '.skills | length' "$a2a_card" 2>/dev/null || echo 0)"
  [[ "$skills_count" -gt 0 ]] || issues+=("skills:empty array")

  # Authentication block
  jq -e '.authentication' "$a2a_card" >/dev/null 2>&1 || issues+=("authentication:missing")

  # Signing metadata
  signing_method="$(jq -r '.signing.method // empty' "$a2a_card")"
  [[ -n "$signing_method" ]] || issues+=("signing:missing method")

  # Capabilities
  jq -e '.capabilities' "$a2a_card" >/dev/null 2>&1 || issues+=("capabilities:missing")

  # Protocol must be "a2a" not "a2a-ready"
  if jq -e '.protocols | index("a2a-ready")' "$a2a_card" >/dev/null 2>&1; then
    issues+=("protocols:should use 'a2a' not 'a2a-ready'")
  fi
  jq -e '.protocols | index("a2a")' "$a2a_card" >/dev/null 2>&1 || issues+=("protocols:missing 'a2a'")

  # Validate internal card also uses v0.3 and "a2a"
  internal_spec="$(jq -r '.specVersion // empty' "$internal_card")"
  [[ "$internal_spec" == "0.3" ]] || issues+=("internal-card:specVersion expected 0.3")
  if jq -e '.protocols | index("a2a-ready")' "$internal_card" >/dev/null 2>&1; then
    issues+=("internal-card:should use 'a2a' not 'a2a-ready'")
  fi

  # Validate legacy doc points to new card
  jq -e '.a2aCard' "$legacy_doc" >/dev/null 2>&1 || issues+=("legacy:missing a2aCard pointer")
  if jq -e '.protocols | index("a2a-ready")' "$legacy_doc" >/dev/null 2>&1; then
    issues+=("legacy:should use 'a2a' not 'a2a-ready'")
  fi

  # Name consistency
  a2a_name="$(jq -r '.name // empty' "$a2a_card")"
  internal_name="$(jq -r '.name // empty' "$internal_card")"
  legacy_name="$(jq -r '.name // empty' "$legacy_doc")"
  [[ "$a2a_name" == "$internal_name" ]] || issues+=("name:mismatch between a2a-card and internal card")
  [[ "$a2a_name" == "$legacy_name" ]] || issues+=("name:mismatch between a2a-card and legacy doc")

  # Default profile validation
  default_profile="$(jq -r '.defaultProfile // empty' "$internal_card")"
  if [[ -n "$default_profile" ]]; then
    jq -e --arg profile "$default_profile" '.profiles[$profile]' "$agent_profiles" >/dev/null 2>&1 || issues+=("default-profile:missing in agent-profiles.json")
  fi

  # Card signing in internal card
  jq -e '.security.cardSigning' "$internal_card" >/dev/null 2>&1 || issues+=("internal-card:missing cardSigning in security")
fi

if [[ "${#issues[@]}" -gt 0 ]]; then
  status="issues"
fi

# Build issues JSON safely
if [[ "${#issues[@]}" -gt 0 ]]; then
  issues_json="$(printf '%s\n' "${issues[@]}" | jq -R . | jq -s .)"
else
  issues_json="[]"
fi

payload="$(jq -n \
  --arg status "$status" \
  --arg a2a_card "$a2a_card" \
  --arg legacy_doc "$legacy_doc" \
  --arg internal_card "$internal_card" \
  --arg agent_profiles "$agent_profiles" \
  --argjson strict "$([[ "$STRICT_MODE" -eq 1 ]] && echo true || echo false)" \
  --argjson issues "$issues_json" \
  '{status: $status, strict: $strict, specVersion: "0.3", files: {a2a_card: $a2a_card, legacy_doc: $legacy_doc, internal_card: $internal_card, agent_profiles: $agent_profiles}, issues: $issues}')"

if [[ "$JSON_MODE" -eq 1 ]]; then
  printf '%s\n' "$payload"
else
  ui_dot_banner "AI and Agents"
  ui_header "A2A v0.3 Conformance"
  if [[ "$status" == "healthy" ]]; then
    ui_ok "Status" "healthy"
    ui_ok "Spec version" "0.3"
    ui_ok "A2A card" "$a2a_card"
    ui_ok "Legacy doc" "$legacy_doc"
    ui_ok "Internal card" "$internal_card"
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
