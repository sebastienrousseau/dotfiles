#!/usr/bin/env bash
# Dotfiles CLI - Secrets Commands
# secrets-init, secrets, secrets-create, ssh-key

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"
# shellcheck source=../lib/ui.sh
source "$SCRIPT_DIR/../lib/ui.sh"

cmd_secrets_init() {
  local src_dir
  src_dir="$(resolve_source_dir)"

  if [ -n "$src_dir" ] && [ -f "$src_dir/scripts/secrets/age-init.sh" ]; then
    exec bash "$src_dir/scripts/secrets/age-init.sh" "$@"
  fi

  local secrets_dir="$HOME/.config/chezmoi"
  local key_file="$secrets_dir/key.txt"

  mkdir -p "$secrets_dir"

  if [ -f "$key_file" ]; then
    ui_logo_dot "Dot Secrets • Init"
    ui_info "Age key already exists: $key_file"
    exit 0
  fi

  if ! has_command age-keygen; then
    ui_logo_dot "Dot Secrets • Init"
    ui_error "age-keygen not found. Install 'age' first."
    exit 1
  fi

  ui_logo_dot "Dot Secrets • Init"
  age-keygen -o "$key_file"
  chmod 600 "$key_file"
  ui_success "Age key created at $key_file"
  ui_info "Public key:"
  age-keygen -y "$key_file"
}

cmd_secrets() {
  local secrets_dir="$HOME/.config/chezmoi"
  local key_file="$secrets_dir/key.txt"

  if [ ! -f "$key_file" ]; then
    ui_logo_dot "Dot Secrets • Edit"
    ui_error "No age key found. Run: dot secrets-init"
    exit 1
  fi

  ui_logo_dot "Dot Secrets • Edit"
  exec chezmoi edit --apply "$HOME/.config/chezmoi/encrypted_secrets.age"
}

cmd_secrets_create() {
  run_script "scripts/secrets/create-secrets-file.sh" "Secrets creation script" "$@"
}

cmd_ssh_key() {
  run_script "scripts/secrets/encrypt-ssh-key.sh" "SSH key encryption script" "$@"
}

# Dispatch
case "${1:-}" in
  secrets-init)
    shift
    cmd_secrets_init "$@"
    ;;
  secrets)
    shift
    cmd_secrets "$@"
    ;;
  secrets-create)
    shift
    cmd_secrets_create "$@"
    ;;
  ssh-key)
    shift
    cmd_ssh_key "$@"
    ;;
  *)
    ui_error "Unknown secrets command: ${1:-}"
    exit 1
    ;;
esac
