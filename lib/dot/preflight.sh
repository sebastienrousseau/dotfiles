#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Consent and prerequisites for commands that change the machine.
# Sourced by utils.sh; inherits set -euo pipefail.
#
# `dot upgrade` and `dot ai` bring a machine up to what they need, but only
# with the user's consent. The answer is NO unless someone says yes:
#
#   - DOTFILES_YES=1 (or a command's --yes)  → yes, without asking;
#   - no terminal to ask (piped, cron, CI, DOTFILES_NONINTERACTIVE=1)
#                                             → no: report, change nothing;
#   - otherwise                               → ask, default No.
#
# ui_confirm cannot be reused here: it answers its default when it cannot ask,
# and its default is yes, so an unattended run would install software.
#
# Bash 3.2 compatible (macOS /bin/bash): no associative arrays, no namerefs.

[[ -n "${_DOT_PREFLIGHT_LOADED:-}" ]] && return 0
_DOT_PREFLIGHT_LOADED=1

# dot_can_ask: a person is at a terminal to answer.
dot_can_ask() {
  [[ -t 0 && -t 1 && "${DOTFILES_NONINTERACTIVE:-0}" != "1" && -z "${CI:-}" ]]
}

# dot_consent <question>: 0 for yes. Never yes by default.
dot_consent() {
  local question="$1" answer=""
  [[ "${DOTFILES_YES:-0}" == "1" ]] && return 0
  dot_can_ask || return 1
  if [[ "${UI_ENABLED:-0}" == "1" ]] && command -v gum >/dev/null 2>&1; then
    gum confirm --default=false "$question"
    return $?
  fi
  printf '  %s [y/N] ' "$question"
  read -r answer </dev/tty || answer=""
  [[ "$answer" =~ ^[Yy] ]]
}

# dot_apply_yes_flag <args...>: -y/--yes anywhere means DOTFILES_YES=1.
dot_apply_yes_flag() {
  local arg
  for arg in "$@"; do
    case "$arg" in -y | --yes) export DOTFILES_YES=1 ;; esac
  done
}

# ── mise ────────────────────────────────────────────────────────────────

# The pinned mise release, from the deployed versions.env (one source of
# truth with the Linux provisioner), falling back to the same pin.
_dot_mise_tag() {
  local env="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/versions.env" tag=""
  [[ -f "$env" ]] && tag="$(sed -n 's/^MISE_TAG="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' "$env" | head -1)"
  [[ "$tag" == v* ]] || tag="v2026.3.8"
  printf '%s' "$tag"
}

# _dot_mise_asset: the release asset for this OS/CPU, or nothing if mise
# ships none (the caller then falls back to a package manager or gives up).
_dot_mise_asset() {
  local os arch
  case "$(uname -s)" in
    Darwin) os=macos ;;
    Linux) os=linux ;;
    *) return 1 ;;
  esac
  case "$(uname -m)" in
    arm64 | aarch64) arch=arm64 ;;
    x86_64 | amd64) arch=x64 ;;
    *) return 1 ;;
  esac
  printf 'mise-%s-%s-%s.tar.gz' "$(_dot_mise_tag)" "$os" "$arch"
}

# dot_mise_install_method: how mise would be installed here (brew, release)
# or nothing when it cannot be.
dot_mise_install_method() {
  if command -v brew >/dev/null 2>&1; then
    printf 'brew'
  elif command -v curl >/dev/null 2>&1 && _dot_mise_asset >/dev/null; then
    printf 'release'
  fi
}

# _dot_install_mise_release: the pinned official release, verified against
# its published SHASUMS256.txt, into ~/.local/bin.
_dot_install_mise_release() {
  local tag asset base tmp rc=0
  tag="$(_dot_mise_tag)"
  asset="$(_dot_mise_asset)" || return 1
  base="https://github.com/jdx/mise/releases/download/$tag"
  if ! declare -F download_verified_asset >/dev/null; then
    # shellcheck source=verified-download.sh
    source "${_DOT_LIB_DIR:-$(dirname "${BASH_SOURCE[0]}")}/verified-download.sh"
  fi
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/dot-mise.XXXXXX")"
  if download_verified_asset "$base/$asset" "$base/SHASUMS256.txt" "$asset" "$tmp/$asset" &&
    tar -xzf "$tmp/$asset" -C "$tmp" mise/bin/mise; then
    mkdir -p "$HOME/.local/bin"
    install -m 0755 "$tmp/mise/bin/mise" "$HOME/.local/bin/mise" || rc=1
  else
    rc=1
  fi
  rm -rf "$tmp"
  return "$rc"
}

# dot_install_mise: install mise by the method above. 0 when it is on PATH.
dot_install_mise() {
  case "$(dot_mise_install_method)" in
    brew) brew install mise ;;
    release) _dot_install_mise_release ;;
    *) return 1 ;;
  esac || return 1
  case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH" ;; esac
  command -v mise >/dev/null 2>&1
}

# dot_ensure_mise <why>: mise present, or offered and installed with consent.
# Returns 1 (having said why) when it is missing and was not installed.
dot_ensure_mise() {
  local why="$1" method
  command -v mise >/dev/null 2>&1 && return 0
  method="$(dot_mise_install_method)"
  if [[ -z "$method" ]]; then
    ui_warn "mise" "not installed, and no way to install it here — see https://mise.jdx.dev"
    return 1
  fi
  ui_warn "mise" "not installed — $why"
  if ! dot_consent "Install mise now (via $method)?"; then
    ui_info "mise" "skipped — rerun with --yes, or install it: https://mise.jdx.dev"
    return 1
  fi
  ui_info "mise" "installing via ${method}…"
  if dot_install_mise; then
    ui_ok "mise" "installed ($(mise --version 2>/dev/null | head -1))"
  else
    ui_err "mise" "install failed"
    return 1
  fi
}
