#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# The generated Neovim palette colourscheme and lualine theme, loaded in a
# real headless Neovim: every highlight group that draws text must read at
# 7:1 (WCAG AAA) on the background it actually sits on.
# shellcheck disable=SC1090,SC1091,SC2034

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d -t dot-nvim-palette.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/rt/colors" "$WORK/rt/lua/lualine/themes"

cat >"$WORK/check.lua" <<'LUA'
local function lum(hex)
  local function ch(v)
    v = v / 255
    return v <= 0.04045 and v / 12.92 or ((v + 0.055) / 1.055) ^ 2.4
  end
  local r, g, b = tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
  return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)
end
local function cr(a, b)
  local x, y = lum(a), lum(b)
  if x < y then
    x, y = y, x
  end
  return (x + 0.05) / (y + 0.05)
end
vim.cmd.colorscheme("dotfiles")
local nbg = string.format("#%06x", vim.api.nvim_get_hl(0, { name = "Normal" }).bg)
local bad, n = {}, 0
for name, spec in pairs(vim.api.nvim_get_hl(0, {})) do
  if spec.fg and not spec.link and name ~= "EndOfBuffer" then
    local fg = string.format("#%06x", spec.fg)
    local bg = spec.bg and string.format("#%06x", spec.bg) or nbg
    n = n + 1
    if cr(fg, bg) < 7 then
      table.insert(bad, name)
    end
  end
end
for mode, sections in pairs(dofile(vim.env.LUALINE_THEME)) do
  for section, s in pairs(sections) do
    n = n + 1
    if cr(s.fg, s.bg) < 7 then
      table.insert(bad, "lualine." .. mode .. "." .. section)
    end
  end
end
io.stdout:write(string.format("%s %d %s\n", vim.g.colors_name, n, #bad == 0 and "none" or table.concat(bad, ",")))
LUA

render() {
  chezmoi execute-template --source "$REPO_ROOT/defaults" --override-data "{\"theme\":\"$1\"}" \
    <"$REPO_ROOT/defaults/$2" >"$3"
}

for theme in maui-dark maui-light berlin-dark berlin-light fallback-dark fallback-light; do
  test_start "nvim_palette_is_aaa ($theme)"
  if ! command -v nvim >/dev/null 2>&1 || ! command -v chezmoi >/dev/null 2>&1; then
    ((TESTS_PASSED++))
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (skipped: nvim or chezmoi unavailable; render goldens still cover the output)"
    continue
  fi
  render "$theme" dot_config/nvim/colors/dotfiles.lua.tmpl "$WORK/rt/colors/dotfiles.lua"
  render "$theme" dot_config/nvim/lua/lualine/themes/dotfiles.lua.tmpl "$WORK/rt/lua/lualine/themes/dotfiles.lua"
  out="$(LUALINE_THEME="$WORK/rt/lua/lualine/themes/dotfiles.lua" nvim --headless -u NONE \
    --cmd "set rtp^=$WORK/rt" -c "set termguicolors" -c "luafile $WORK/check.lua" -c 'qa!' 2>&1 | tr -d '\r')"
  assert_equals "dotfiles" "$(awk '{print $1}' <<<"$out")" "the palette colourscheme loads"
  assert_equals "none" "$(awk '{print $3}' <<<"$out")" "no text pair below 7:1 (checked $(awk '{print $2}' <<<"$out"))"
done

printf 'RESULTS:%s:%s:%s\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
