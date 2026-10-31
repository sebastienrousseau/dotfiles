#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# The toolchain side of `dot system update`: prerequisites and consent up front,
# then mise, system-package and Nix phases, used by cmd_upgrade in
# plugins/system/libexec/system.sh.
# Sourced by plugins/system/libexec/system.sh after utils.sh; inherits
# set -euo pipefail
#
# cmd_upgrade renders its phases with _upgrade_step, which closes stdin and
# hands the terminal to the step renderer, so nothing here may prompt once
# the phases start. dot_upgrade_prepare runs first and asks every question;
# the phase functions only act on its answers.
#
# Bash 3.2 compatible (macOS /bin/bash): no associative arrays, no namerefs.

[[ -n "${_DOT_UPGRADE_LOADED:-}" ]] && return 0
_DOT_UPGRADE_LOADED=1

# The system package manager `dot system update` would drive, if any.
dot_upgrade_system_pm() {
  local pm
  for pm in brew apt-get dnf pacman zypper; do
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
  ui_warn "Casks" "$casks may need sudo — run dot system update in a terminal to upgrade them"
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

# dot_upgrade_prepare <args...>: every question `dot system update` will ask,
# before any phase runs. -y/--yes answers yes to all of them.
dot_upgrade_prepare() {
  local arg
  DOT_UPGRADE_SYSTEM="" DOT_UPGRADE_GLOBALS=0
  dot_apply_yes_flag "$@"
  for arg in "$@"; do
    [[ "$arg" != --globals ]] || DOT_UPGRADE_GLOBALS=1
  done
  dot_ensure_mise "dot system update keeps your CLI tools and runtimes current with it" || true
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
    zypper) sudo -n zypper --non-interactive refresh && sudo -n zypper --non-interactive update ;;
    *) return 1 ;;
  esac
}

# _dot_upgrade_app_managers: the installed app stores the consented system
# phase also updates (App Store, Flatpak, Snap).
_dot_upgrade_app_managers() {
  local m out=""
  for m in mas flatpak snap; do
    ! has_command "$m" || out="$out $m"
  done
  printf '%s' "${out# }"
}

# _dot_upgrade_apps: each installed app store updated; a failure in one
# fails the phase but the others still run.
_dot_upgrade_apps() {
  local rc=0
  if has_command mas; then mas upgrade || rc=1; fi
  if has_command flatpak; then flatpak update -y --noninteractive || rc=1; fi
  if has_command snap; then sudo -n snap refresh || rc=1; fi
  return "$rc"
}

# _dot_upgrade_globals: npm, cargo and pipx globals, asked for with
# --globals (what the old `update` script did, minus per-package pip3
# upgrades, which PEP 668 refuses). A missing manager is skipped.
_dot_upgrade_globals() {
  local rc=0
  if has_command npm; then npm update -g --audit=false || rc=1; fi
  if has_command cargo && has_command cargo-install-update; then cargo install-update -a || rc=1; fi
  if has_command pipx; then pipx upgrade-all || rc=1; fi
  return "$rc"
}

# dot_upgrade_nix_steps <src_dir>: the Nix phases, when a flake is present.
dot_upgrade_nix_steps() {
  [[ -f "$1/nix/flake.nix" ]] && has_command nix || return 0
  _upgrade_step nix-flake "Nix flake" "updating…" -- sh -c 'cd "$1" && nix flake update' _ "$1"
  _upgrade_step nix-gc "Nix GC" "collecting…" -- nix-collect-garbage -d
}

# dot_upgrade_app_steps: the app-store phase, when any store is installed.
# DOTFILES_APP_STORES=0 shows it as a skip instead, for a machine whose store
# CLI is installed but does not work there.
dot_upgrade_app_steps() {
  local apps
  apps="$(_dot_upgrade_app_managers)"
  [[ -n "$apps" ]] || return 0
  if [[ "${DOTFILES_APP_STORES:-1}" == 0 ]]; then
    ui_step apps "App stores" skip "turned off by DOTFILES_APP_STORES=0"
    return 0
  fi
  _upgrade_step apps "App stores" "${apps}…" -- _dot_upgrade_apps
}

# _dot_upgrade_pins <list>: the AI CLI pin bumps into <list>, one per line;
# the printed line counts them for the step. The ai plugin reports them
# (`dot ai update --check`), so the system plugin loads none of its code.
_dot_upgrade_pins() {
  local n
  "${DOT_SYSTEM_DOT:-$(resolve_source_dir)/bin/dot}" ai update --check >"$1" || return 1
  n="$(grep -c . "$1" || true)"
  if [[ "$n" -eq 0 ]]; then
    echo "every pin is current"
  else
    echo "$n newer release(s), listed below"
  fi
}

# dot_upgrade_pin_report <list>: each bump _dot_upgrade_pins found. Called
# after ui_steps_end, once the renderer has given the terminal back.
dot_upgrade_pin_report() {
  local line
  [[ -s "$1" ]] || return 0
  while IFS= read -r line; do
    ui_info "Pin bump" "$line"
  done <"$1"
  ui_info "Pins" "move them by editing [ai_tools] in defaults/.chezmoidata.toml"
}

# dot_upgrade_toolchain_steps [pin-list]: mise and system-package phases,
# per the answers dot_upgrade_prepare recorded. Called inside cmd_upgrade,
# whose _upgrade_step renders each one. With a pin list, the AI CLI pin check
# is a step too, writing the bumps there for dot_upgrade_pin_report.
dot_upgrade_toolchain_steps() {
  if has_command mise; then
    _upgrade_step mise "Mise tools" "installing + upgrading…" -- _dot_upgrade_mise
    # AI CLIs stay at their [ai_tools] pins; collect the bumps to review.
    if [[ -n "${1:-}" ]]; then
      _upgrade_step pins "AI tool pins" "checking for newer releases…" -- _dot_upgrade_pins "$1"
    fi
  else
    ui_step mise "Mise tools" skip "mise not installed — dot update --yes installs it"
  fi
  if [[ -n "${DOT_UPGRADE_SYSTEM:-}" ]]; then
    _upgrade_step system "System packages" "$DOT_UPGRADE_SYSTEM upgrade…" -- _dot_upgrade_system "$DOT_UPGRADE_SYSTEM"
    dot_upgrade_app_steps
  elif dot_upgrade_system_pm >/dev/null; then
    ui_step system "System packages" skip "not requested — answer yes, or dot update --yes"
  fi
  if [[ "${DOT_UPGRADE_GLOBALS:-0}" == 1 ]]; then
    _upgrade_step globals "Language globals" "npm, cargo, pipx…" -- _dot_upgrade_globals
  fi
}
