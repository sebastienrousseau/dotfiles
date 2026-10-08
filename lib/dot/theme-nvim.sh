#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Sourced by bin/dot-theme-sync; inherits set -euo pipefail
#
# lib/dot/theme-nvim.sh: the Neovim target of dot-theme-sync. Finds the
# running Neovim servers that belong to this user and builds the Lua that
# switches their colourscheme. A server socket someone else planted is never
# addressed, and a theme value is never spliced into Lua unless it is a
# plain name.

# _theme_nvim_owns <path>: true when the current user owns <path>. A seam
# for the tests, which cannot chown a directory away from themselves.
_theme_nvim_owns() {
  [[ -O "$1" ]]
}

# _theme_own_nvim_sockets <runtime dir>: sockets of this user's Neovim 0.10+
# servers, one per line. The first glob is stdpath("run") with
# XDG_RUNTIME_DIR set (Linux); the second is the fallback without it, which
# is where macOS puts them. Socket and parent directory must both be ours.
# Neovim 0.9 sockets (/tmp/nvimXXXXXX/0) are not searched: any user can
# create one.
_theme_own_nvim_sockets() {
  local s tmp="${TMPDIR:-/tmp}"
  for s in "$1"/nvim.*.0 "${tmp%/}"/nvim."${USER:-$(id -un)}"/*/nvim.*.0; do
    if [[ -S "$s" ]] && _theme_nvim_owns "$s" && _theme_nvim_owns "${s%/*}"; then
      printf '%s\n' "$s"
    fi
  done | awk '!seen[$0]++'
}

# _theme_nvim_safe <colorscheme> <style>: true when both are plain names
# that can sit inside a single-quoted Lua string. The style may be empty.
_theme_nvim_safe() {
  [[ "$1" =~ ^[A-Za-z0-9_.-]+$ ]] || return 1
  [[ -z "$2" || "$2" =~ ^[A-Za-z0-9_-]+$ ]]
}

# _theme_nvim_lua_cmd <colorscheme> <style>: the Lua that switches a running
# Neovim to <colorscheme>. Mirrors dot_config/nvim/lua/plugins/ui.lua. Call
# _theme_nvim_safe first: the arguments are interpolated as they are.
_theme_nvim_lua_cmd() {
  local scheme="$1" style="$2" bg="dark" setup=""
  [[ "$style" != "light" ]] || bg="light"
  case "$scheme" in
    catppuccin) setup="require('catppuccin').setup({flavour='${style:-mocha}'})" ;;
    tokyonight-*) setup="require('tokyonight').setup({style='${style:-night}'})" ;;
    kanagawa) setup="require('kanagawa').setup({theme='${style:-wave}'})" ;;
    gruvbox) setup="vim.o.background='${bg}' require('gruvbox').setup({contrast='hard'})" ;;
    everforest) setup="vim.o.background='${bg}'" ;;
    solarized) setup="vim.o.background='${bg}' require('solarized').setup({})" ;;
    onedark) setup="require('onedark').setup({style='${bg}'})" ;;
    nord)
      printf '%s\n' "require('nord').set()"
      return 0
      ;;
  esac
  printf '%s\n' "${setup:+$setup }vim.cmd.colorscheme('${scheme}')"
}
