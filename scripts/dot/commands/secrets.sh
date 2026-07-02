#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Dotfiles CLI - Secrets/Env Commands
# secrets-init, secrets, secrets-create, ssh-key, env load

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../lib/dot/utils.sh
source "$SCRIPT_DIR/../../../lib/dot/utils.sh"
# shellcheck source=../../lib/secrets_provider.sh
source "$SCRIPT_DIR/../../lib/secrets_provider.sh"

dot_ui_command_banner "Secrets" "${1:-}"

dot_data_file() {
  local src_dir
  src_dir="$(resolve_chezmoi_source_dir)"
  [[ -z "$src_dir" ]] && src_dir="$(require_source_dir)"
  printf "%s\n" "$src_dir/.chezmoidata.toml"
}

dot_load_secrets_policy_env() {
  local data_file provider auto_load
  data_file="$(dot_data_file)"
  [[ -f "$data_file" ]] || return 0

  provider="$(awk -F'=' '
    /^\[secrets\.policy\]/ {in_policy=1; next}
    /^\[/ {if (in_policy) exit}
    in_policy && $1 ~ /provider/ {
      gsub(/["[:space:]]/, "", $2); print $2; exit
    }
  ' "$data_file")"
  auto_load="$(awk -F'=' '
    /^\[secrets\.policy\]/ {in_policy=1; next}
    /^\[/ {if (in_policy) exit}
    in_policy && $1 ~ /auto_load/ {
      gsub(/[[:space:]]/, "", $2); print $2; exit
    }
  ' "$data_file")"

  if [[ -n "$provider" && -z "${DOTFILES_SECRETS_PROVIDER:-}" ]]; then
    export DOTFILES_SECRETS_PROVIDER="$provider"
  fi
  if [[ -n "$auto_load" && -z "${DOTFILES_SECRETS_AUTO_LOAD:-}" ]]; then
    if [[ "$auto_load" == "true" ]]; then
      export DOTFILES_SECRETS_AUTO_LOAD=1
    else
      export DOTFILES_SECRETS_AUTO_LOAD=0
    fi
  fi
}

dot_load_secrets_policy_env

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
    ui_info "Age key already exists: $key_file"
    exit 0
  fi

  if ! has_command age-keygen; then
    die "age-keygen not found. Install 'age' first."
  fi

  age-keygen -o "$key_file"
  chmod 600 "$key_file"
  ui_ok "Age key created" "$key_file"
  ui_header "Public key"
  age-keygen -y "$key_file"
}

cmd_secrets_edit() {
  local secrets_dir="$HOME/.config/chezmoi"
  local key_file="$secrets_dir/key.txt"

  if [ ! -f "$key_file" ]; then
    die "No age key found. Run: dot secrets-init"
  fi

  exec chezmoi edit --apply "$HOME/.config/chezmoi/encrypted_secrets.age"
}

cmd_secrets_create() {
  run_script "scripts/secrets/create-secrets-file.sh" "Secrets creation script" "$@"
}

cmd_ssh_key() {
  run_script "scripts/secrets/encrypt-ssh-key.sh" "SSH key encryption script" "$@"
}

cmd_ssh_cert() {
  run_script "scripts/security/ssh-cert.sh" "SSH cert script" "$@"
}

cmd_secrets_provider() {
  local provider
  provider="$(dot_secrets_provider)"
  ui_info "Provider" "$provider"
}

cmd_secrets_set() {
  local key="${1:-}" value="${2:-}"
  [[ -n "$key" ]] || die "Usage: dot secrets set <KEY> [VALUE]"

  if [[ -z "$value" ]]; then
    read -r -s -p "Value for $key: " value
    echo ""
  fi
  [[ -n "$value" ]] || die "Empty value refused for key: $key"

  dot_secrets_set "$key" "$value" || die "Failed to store key: $key"
  ui_ok "Stored" "$key"
}

cmd_secrets_get() {
  local key="${1:-}" raw="${2:-}"
  [[ -n "$key" ]] || die "Usage: dot secrets get <KEY> [--raw]"
  local value
  value="$(dot_secrets_get "$key" || true)"
  [[ -n "$value" ]] || die "Secret not found: $key"
  if [[ "$raw" == "--raw" ]]; then
    printf "%s\n" "$value"
  else
    ui_ok "$key" "***"
  fi
}

cmd_secrets_list() {
  local any=0
  while IFS= read -r key; do
    any=1
    printf "%s\n" "$key"
  done < <(dot_secrets_index_list)
  if [[ "$any" -eq 0 ]]; then
    ui_warn "No secrets indexed" "use: dot secrets set <KEY> <VALUE>"
  fi
}

cmd_env_load() {
  # Usage: dot secrets load [<bucket>] [--shell posix|fish|nu]
  # Emits shell code to set the bucket's secrets as env vars, in the target
  # shell's dialect so it works beyond POSIX:
  #   posix (default):  eval "$(dot secrets load ai)"
  #   fish:             dot secrets load ai --shell fish | source
  #   nu:               load-env (dot secrets load ai --shell nu | from nuon)
  local bucket="ai" dialect="posix" data_file key value count=0
  local -a keys=() values=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --shell)
        dialect="${2:-posix}"
        shift 2
        ;;
      --shell=*)
        dialect="${1#*=}"
        shift
        ;;
      -*) die "Unknown flag: $1 (usage: dot secrets load [<bucket>] [--shell posix|fish|nu])" ;;
      *)
        bucket="$1"
        shift
        ;;
    esac
  done

  data_file="$(dot_data_file)"
  [[ -f "$data_file" ]] || die "Missing data file: $data_file"

  while IFS= read -r key; do
    value="$(dot_secrets_get "$key" || true)"
    if [[ -n "$value" ]]; then
      keys+=("$key")
      values+=("$value")
      count=$((count + 1))
    fi
  done < <(dot_secrets_bucket_keys "$data_file" "$bucket")

  [[ "$count" -gt 0 ]] || die "No secrets loaded for bucket: $bucket"

  local i k v esc
  case "$dialect" in
    posix | sh | bash | zsh)
      for i in "${!keys[@]}"; do
        printf 'export %s=%q\n' "${keys[$i]}" "${values[$i]}"
      done
      ;;
    fish)
      for i in "${!keys[@]}"; do
        v="${values[$i]}"
        esc="${v//\\/\\\\}"
        esc="${esc//\'/\\\'}" # fish single-quote escaping
        printf "set -gx %s '%s'\n" "${keys[$i]}" "$esc"
      done
      ;;
    nu | nushell)
      # Emit a NUON record for: load-env (dot secrets load <bucket> --shell nu | from nuon)
      printf '{\n'
      for i in "${!keys[@]}"; do
        v="${values[$i]}"
        esc="${v//\\/\\\\}"
        esc="${esc//\"/\\\"}" # double-quote escaping
        printf '  "%s": "%s"\n' "${keys[$i]}" "$esc"
      done
      printf '}\n'
      ;;
    *)
      die "Unknown shell dialect: $dialect (want: posix|fish|nu)"
      ;;
  esac
}

cmd_secrets_load() {
  cmd_env_load "$@"
}

# Dispatch
top="${1:-}"
case "$top" in
  secrets-init)
    shift
    cmd_secrets_init "$@"
    ;;
  secrets)
    shift || true
    sub="${1:-edit}"
    if [[ $# -gt 0 ]]; then shift; fi
    case "$sub" in
      edit) cmd_secrets_edit "$@" ;;
      set) cmd_secrets_set "$@" ;;
      get) cmd_secrets_get "$@" ;;
      list) cmd_secrets_list "$@" ;;
      load) cmd_secrets_load "$@" ;;
      provider) cmd_secrets_provider "$@" ;;
      *)
        die "Usage: dot secrets [edit|set|get|list|load|provider]"
        ;;
    esac
    ;;
  secrets-create)
    shift
    cmd_secrets_create "$@"
    ;;
  ssh-key)
    shift
    cmd_ssh_key "$@"
    ;;
  ssh-cert)
    shift
    cmd_ssh_cert "$@"
    ;;
  env)
    shift || true
    sub="${1:-load}"
    if [[ $# -gt 0 ]]; then shift; fi
    case "$sub" in
      load) cmd_env_load "$@" ;;
      *) die "Usage: dot env load <bucket>" ;;
    esac
    ;;
  *)
    echo "Unknown secrets command: ${1:-}" >&2
    exit 1
    ;;
esac
