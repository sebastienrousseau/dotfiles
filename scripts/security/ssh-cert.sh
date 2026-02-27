#!/usr/bin/env bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
# shellcheck shell=bash
set -euo pipefail

# ssh-cert.sh — Short-lived SSH certificate management
#
# Supports step-ca (Smallstep) and ssh-keygen-based CA workflows.
# Short-lived certificates reduce the blast radius of key compromise
# by expiring automatically (default: 16 hours).
#
# Usage:
#   dot ssh-cert issue [--ttl 16h] [--principal user]
#   dot ssh-cert status
#   dot ssh-cert revoke

# ---------- configuration -------------------------------------------------- #

SSH_DIR="${HOME}/.ssh"
CERT_FILE="${SSH_DIR}/id_ed25519-cert.pub"
KEY_FILE="${SSH_DIR}/id_ed25519"
DEFAULT_TTL="${SSH_CERT_TTL:-16h}"
DEFAULT_PRINCIPAL="${SSH_CERT_PRINCIPAL:-${USER}}"
CA_URL="${SSH_CERT_CA_URL:-}"
CA_PROVISIONER="${SSH_CERT_CA_PROVISIONER:-}"

# ---------- helpers -------------------------------------------------------- #

info() { printf '\033[1;34m[ssh-cert]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[ssh-cert]\033[0m %s\n' "$*" >&2; }
error() {
  printf '\033[1;31m[ssh-cert]\033[0m %s\n' "$*" >&2
  exit 1
}

check_key() {
  if [[ ! -f "$KEY_FILE" ]]; then
    error "SSH key not found at $KEY_FILE. Generate one with: ssh-keygen -t ed25519"
  fi
}

# ---------- issue ---------------------------------------------------------- #

cmd_issue() {
  local ttl="$DEFAULT_TTL"
  local principal="$DEFAULT_PRINCIPAL"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --ttl)
        ttl="$2"
        shift 2
        ;;
      --principal)
        principal="$2"
        shift 2
        ;;
      *) error "Unknown option: $1" ;;
    esac
  done

  check_key

  # Method 1: step-ca (Smallstep) — preferred for production
  if command -v step >/dev/null 2>&1 && [[ -n "$CA_URL" ]]; then
    info "Requesting certificate from step-ca ($CA_URL)..."
    local step_args=(ssh certificate "$principal" "$KEY_FILE"
      --sign
      --not-after "$ttl"
      --ca-url "$CA_URL"
      --force
    )
    if [[ -n "$CA_PROVISIONER" ]]; then
      step_args+=(--provisioner "$CA_PROVISIONER")
    fi
    step "${step_args[@]}"
    info "Certificate issued:"
    step ssh inspect "$CERT_FILE"
    return 0
  fi

  # Method 2: ssh-keygen with a local CA (for dev/testing)
  local ca_key="${SSH_DIR}/ca_key"
  if [[ ! -f "$ca_key" ]]; then
    warn "No step-ca configured and no local CA key found."
    echo ""
    echo "To use short-lived SSH certificates, choose one of:"
    echo ""
    echo "  Option A: Smallstep step-ca (recommended for production)"
    echo "    1. Install: brew install step / sudo pacman -S step-cli step-ca"
    echo "    2. Initialize CA: step ca init --name 'My CA' --provisioner admin"
    echo "    3. Start CA: step-ca \$(step path)/config/ca.json"
    echo "    4. Configure: export SSH_CERT_CA_URL=https://ca.example.com"
    echo "    5. Run: dot ssh-cert issue"
    echo ""
    echo "  Option B: Local CA key (for development/testing)"
    echo "    1. Generate CA: ssh-keygen -t ed25519 -f ~/.ssh/ca_key -C 'local-ca'"
    echo "    2. Run: dot ssh-cert issue"
    echo ""
    echo "  Environment variables:"
    echo "    SSH_CERT_CA_URL         step-ca server URL"
    echo "    SSH_CERT_CA_PROVISIONER step-ca provisioner name"
    echo "    SSH_CERT_TTL            Certificate lifetime (default: 16h)"
    echo "    SSH_CERT_PRINCIPAL      Certificate principal (default: \$USER)"
    return 1
  fi

  info "Signing with local CA key ($ca_key)..."
  info "TTL: $ttl, Principal: $principal"

  # Parse TTL to seconds for validity
  local validity="-${ttl}:+${ttl}"

  ssh-keygen \
    -s "$ca_key" \
    -I "${principal}@$(hostname)-$(date +%s)" \
    -n "$principal" \
    -V "$validity" \
    "${KEY_FILE}.pub"

  info "Certificate issued:"
  ssh-keygen -L -f "$CERT_FILE"
  info "Expires automatically after $ttl"
}

# ---------- status --------------------------------------------------------- #

cmd_status() {
  if [[ ! -f "$CERT_FILE" ]]; then
    info "No SSH certificate found at $CERT_FILE"
    return 0
  fi

  info "Current certificate:"
  ssh-keygen -L -f "$CERT_FILE"

  # Check expiry
  local valid_to
  valid_to=$(ssh-keygen -L -f "$CERT_FILE" 2>/dev/null | grep "Valid:" | sed 's/.*to //')
  if [[ -n "$valid_to" ]]; then
    local expiry_epoch
    expiry_epoch=$(date -d "$valid_to" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%S" "$valid_to" +%s 2>/dev/null || echo 0)
    local now_epoch
    now_epoch=$(date +%s)
    if ((expiry_epoch > 0 && expiry_epoch < now_epoch)); then
      warn "Certificate has EXPIRED"
      return 1
    else
      local remaining=$(((expiry_epoch - now_epoch) / 3600))
      info "Certificate valid for ~${remaining}h"
    fi
  fi
}

# ---------- revoke --------------------------------------------------------- #

cmd_revoke() {
  if [[ ! -f "$CERT_FILE" ]]; then
    info "No certificate to revoke"
    return 0
  fi

  # Step-ca revocation
  if command -v step >/dev/null 2>&1 && [[ -n "$CA_URL" ]]; then
    info "Revoking certificate via step-ca..."
    step ssh revoke "$CERT_FILE" --ca-url "$CA_URL" || true
  fi

  # Local removal
  rm -f "$CERT_FILE"
  info "Certificate removed: $CERT_FILE"
}

# ---------- main ----------------------------------------------------------- #

subcommand="${1:-}"
shift 2>/dev/null || true

case "$subcommand" in
  issue) cmd_issue "$@" ;;
  status) cmd_status ;;
  revoke) cmd_revoke ;;
  *)
    echo "Usage: dot ssh-cert <command>"
    echo ""
    echo "Commands:"
    echo "  issue   [--ttl 16h] [--principal user]  Request a short-lived certificate"
    echo "  status                                   Show current certificate status"
    echo "  revoke                                   Revoke and remove certificate"
    echo ""
    echo "Environment:"
    echo "  SSH_CERT_CA_URL          step-ca server URL (enables Smallstep mode)"
    echo "  SSH_CERT_CA_PROVISIONER  step-ca provisioner name"
    echo "  SSH_CERT_TTL             Certificate lifetime (default: 16h)"
    echo "  SSH_CERT_PRINCIPAL       Certificate principal (default: \$USER)"
    ;;
esac
