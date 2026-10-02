#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck shell=bash
# Sourced by tools.sh; inherits set -euo pipefail
# `dot packages`: one line per installed package manager, each query bounded
# so a manager that never answers cannot hang the command.

# shellcheck source=../../../../lib/dot/probe.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../../lib/dot/probe.sh"

## _pkg_probe <cmd…> — a package-manager query under dot_probe, limited to
## DOTFILES_PACKAGES_TIMEOUT seconds (default 10). Exits 124 on expiry.
_pkg_probe() {
  dot_probe "${DOTFILES_PACKAGES_TIMEOUT:-10}" "$@"
}

## _pkg_count <pattern> <cmd…> — lines of the command's output matching the
## grep pattern; "timed out" past the limit; "N/A" when it failed silently.
## Output from a failing command still counts: `npm list -g` exits non-zero
## on any extraneous package, and `pipx list` on any broken interpreter.
_pkg_count() {
  local pattern="$1" out rc=0
  shift
  out="$(_pkg_probe "$@")" || rc=$?
  if [[ "$rc" -eq 124 ]]; then
    echo "timed out"
  elif [[ "$rc" -eq 0 || -n "$out" ]]; then
    # Re-add the newline $( ) stripped so the last line counts.
    printf '%s\n' "$out" | grep -c -- "$pattern" || true
  else
    echo "N/A"
  fi
}

## _pkg_word <n> <cmd…> — field n of the first output line (0 = the whole
## line), "timed out" past the limit, or "installed" when it printed nothing.
_pkg_word() {
  local n="$1" out rc=0 line
  shift
  out="$(_pkg_probe "$@")" || rc=$?
  if [[ "$rc" -eq 124 ]]; then
    echo "timed out"
    return
  fi
  line="${out%%$'\n'*}"
  if [[ -z "$line" ]]; then
    echo "installed"
  elif [[ "$n" -eq 0 ]]; then
    echo "$line"
  else
    echo "$line" | cut -d' ' -f"$n"
  fi
}

show_system_package_managers() {
  if has_command brew; then
    echo "  Homebrew: $(_pkg_word 0 brew --version)"
    echo "    Formulae: $(_pkg_count . brew list --formula)"
    echo "    Casks: $(_pkg_count . brew list --cask)"
  fi
  if has_command apt; then
    echo "  APT: $(_pkg_word 0 apt --version)"
    echo "    Packages: $(_pkg_count '^ii' dpkg -l)"
  fi
  if has_command dnf; then
    echo "  DNF: $(_pkg_word 0 dnf --version)"
  fi
  if has_command pacman; then
    echo "  Pacman: $(_pkg_word 0 pacman --version)"
    echo "    Packages: $(_pkg_count . pacman -Q)"
  fi
  if has_command nix; then
    echo "  Nix: $(_pkg_word 0 nix --version)"
  fi
}

_pkg_show_npm() {
  echo "  npm: $(_pkg_word 0 npm --version)"
  echo "    Global packages: $(_pkg_count '├──\|└──' npm list -g --depth=0)"
}

_pkg_show_cargo() {
  echo "  Cargo: $(_pkg_word 2 cargo --version)"
  echo "    Installed: $(_pkg_count ':$' cargo install --list)"
}

_pkg_show_pipx() {
  echo "  pipx: $(_pkg_word 0 pipx --version)"
  echo "    Installed: $(_pkg_count . pipx list --short)"
}

show_language_package_managers() {
  has_command npm && _pkg_show_npm
  has_command pnpm && echo "  pnpm: $(_pkg_word 0 pnpm --version)"
  has_command bun && echo "  Bun: $(_pkg_word 0 bun --version)"
  has_command cargo && _pkg_show_cargo
  has_command pip3 && echo "  pip: $(_pkg_word 2 pip3 --version)"
  has_command pipx && _pkg_show_pipx
  has_command gem && echo "  RubyGems: $(_pkg_word 0 gem --version)"
  has_command go && echo "  Go: $(_pkg_word 3 go version)"
  return 0
}
