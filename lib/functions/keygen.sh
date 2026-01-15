#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - SSH Key Generator (keygen)
# Made with ♥ by Sebastien Rousseau
# License: MIT
#
# Description:
#   keygen is a utility function to generate high-quality SSH key pairs with
#   strong encryption and entropy. Supports ed25519, RSA, ECDSA, and DSA keys
#   with configurable key lengths.
#
# Usage:
#   keygen [name] [email] [type] [bits]
#   keygen --help
#
# Arguments:
#   name        The name for the SSH key (e.g., username, service name)
#   email       The email address associated with the key
#   type        Key type (ed25519, rsa, ecdsa, dsa). Default: ed25519
#   bits        Key length in bits (RSA: 2048-8192, ECDSA: 256/384/521)
#   --help      Displays this help menu and exits
#
################################################################################

log_info() {
  echo "[INFO] $*"
}

log_warning() {
  echo "[WARNING] $*" >&2
}

log_error() {
  echo "[ERROR] $*" >&2
  exit 1
}

keygen() {
  # Display help menu
  if [[ "$1" == "--help" ]]; then
    cat << 'EOH'
SSH Key Generator (keygen)

Description:
  keygen is a utility function to generate high-quality SSH key pairs with
  strong encryption and entropy. Supports ed25519, RSA, ECDSA, and DSA keys
  with configurable key lengths.

Usage:
  keygen [name] [email] [type] [bits]
  keygen --help

Arguments:
  name        The name for the SSH key (e.g., username, service name).
              This name is used to create a unique file path for the key.
  email       The email address associated with the key.
  type        Key type (ed25519, rsa, ecdsa, dsa). Default: ed25519.
  bits        Key length in bits:
             - RSA:   2048-8192 bits (default: 4096).
             - ECDSA: 256, 384, or 521 bits (default: 256).
             - DSA:   1024, 2048, or 3072 bits (default: 3072).
             - ED25519: Fixed length.
  --help      Displays this help menu and exits.

Examples:
  keygen
      # Interactive mode with prompts.

  keygen mykey myemail@example.com
      # Generates an ed25519 key pair named 'mykey'.

  keygen mykey myemail@example.com rsa 4096
      # Generates a 4096-bit RSA key pair named 'mykey'.

  keygen mykey myemail@example.com ecdsa 256
      # Generates a 256-bit ECDSA key pair named 'mykey'.

  keygen mykey myemail@example.com dsa 1024
      # Generates a 1024-bit DSA key pair named 'mykey'.

Notes:
  - Keys are stored in ~/.ssh with the specified name.
  - Public keys are copied to the clipboard for convenience.
  - The private key is never exposed; keep it secure.

EOH
    return 0
  fi

  # Ensure ~/.ssh directory exists
  mkdir -p -m 700 ~/.ssh || log_error "Failed to create ~/.ssh directory."

  # Collect inputs
  local name email key_type key_bits
  if [[ $# -eq 0 ]]; then
    echo "Enter a unique name for the SSH key (e.g., 'myserver' or 'username'):"
    read -r name
    echo "Enter an email address associated with the key:"
    read -r email
    echo "Enter key type (ed25519, rsa, ecdsa, dsa) [default: ed25519]:"
    read -r key_type
    key_type="${key_type:-ed25519}"

    if [[ "${key_type}" != "ed25519" ]]; then
      case "${key_type}" in
        "rsa") echo "Enter RSA key length (2048-8192) [default: 4096]:" && read -r key_bits ;;
        "ecdsa") echo "Enter ECDSA key length (256/384/521) [default: 256]:" && read -r key_bits ;;
        "dsa") echo "Enter DSA key length (1024/2048/3072) [default: 3072]:" && read -r key_bits ;;
        *) log_error "Invalid key type: ${key_type}" ;;
      esac
    fi
  elif [[ $# -ge 2 ]]; then
    name="$1"
    email="$2"
    key_type="${3:-ed25519}"
    key_bits="$4"
  else
    log_error "Usage: keygen [name] [email] [type] [bits] or keygen --help"
  fi

  # Validate inputs
  [[ ! "${name}" =~ ^[a-zA-Z0-9_-]+$ ]] && log_error "Invalid name format. Only alphanumeric, _, and - are allowed."
  [[ ! "${email}" =~ ^[^@]+@[^@]+\.[^@]+$ ]] && log_error "Invalid email format."

  # Key validation
  key_type="${key_type:-ed25519}"
  case "${key_type}" in
    "ed25519") ;;
    "rsa")
      key_bits="${key_bits:-4096}"
      [[ ! "${key_bits}" =~ ^[0-9]+$ ]] && log_error "RSA key length must be a number."
      [[ "${key_bits}" -lt 2048 || "${key_bits}" -gt 8192 ]] && log_error "RSA key length must be between 2048 and 8192 bits."
      ;;
    "ecdsa")
      key_bits="${key_bits:-256}"
      [[ ! "${key_bits}" =~ ^(256|384|521)$ ]] && log_error "ECDSA key length must be 256, 384, or 521 bits."
      ;;
    "dsa")
      key_bits="${key_bits:-3072}"
      [[ ! "${key_bits}" =~ ^(1024|2048|3072)$ ]] && log_error "DSA key length must be 1024, 2048, or 3072 bits."
      ;;
    *) log_error "Invalid key type: ${key_type}. Use 'ed25519', 'rsa', 'ecdsa', or 'dsa'." ;;
  esac

  # Set file paths
  local key_path="${HOME}/.ssh/id_${key_type}_${name}"

  # Generate key pair
  log_info "Generating ${key_type} SSH key named '${name}'..."
  if [[ "${key_type}" == "ed25519" ]]; then
    ssh-keygen -t ed25519 -f "${key_path}" -C "${email}"
  else
    ssh-keygen -t "${key_type}" -b "${key_bits}" -f "${key_path}" -C "${email}"
  fi

  # Set permissions
  chmod 600 "${key_path}" && chmod 644 "${key_path}.pub"

  # Add to SSH agent
  if ! ssh-add "${key_path}" &>/dev/null; then
    log_warning "SSH agent not running. Start it and run 'ssh-add ${key_path}'."
  fi

  # Copy to clipboard
  copy_to_clipboard "${key_path}.pub"

  # Display success message
  log_info "SSH key successfully generated!"
  echo "  Private key: ${key_path}"
  echo "  Public key: ${key_path}.pub"

  # Display fingerprint
  ssh-keygen -l -f "${key_path}.pub"
}

copy_to_clipboard() {
  local pub_key_file="$1"
  if command -v pbcopy &>/dev/null; then
    pbcopy < "${pub_key_file}"
    log_info "Public key copied to clipboard (macOS)."
  elif command -v xclip &>/dev/null; then
    xclip -selection clipboard < "${pub_key_file}"
    log_info "Public key copied to clipboard (Linux)."
  elif command -v wl-copy &>/dev/null; then
    wl-copy < "${pub_key_file}"
    log_info "Public key copied to clipboard (Wayland)."
  elif command -v clip.exe &>/dev/null; then
    clip.exe < "${pub_key_file}"
    log_info "Public key copied to clipboard (Windows)."
  else
    log_warning "Clipboard tool not available. Public key not copied."
  fi
}
