#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
## Workstation attestation export.
##
## Produces a machine-readable evidence record for the current dotfiles
## workstation state: version, platform, signing, MCP posture, and agent mode.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
# Export so child processes (the mcp-doctor subprocess below) inherit it
# without the env-prefix dance that confuses shellcheck (SC2097/SC2098).
export REPO_ROOT

# shellcheck source=../../lib/dot/ui.sh
source "$SCRIPT_DIR/../../lib/dot/ui.sh"
# shellcheck source=../../lib/dot/platform.sh
source "$SCRIPT_DIR/../../lib/dot/platform.sh"
# shellcheck source=../../lib/dot/utils.sh
source "$SCRIPT_DIR/../../lib/dot/utils.sh"

JSON_MODE=0
WRITE_PATH=""
FLEET_STORE=""
FLEET_ID=""
VERIFY=0
VERIFY_MAX_AGE=""

# usage_error <message> — a malformed command line is exit 2 with the reason
# on stderr, not the silent rc=1 a failed `shift 2` used to produce under
# set -e when a value-taking option was the last argument.
usage_error() {
  printf 'dot attest: %s\n' "$1" >&2
  exit 2
}

# require_value <option> <argc> — the option needs a value after it.
require_value() {
  if [[ "$2" -lt 2 ]]; then
    usage_error "option '$1' requires a value"
  fi
}

_parse_attest_args() {
  EVIDENCE_FILE=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json | -j)
        JSON_MODE=1
        shift
        ;;
      --verify | -V)
        VERIFY=1
        shift
        ;;
      --max-age | -a)
        require_value "$1" $#
        VERIFY_MAX_AGE="$2"
        VERIFY=1
        shift 2
        ;;
      --write | -w)
        require_value "$1" $#
        WRITE_PATH="$2"
        shift 2
        ;;
      --fleet-store | -F)
        require_value "$1" $#
        FLEET_STORE="$2"
        shift 2
        ;;
      --fleet-id | -I)
        require_value "$1" $#
        FLEET_ID="$2"
        shift 2
        ;;
      -*) usage_error "unknown option '$1'" ;;
      *)
        _take_operand "$1"
        shift
        ;;
    esac
  done
  _verify_evidence_file
}

# _take_operand WORD — the one operand: the evidence file `--verify` checks.
_take_operand() {
  [[ -z "$EVIDENCE_FILE" ]] || usage_error "unexpected argument '$1'"
  EVIDENCE_FILE="$1"
}

# _set_verify_args — VERIFY_ARGS: the flags attest-verify.sh takes from ours.
_set_verify_args() {
  VERIFY_ARGS=(--verify)
  [[ "$JSON_MODE" -eq 1 ]] && VERIFY_ARGS+=(--json)
  [[ -n "$VERIFY_MAX_AGE" ]] && VERIFY_ARGS+=(--max-age "$VERIFY_MAX_AGE")
  return 0
}

# _verify_evidence_file — `--verify FILE` checks that record instead of a
# fresh one; a file operand without --verify is a usage error.
_verify_evidence_file() {
  [[ -n "$EVIDENCE_FILE" ]] || return 0
  [[ "$VERIFY" -eq 1 ]] || usage_error "unexpected argument '$EVIDENCE_FILE' (only verify takes a file)"
  _set_verify_args
  exec bash "$SCRIPT_DIR/attest-verify.sh" "${VERIFY_ARGS[@]}" -- "$EVIDENCE_FILE"
}
_parse_attest_args "$@"

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
agent_profile_file="$REPO_ROOT/defaults/dot_config/dotfiles/agent-profiles.json"
agent_card_file="$REPO_ROOT/defaults/dot_config/dotfiles/agent-card.json"
agent_state_file="${AGENT_STATE_FILE:-$HOME/.config/dotfiles/agent-mode.env}"
policy_bundles_file="$REPO_ROOT/defaults/dot_config/dotfiles/policy-bundles.json"
model_registry_file="$REPO_ROOT/defaults/dot_config/dotfiles/model-registry.json"
prompt_registry_file="$REPO_ROOT/defaults/dot_config/dotfiles/prompt-registry.json"
mcp_policy_file="$REPO_ROOT/defaults/dot_config/dotfiles/mcp-policy.json"
mcp_registry_file="$REPO_ROOT/defaults/dot_config/dotfiles/mcp-registry.json"
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

MCP_CONFIG="$REPO_ROOT/defaults/dot_config/claude/mcp_servers.json"
export MCP_CONFIG
mcp_summary="$(bash "$REPO_ROOT/scripts/diagnostics/mcp-doctor.sh" --strict --json || true)"

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

_write_fleet_attestation() {
  local fleet_root="${FLEET_STORE%/}"
  local fleet_id="${FLEET_ID:-${DOTFILES_FLEET_ID:-default}}"
  local fleet_host="${hostname_value:-unknown-host}"
  local fleet_dir="$fleet_root/$fleet_id/$fleet_host"
  mkdir -p "$fleet_dir"
  printf '%s\n' "$1" >"$fleet_dir/workstation-attestation.json"
  printf '%s\n' "$1" >"$fleet_dir/workstation-attestation-$(date -u +%Y%m%dT%H%M%SZ).json"
}

if [[ -n "$FLEET_STORE" ]]; then
  _write_fleet_attestation "$attestation_json"
fi

_verify_attestation() {
  local verify_status=0
  _set_verify_args
  printf '%s\n' "$1" |
    bash "$SCRIPT_DIR/attest-verify.sh" "${VERIFY_ARGS[@]}" || verify_status=$?
  exit "$verify_status"
}

if [[ "$VERIFY" -eq 1 ]]; then
  _verify_attestation "$attestation_json"
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
    ui_ok "Fleet store" "${FLEET_STORE%/}/${FLEET_ID:-${DOTFILES_FLEET_ID:-default}}/${hostname_value:-unknown-host}"
  fi
fi
