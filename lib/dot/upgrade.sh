#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# The toolchain side of `dot upgrade`: prerequisites and consent up front,
# then mise, system-package and Nix phases, used by cmd_upgrade in
# scripts/dot/commands/meta.sh.
# Sourced by utils.sh; inherits set -euo pipefail
#
# cmd_upgrade renders its phases with _upgrade_step, which closes stdin and
# hands the terminal to the step renderer, so nothing here may prompt once
# the phases start. dot_upgrade_prepare runs first and asks every question;
# the phase functions only act on its answers.
#
# Bash 3.2 compatible (macOS /bin/bash): no associative arrays, no namerefs.

[[ -n "${_DOT_UPGRADE_LOADED:-}" ]] && return 0
_DOT_UPGRADE_LOADED=1

# The system package manager `dot upgrade` would drive, if any.
dot_upgrade_system_pm() {
  local pm
  for pm in brew apt-get dnf pacman; do
    if command -v "$pm" >/dev/null 2>&1; then
      printf '%s' "$pm"
      return 0
    fi
  done
  return 1
}

# _dot_upgrade_sudo_ready: sudo credentials cached for the unattended phase
# (asked once, here, while there is still a terminal to ask on).
_dot_upgrade_sudo_ready() {
  sudo -n true 2>/dev/null && return 0
  dot_can_ask || return 1
  ui_info "sudo" "system package upgrades need your password once"
  sudo -v
}

# _dot_upgrade_consent_system: ask whether to include system packages and
# record the answer in DOT_UPGRADE_SYSTEM (the package manager, or empty).
_dot_upgrade_consent_system() {
  local pm
  DOT_UPGRADE_SYSTEM=""
  pm="$(dot_upgrade_system_pm)" || return 0
  dot_consent "Also upgrade system packages ($pm)?" || return 0
  if [[ "$pm" == "brew" ]]; then
    _dot_upgrade_brew_sudo
  elif ! _dot_upgrade_sudo_ready; then
    ui_warn "System packages" "skipped — sudo is needed and could not be confirmed"
    return 0
  fi
  DOT_UPGRADE_SYSTEM="$pm"
}

# _dot_upgrade_brew_sudo: formulae never need sudo, but a cask whose upgrade
# removes a .pkg install runs sudo, and with nobody to type the password
# `brew upgrade` fails. With outdated casks, cache sudo now while there is
# a terminal, or name the casks that may fail when there is none.
_dot_upgrade_brew_sudo() {
  local casks
  casks="$(brew outdated --cask --quiet 2>/dev/null | tr '\n' ' ')"
  casks="${casks% }"
  [[ -n "$casks" ]] || return 0
  _dot_upgrade_sudo_ready && return 0
  ui_warn "Casks" "$casks may need sudo — run dot upgrade in a terminal to upgrade them"
}

# _dot_upgrade_brew_left: after a failed `brew upgrade`, name the casks still
# outdated (a cask that needed sudo is the usual cause) and how to finish.
_dot_upgrade_brew_left() {
  local casks
  casks="$(brew outdated --cask --quiet 2>/dev/null | tr '\n' ' ')"
  casks="${casks% }"
  [[ -n "$casks" ]] || return 1
  printf 'Still outdated: %s. A cask upgrade can need sudo; run: brew upgrade --cask %s\n' "$casks" "$casks" >&2
  return 1
}

# dot_upgrade_prepare <args...>: every question `dot upgrade` will ask,
# before any phase runs. -y/--yes answers yes to all of them.
dot_upgrade_prepare() {
  DOT_UPGRADE_SYSTEM=""
  dot_apply_yes_flag "$@"
  dot_ensure_mise "dot upgrade keeps your CLI tools and runtimes current with it" || true
  _dot_upgrade_consent_system
}

# _dot_upgrade_mise: missing tools installed, then everything upgraded, from
# $HOME so the global config applies rather than a project's pins. mise
# itself self-updates only when dot installed it from the release (brew and
# distro packages update mise with the system).
_dot_upgrade_mise() (
  cd "$HOME" || exit 1
  export MISE_YES=1
  if [[ "$(command -v mise)" == "$HOME/.local/bin/mise" ]]; then
    mise self-update --yes
  fi
  mise install
  mise upgrade
)

# _dot_upgrade_system <pm>: the consented system-package upgrade.
_dot_upgrade_system() {
  case "$1" in
    brew) brew update && { brew upgrade || _dot_upgrade_brew_left; } ;;
    apt-get) sudo -n apt-get update && sudo -n env DEBIAN_FRONTEND=noninteractive apt-get -y upgrade ;;
    dnf) sudo -n dnf -y upgrade ;;
    pacman) sudo -n pacman -Syu --noconfirm ;;
    *) return 1 ;;
  esac
}

# dot_upgrade_nix_steps <src_dir>: the Nix phases, when a flake is present.
dot_upgrade_nix_steps() {
  [[ -f "$1/nix/flake.nix" ]] && has_command nix || return 0
  _upgrade_step nix-flake "Nix flake" "updating…" -- sh -c 'cd "$1" && nix flake update' _ "$1"
  _upgrade_step nix-gc "Nix GC" "collecting…" -- nix-collect-garbage -d
}

# dot_upgrade_toolchain_steps: mise and system-package phases, per the
# answers dot_upgrade_prepare recorded. Called inside cmd_upgrade, whose
# _upgrade_step renders each one.
dot_upgrade_toolchain_steps() {
  if has_command mise; then
    _upgrade_step mise "Mise tools" "installing + upgrading…" -- _dot_upgrade_mise
    # AI CLIs stay at their [ai_tools] pins; list the bumps to review.
    ai_pin_bumps
  else
    ui_step mise "Mise tools" skip "mise not installed — dot upgrade --yes installs it"
  fi
  if [[ -n "${DOT_UPGRADE_SYSTEM:-}" ]]; then
    _upgrade_step system "System packages" "$DOT_UPGRADE_SYSTEM upgrade…" -- _dot_upgrade_system "$DOT_UPGRADE_SYSTEM"
  elif dot_upgrade_system_pm >/dev/null; then
    ui_step system "System packages" skip "not requested — answer yes, or dot upgrade --yes"
  fi
}
