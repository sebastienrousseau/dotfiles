#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Dotfiles CLI - Meta Commands
# docs, learn, keys (prewarm, sandbox, upgrade, mcp, mode and agent are
# plugins)

set -euo pipefail

_META_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../lib/dot/utils.sh
source "$_META_DIR/../../../lib/dot/utils.sh"
# shellcheck source=../../../lib/dot/log.sh
source "$_META_DIR/../../../lib/dot/log.sh"

meta_banner_section() {
  case "${1:-}" in
    docs | keys | learn | search | help | version)
      printf '%s\n' "Reference"
      ;;
    *)
      printf '%s\n' "Meta"
      ;;
  esac
}

dot_ui_command_banner "$(meta_banner_section "${1:-}")" "${1:-}" "$@"

cmd_docs() {
  local src_dir
  src_dir="$(resolve_source_dir)"

  if [ -n "$src_dir" ] && [ -f "$src_dir/README.md" ]; then
    if has_command glow; then
      glow "$src_dir/README.md"
    else
      exec cat "$src_dir/README.md"
    fi
  else
    die "README not found."
  fi
}

cmd_learn() {
  local dot_bin
  # Post-Phase-4b: dot_local/ lives under defaults/. Legacy layout
  # (older deployments before .chezmoiroot activation) kept it at
  # repo root — probe both.
  dot_bin="$(dirname "${BASH_SOURCE[0]}")/../../../defaults/dot_local/bin"
  [[ -f "$dot_bin/executable_tour" ]] ||
    dot_bin="$(dirname "${BASH_SOURCE[0]}")/../../../dot_local/bin"
  if [ -f "$dot_bin/executable_tour" ]; then
    exec bash "$dot_bin/executable_tour" "$@"
  fi
  # Fallback to ops script
  run_script "scripts/ops/tour.sh" "Tour script" "$@"
}

cmd_keys() {
  local src_dir
  src_dir="$(resolve_source_dir)"

  if [[ "${1:-}" == "sign-check" ]]; then
    ui_header "Git Signing Status"
    local signing_key="" format="" key_file=""
    signing_key="$(git config --global user.signingkey 2>/dev/null || true)"
    format="$(git config --global gpg.format 2>/dev/null || true)"
    if [[ -z "$signing_key" ]]; then
      ui_warn "No signing key configured (git config --global user.signingkey)"
    else
      ui_info "Key" "$signing_key"
      ui_info "Format" "${format:-gpg}"
      if [[ "$format" == "ssh" ]]; then
        key_file="${signing_key/#\~/$HOME}"
        if [[ -f "$key_file" ]]; then
          ui_info "Status" "SSH key file exists: $key_file"
        else
          ui_warn "SSH key file not found: $key_file"
        fi
      else
        if has_command gpg && gpg --list-keys "$signing_key" >/dev/null 2>&1; then
          ui_info "Status" "GPG key found in keyring"
        else
          ui_warn "GPG key not found in keyring: $signing_key"
        fi
      fi
    fi
    return 0
  fi

  # The keybindings document lives at docs/security/KEYS.md. Probing only
  # docs/KEYS.md meant every `dot keys` fell through to
  # scripts/diagnostics/keys.sh, which is not in the tree either, so the
  # command could only ever report "Keys script not found". The legacy path
  # stays in the list for trees that predate the move.
  local keys_doc=""
  if [ -n "$src_dir" ]; then
    local candidate
    for candidate in docs/security/KEYS.md docs/KEYS.md; do
      if [ -f "$src_dir/$candidate" ]; then
        keys_doc="$src_dir/$candidate"
        break
      fi
    done
  fi

  if [ -n "$keys_doc" ]; then
    if [ -n "${1:-}" ]; then
      # ripgrep is not installed everywhere (the CI runners have none), and
      # a bare `rg` there printed nothing at all while exiting 0.
      if has_command rg; then
        rg -i --fixed-strings --context 1 "${1:-}" "$keys_doc" || true
      else
        grep -i -F -C 1 -- "${1:-}" "$keys_doc" || true
      fi
    else
      exec cat "$keys_doc"
    fi
  else
    run_script "scripts/diagnostics/keys.sh" "Keys script" "$@"
  fi
}

# Dispatch
case "${1:-}" in
  docs)
    shift
    cmd_docs "$@"
    ;;
  learn)
    shift
    cmd_learn "$@"
    ;;
  keys)
    shift
    cmd_keys "$@"
    ;;
  --help | -h | help)
    cat <<'EOF'
Usage: meta.sh <command> [args...]

Commands:
  docs, learn, keys
EOF
    ;;
  "")
    cat <<'EOF'
Usage: meta.sh <command> [args...]

Commands:
  docs, learn, keys
EOF
    exit 1
    ;;
  *)
    echo "Unknown meta command: ${1:-}" >&2
    exit 1
    ;;
esac
