#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
## A2A v0.3 and agent card conformance validation.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

# shellcheck source=../../lib/dot/ui.sh
source "$SCRIPT_DIR/../../lib/dot/ui.sh"

JSON_MODE=0
STRICT_MODE=0
_a2a_parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json | -j) JSON_MODE=1 ;;
      --strict | -s) STRICT_MODE=1 ;;
    esac
    shift
  done
}

a2a_card="$REPO_ROOT/.well-known/agent-card.json"
legacy_doc="$REPO_ROOT/.well-known/agent.json"
internal_card="$REPO_ROOT/defaults/dot_config/dotfiles/agent-card.json"
agent_profiles="$REPO_ROOT/defaults/dot_config/dotfiles/agent-profiles.json"
status="healthy"
issues=()

# _a2a_require <file> <jq-expr> <issue>: record <issue> unless the
# expression holds.
_a2a_require() {
  jq -e "$2" "$1" >/dev/null 2>&1 || issues+=("$3")
}

# _a2a_forbid <file> <jq-expr> <issue>: record <issue> if it holds.
_a2a_forbid() {
  if jq -e "$2" "$1" >/dev/null 2>&1; then
    issues+=("$3")
  fi
}

# The primary A2A card, the legacy document, the internal card and the
# agent profiles must all exist.
_a2a_check_files() {
  [[ -f "$a2a_card" ]] || issues+=("missing:.well-known/agent-card.json")
  [[ -f "$legacy_doc" ]] || issues+=("missing:.well-known/agent.json")
  [[ -f "$internal_card" ]] || issues+=("missing:agent-card.json")
  [[ -f "$agent_profiles" ]] || issues+=("missing:agent-profiles.json")
}

# Validate the A2A v0.3 card.
_a2a_check_card() {
  local spec_version skills_count signing_method
  spec_version="$(jq -r '.specVersion // empty' "$a2a_card")"
  [[ "$spec_version" == "0.3" ]] || issues+=("specVersion:expected 0.3, got $spec_version")

  # Skills array
  _a2a_require "$a2a_card" '.skills | type == "array"' "skills:missing or not array"
  skills_count="$(jq '.skills | length' "$a2a_card" 2>/dev/null || echo 0)"
  [[ "$skills_count" -gt 0 ]] || issues+=("skills:empty array")

  _a2a_require "$a2a_card" '.authentication' "authentication:missing"

  # Signing metadata
  signing_method="$(jq -r '.signing.method // empty' "$a2a_card")"
  [[ -n "$signing_method" ]] || issues+=("signing:missing method")

  _a2a_require "$a2a_card" '.capabilities' "capabilities:missing"

  # Protocol must be "a2a" not "a2a-ready"
  _a2a_forbid "$a2a_card" '.protocols | index("a2a-ready")' "protocols:should use 'a2a' not 'a2a-ready'"
  _a2a_require "$a2a_card" '.protocols | index("a2a")' "protocols:missing 'a2a'"
}

# The internal card also uses v0.3 and "a2a"; the legacy doc points to the
# new card.
_a2a_check_internal_and_legacy() {
  local internal_spec
  internal_spec="$(jq -r '.specVersion // empty' "$internal_card")"
  [[ "$internal_spec" == "0.3" ]] || issues+=("internal-card:specVersion expected 0.3")
  _a2a_forbid "$internal_card" '.protocols | index("a2a-ready")' "internal-card:should use 'a2a' not 'a2a-ready'"

  _a2a_require "$legacy_doc" '.a2aCard' "legacy:missing a2aCard pointer"
  _a2a_forbid "$legacy_doc" '.protocols | index("a2a-ready")' "legacy:should use 'a2a' not 'a2a-ready'"
}

# Name consistency, the default profile, and card signing.
_a2a_check_consistency() {
  local a2a_name internal_name legacy_name default_profile
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
  _a2a_require "$internal_card" '.security.cardSigning' "internal-card:missing cardSigning in security"
}

# Build the JSON payload (issues escaped by jq).
_a2a_payload() {
  local issues_json strict=false
  if [[ "${#issues[@]}" -gt 0 ]]; then
    issues_json="$(printf '%s\n' "${issues[@]}" | jq -R . | jq -s .)"
  else
    issues_json="[]"
  fi
  [[ "$STRICT_MODE" -eq 1 ]] && strict=true
  jq -n \
    --arg status "$status" \
    --arg a2a_card "$a2a_card" \
    --arg legacy_doc "$legacy_doc" \
    --arg internal_card "$internal_card" \
    --arg agent_profiles "$agent_profiles" \
    --argjson strict "$strict" \
    --argjson issues "$issues_json" \
    '{status: $status, strict: $strict, specVersion: "0.3", files: {a2a_card: $a2a_card, legacy_doc: $legacy_doc, internal_card: $internal_card, agent_profiles: $agent_profiles}, issues: $issues}'
}

_a2a_report() {
  local issue
  ui_dot_banner "AI and Agents"
  ui_header "A2A v0.3 Conformance"
  if [[ "$status" == "healthy" ]]; then
    ui_ok "Status" "healthy"
    ui_ok "Spec version" "0.3"
    ui_ok "A2A card" "$a2a_card"
    ui_ok "Legacy doc" "$legacy_doc"
    ui_ok "Internal card" "$internal_card"
    return 0
  fi
  ui_warn "Status" "issues"
  while IFS= read -r issue; do
    [[ -n "$issue" ]] || continue
    ui_warn "Issue" "$issue"
  done < <(printf '%s' "$payload" | jq -r '.issues[]')
}

_a2a_main() {
  _a2a_parse_args "$@"
  command -v jq >/dev/null 2>&1 || {
    echo "jq is required for A2A conformance checks." >&2
    exit 1
  }
  _a2a_check_files
  if [[ "${#issues[@]}" -eq 0 ]]; then
    _a2a_check_card
    _a2a_check_internal_and_legacy
    _a2a_check_consistency
  fi
  if [[ "${#issues[@]}" -gt 0 ]]; then
    status="issues"
  fi
  payload="$(_a2a_payload)"
  if [[ "$JSON_MODE" -eq 1 ]]; then
    printf '%s\n' "$payload"
  else
    _a2a_report
  fi
  if [[ "$STRICT_MODE" -eq 1 && "$status" != "healthy" ]]; then
    exit 1
  fi
}

_a2a_main "$@"
