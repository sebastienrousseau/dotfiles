#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Sourced by scripts/diagnostics/doctor.sh: the toolchain sections of
# `dot doctor` (Core Shells, Modern CLI Tools, Infrastructure). They use the
# doctor's _ok/_warn/_fail/_section and its path helpers.
#
# install.sh deploys configs; the toolchain (packages, fonts, tools) comes
# only with `install.sh --provision`, which records each provisioning script
# it ran successfully (install/lib/provision.sh). A toolchain command that is
# missing is a failure once that has happened on this machine, and before it
# a warning that says how to provision: a configs-only install is not broken.

# Re-source guard: cheap short-circuit when sourced from multiple modules.
[[ "${_DOT_LIB_DOCTOR_TOOLCHAIN_LOADED:-0}" == "1" ]] && return 0
_DOT_LIB_DOCTOR_TOOLCHAIN_LOADED=1

# _toolchain_provisioned: whether `install.sh --provision` has succeeded here,
# by the state run_provision keeps.
_toolchain_provisioned() {
  [[ -s "${XDG_STATE_HOME:-$HOME/.local/state}/dot/provision/hashes" ]]
}

# _missing <cmd>: report a toolchain command that is not installed.
_missing() {
  if _toolchain_provisioned; then
    _fail "$1" "missing"
  else
    _warn "$1" "not installed (toolchain not provisioned: install.sh --provision)"
  fi
}

# --- Core Shells ---
_doctor_core_shells() {
  _section "Core Shells"
  for cmd in zsh fish starship; do
    if check_cmd "$cmd"; then
      cmd_path="$(get_cmd_path "$cmd")"
      _ok "$cmd" "$(pretty_path "$cmd_path") ($(tool_source "$cmd_path"))"
    elif [[ "$cmd" == "fish" ]]; then
      _warn "$cmd" "optional"
    else
      _missing "$cmd"
    fi
  done

  if check_cmd "nu"; then
    cmd_path="$(get_cmd_path "nu")"
    _ok "nu" "$(pretty_path "$cmd_path") ($(tool_source "$cmd_path"))"
  elif check_cmd "nushell"; then
    cmd_path="$(get_cmd_path "nushell")"
    _ok "nu" "$(pretty_path "$cmd_path") ($(tool_source "$cmd_path"))"
  else
    _warn "nu" "optional"
  fi
}

# --- Modern CLI Tools ---
# chezmoi is the one entry install.sh itself installs, so it is a failure
# whether or not the toolchain was provisioned.
_doctor_modern_cli_tools() {
  _section "Modern CLI Tools"
  for cmd in rg bat chezmoi fzf zoxide atuin yazi zellij; do
    if check_cmd "$cmd"; then
      _ok "$cmd" "$(pretty_path "$(get_cmd_path "$cmd")")"
    elif [[ "$cmd" == "bat" ]] && check_cmd "batcat"; then
      _ok "$cmd" "$(pretty_path "$(get_cmd_path "batcat")") (batcat)"
    elif [[ "$cmd" == "chezmoi" ]]; then
      _fail "$cmd" "missing"
    else
      _missing "$cmd"
    fi
  done
}

# --- Infrastructure ---
_doctor_infrastructure() {
  _section "Infrastructure"
  for cmd in pueue wasmtime nix sops age hyperfine; do
    if check_cmd "$cmd"; then
      _ok "$cmd" "$(pretty_path "$(get_cmd_path "$cmd")")"
    elif [[ "$cmd" == "nix" ]]; then
      _ok "$cmd" "optional (not installed)"
    else
      _missing "$cmd"
    fi
  done

  if check_cmd pueue; then
    if "$(get_cmd_path pueue)" status >/dev/null 2>&1; then
      _ok "pueue daemon" "running"
    # 3>&-: in --json mode fd 3 is the caller's stdout; a daemon that
    # inherits it holds `$(doctor --json)` open for its whole lifetime.
    elif command -v pueued >/dev/null 2>&1 && pueued -d >/dev/null 2>&1 3>&- && "$(get_cmd_path pueue)" status >/dev/null 2>&1; then
      _ok "pueue daemon" "started"
    else
      _warn "pueue daemon" "not running (pueued -d)"
    fi
  fi
}
