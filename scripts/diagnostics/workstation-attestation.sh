#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
## Workstation attestation export.
##
## Produces a machine-readable evidence record for the current dotfiles
## workstation state: version, platform, signing, MCP posture, and agent mode.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"
# shellcheck source=../dot/lib/platform.sh
source "$SCRIPT_DIR/../dot/lib/platform.sh"
# shellcheck source=../dot/lib/utils.sh
source "$SCRIPT_DIR/../dot/lib/utils.sh"

JSON_MODE=0
WRITE_PATH=""
FLEET_STORE=""
FLEET_ID=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json | -j)
      JSON_MODE=1
      shift
      ;;
    --write | -w)
      WRITE_PATH="${2:-}"
      shift 2
      ;;
    --fleet-store | -F)
      FLEET_STORE="${2:-}"
      shift 2
      ;;
    --fleet-id | -I)
      FLEET_ID="${2:-}"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

command -v jq >/dev/null 2>&1 || {
  echo "jq is required for workstation attestation." >&2
  exit 1
}

ui_init

if [[ -z "$FLEET_STORE" && -n "${DOTFILES_FLEET_STORE:-}" ]]; then
  FLEET_STORE="$DOTFILES_FLEET_STORE"
fi

attestation_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/attestations"
if [[ -n "$WRITE_PATH" ]]; then
  mkdir -p "$(dirname "$WRITE_PATH")"
elif [[ "$JSON_MODE" -ne 1 && -z "$FLEET_STORE" ]]; then
  mkdir -p "$attestation_dir"
  WRITE_PATH="$attestation_dir/workstation-attestation.json"
fi

dot_version="$(dotfiles_version)"
platform_id="$(dot_platform_id)"
host_os="$(dot_host_os)"
arch="$(uname -m)"
hostname_value="$(hostname 2>/dev/null || true)"
agent_profile_file="$REPO_ROOT/dot_config/dotfiles/agent-profiles.json"
agent_card_file="$REPO_ROOT/dot_config/dotfiles/agent-card.json"
agent_state_file="${AGENT_STATE_FILE:-$HOME/.config/dotfiles/agent-mode.env}"
policy_bundles_file="$REPO_ROOT/dot_config/dotfiles/policy-bundles.json"
model_registry_file="$REPO_ROOT/dot_config/dotfiles/model-registry.json"
prompt_registry_file="$REPO_ROOT/dot_config/dotfiles/prompt-registry.json"
mcp_policy_file="$REPO_ROOT/dot_config/dotfiles/mcp-policy.json"
mcp_registry_file="$REPO_ROOT/dot_config/dotfiles/mcp-registry.json"
signing_format="$(git config --global gpg.format 2>/dev/null || echo ssh)"
signing_key="$(git config --global user.signingkey 2>/dev/null || true)"
allowed_signers="$(git config --global gpg.ssh.allowedSignersFile 2>/dev/null || echo "$HOME/.config/git/allowed_signers")"
merge_verify="$(git config --global --bool merge.verifySignatures 2>/dev/null || echo false)"

if [[ -f "$agent_state_file" ]]; then
  current_profile="$(sed -n 's/^DOT_AGENT_PROFILE=//p' "$agent_state_file" | tail -n 1)"
else
  current_profile=""
fi
if [[ -z "$current_profile" ]] && [[ -f "$agent_profile_file" ]]; then
  current_profile="$(jq -r '.defaultProfile // "ask"' "$agent_profile_file")"
fi

mcp_summary="$(REPO_ROOT="$REPO_ROOT" MCP_CONFIG="$REPO_ROOT/dot_config/claude/mcp_servers.json" bash "$REPO_ROOT/scripts/diagnostics/mcp-doctor.sh" --strict --json)"

attestation_json="$(
  jq -n \
    --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg repo_root "$REPO_ROOT" \
    --arg version "$dot_version" \
    --arg platform "$platform_id" \
    --arg host_os "$host_os" \
    --arg arch "$arch" \
    --arg hostname "$hostname_value" \
    --arg signing_format "$signing_format" \
    --arg signing_key "$signing_key" \
    --arg allowed_signers "$allowed_signers" \
    --argjson merge_verify "$([[ "$merge_verify" == "true" ]] && echo true || echo false)" \
    --arg current_profile "$current_profile" \
    --argjson mcp "$mcp_summary" \
    --slurpfile agent_profiles "$agent_profile_file" \
    --slurpfile agent_card "$agent_card_file" \
    --slurpfile policy_bundles "$policy_bundles_file" \
    --slurpfile model_registry "$model_registry_file" \
    --slurpfile prompt_registry "$prompt_registry_file" \
    --slurpfile mcp_policy "$mcp_policy_file" \
    --slurpfile mcp_registry "$mcp_registry_file" \
    '{
      generated_at: $generated_at,
      repo_root: $repo_root,
      dotfiles_version: $version,
      platform: {
        runtime: $platform,
        host_os: $host_os,
        architecture: $arch,
        hostname: $hostname
      },
      git_signing: {
        format: $signing_format,
        signing_key: $signing_key,
        allowed_signers_file: $allowed_signers,
        merge_verify_signatures: $merge_verify
      },
      agent: {
        current_profile: $current_profile,
        profiles: $agent_profiles[0],
        card: $agent_card[0]
      },
      governance: {
        policy_bundles: $policy_bundles[0],
        model_registry: $model_registry[0],
        prompt_registry: $prompt_registry[0]
      },
      mcp: {
        doctor: $mcp,
        policy: $mcp_policy[0],
        registry: $mcp_registry[0]
      }
    }'
)"

if [[ -n "$WRITE_PATH" ]]; then
  printf '%s\n' "$attestation_json" >"$WRITE_PATH"
fi

if [[ -n "$FLEET_STORE" ]]; then
  fleet_root="${FLEET_STORE%/}"
  fleet_id="${FLEET_ID:-${DOTFILES_FLEET_ID:-default}}"
  fleet_host="${hostname_value:-unknown-host}"
  fleet_dir="$fleet_root/$fleet_id/$fleet_host"
  fleet_file="$fleet_dir/workstation-attestation.json"
  fleet_timestamp_file="$fleet_dir/workstation-attestation-$(date -u +%Y%m%dT%H%M%SZ).json"
  mkdir -p "$fleet_dir"
  printf '%s\n' "$attestation_json" >"$fleet_file"
  printf '%s\n' "$attestation_json" >"$fleet_timestamp_file"
fi

if [[ "$JSON_MODE" -eq 1 ]]; then
  printf '%s\n' "$attestation_json"
else
  ui_dot_banner "Diagnostics"
  ui_header "Workstation Attestation"
  ui_ok "Version" "$dot_version"
  ui_ok "Platform" "$platform_id / $host_os / $arch"
  ui_ok "Agent profile" "$current_profile"
  ui_ok "MCP status" "$(printf '%s' "$mcp_summary" | jq -r '.status')"
  ui_ok "Output" "$WRITE_PATH"
  if [[ -n "$FLEET_STORE" ]]; then
    ui_ok "Fleet store" "$fleet_root/$fleet_id/$fleet_host"
  fi
fi
