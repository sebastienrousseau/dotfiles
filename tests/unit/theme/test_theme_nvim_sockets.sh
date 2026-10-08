#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# lib/dot/theme-nvim.sh: dot-theme-sync addresses only Neovim servers this
# user owns, and never splices a theme value into Lua unless it is a plain
# name. Real UNIX sockets are bound under a sandbox runtime dir and TMPDIR.
# shellcheck disable=SC1090,SC1091,SC2016,SC2034
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/theme-nvim.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
RUN="$WORK/run"
export TMPDIR="$WORK/tmp/"
export USER="fixture"
MAC="$WORK/tmp/nvim.fixture/abc123"
mkdir -p "$RUN" "$MAC" "$WORK/tmp/nvimXYZ" "$WORK/tmp/nvim.other/def"
bind() { python3 -c 'import socket, sys; socket.socket(socket.AF_UNIX).bind(sys.argv[1])' "$1"; }
bind "$RUN/nvim.100.0"
bind "$MAC/nvim.200.0"
bind "$WORK/tmp/nvimXYZ/0"
bind "$WORK/tmp/nvim.other/def/nvim.300.0"
: >"$RUN/nvim.400.0"

source "$REPO_ROOT/lib/dot/theme-nvim.sh"

test_start "nvim_sockets_lists_owned_linux_and_macos_servers"
assert_equals "$RUN/nvim.100.0"$'\n'"$WORK/tmp/nvim.fixture/abc123/nvim.200.0" \
  "$(_theme_own_nvim_sockets "$RUN")" \
  "the runtime-dir and the TMPDIR/nvim.USER servers, nothing else"

test_start "nvim_sockets_ignore_legacy_tmp_and_other_users"
out="$(_theme_own_nvim_sockets "$RUN")"
assert_false "[[ '$out' == *nvimXYZ* ]]" "a /tmp/nvimXXX/0 socket anyone can plant is not used"
assert_false "[[ '$out' == *nvim.other* ]]" "another user's TMPDIR/nvim.USER dir is not searched"
assert_false "[[ '$out' == *nvim.400.0* ]]" "a plain file is not a server"

test_start "nvim_sockets_without_USER_use_id"
id() { [[ "$1" == "-un" ]] && printf 'fixture\n'; }
assert_contains "$MAC/nvim.200.0" "$(USER="" _theme_own_nvim_sockets "$RUN")" "the user name comes from id -un"
unset -f id

test_start "nvim_sockets_are_listed_once"
assert_equals "$MAC/nvim.200.0" "$(_theme_own_nvim_sockets "$MAC")" \
  "a runtime dir that is also the TMPDIR location yields each socket once"

test_start "nvim_sockets_in_a_foreign_directory_are_skipped"
# Tests cannot chown, so the ownership seam reports the macOS dir as foreign.
_theme_nvim_owns() { [[ "$1" != "$MAC" && -O "$1" ]]; }
assert_equals "$RUN/nvim.100.0" "$(_theme_own_nvim_sockets "$RUN")" "a socket we own inside a dir we do not is skipped"

test_start "nvim_sockets_owned_by_someone_else_are_skipped"
_theme_nvim_owns() { [[ "$1" != "$RUN/nvim.100.0" && -O "$1" ]]; }
assert_equals "$MAC/nvim.200.0" "$(_theme_own_nvim_sockets "$RUN")" "a foreign socket in our dir is skipped"
source "$REPO_ROOT/lib/dot/theme-nvim.sh"

test_start "nvim_owns_checks_the_real_owner"
assert_true "_theme_nvim_owns '$RUN'" "our directory"
assert_false "_theme_nvim_owns /" "root's directory"

test_start "nvim_safe_accepts_plain_names"
assert_true "_theme_nvim_safe tokyonight-night night" "scheme and style"
assert_true "_theme_nvim_safe dotfiles ''" "empty style"
assert_true "_theme_nvim_safe base16_ocean.v2 dark_soft" "dot and underscore in the scheme, underscore in the style"

test_start "nvim_safe_refuses_lua_breakouts"
assert_false "_theme_nvim_safe \"x')vim.fn.system('id\" night" "a quote in the colorscheme"
assert_false "_theme_nvim_safe 'xvim' \"night')os.exit('\"" "a quote in the style"
assert_false "_theme_nvim_safe '' night" "an empty colorscheme"
assert_false "_theme_nvim_safe 'a b' night" "a space"
assert_false "_theme_nvim_safe \"a\$'\\n'b\" night" "a newline"
assert_false "_theme_nvim_safe 'xa;' night" "a trailing ; in the colorscheme"
assert_false "_theme_nvim_safe 'xa' 'night;'" "a trailing ; in the style"
assert_false "_theme_nvim_safe ';xa' night" "a leading ; in the colorscheme"
assert_false "_theme_nvim_safe 'xa' ';night'" "a leading ; in the style"
assert_false "_theme_nvim_safe 'xa' 'ni.ght'" "a dot in the style"

test_start "nvim_lua_cmd_per_colorscheme"
lua() { _theme_nvim_lua_cmd "$@"; }
assert_equals "require('catppuccin').setup({flavour='latte'}) vim.cmd.colorscheme('catppuccin')" "$(lua catppuccin latte)" "catppuccin"
assert_equals "require('catppuccin').setup({flavour='mocha'}) vim.cmd.colorscheme('catppuccin')" "$(lua catppuccin '')" "catppuccin default"
assert_equals "require('tokyonight').setup({style='day'}) vim.cmd.colorscheme('tokyonight-day')" "$(lua tokyonight-day day)" "tokyonight"
assert_equals "require('tokyonight').setup({style='night'}) vim.cmd.colorscheme('tokyonight-night')" "$(lua tokyonight-night '')" "tokyonight default"
assert_equals "require('kanagawa').setup({theme='wave'}) vim.cmd.colorscheme('kanagawa')" "$(lua kanagawa '')" "kanagawa default"
assert_equals "require('kanagawa').setup({theme='lotus'}) vim.cmd.colorscheme('kanagawa')" "$(lua kanagawa lotus)" "kanagawa"
assert_equals "vim.o.background='light' require('gruvbox').setup({contrast='hard'}) vim.cmd.colorscheme('gruvbox')" "$(lua gruvbox light)" "gruvbox light"
assert_equals "vim.o.background='dark' require('gruvbox').setup({contrast='hard'}) vim.cmd.colorscheme('gruvbox')" "$(lua gruvbox hard)" "gruvbox dark"
assert_equals "vim.o.background='light' vim.cmd.colorscheme('everforest')" "$(lua everforest light)" "everforest"
assert_equals "vim.o.background='dark' require('solarized').setup({}) vim.cmd.colorscheme('solarized')" "$(lua solarized '')" "solarized"
assert_equals "require('onedark').setup({style='light'}) vim.cmd.colorscheme('onedark')" "$(lua onedark light)" "onedark light"
assert_equals "require('onedark').setup({style='dark'}) vim.cmd.colorscheme('onedark')" "$(lua onedark warm)" "onedark dark"
assert_equals "require('nord').set()" "$(lua nord '')" "nord"
assert_true "_theme_nvim_lua_cmd nord '' >/dev/null" "nord succeeds"
assert_equals "vim.cmd.colorscheme('dotfiles')" "$(lua dotfiles night)" "any other scheme"

test_summary
