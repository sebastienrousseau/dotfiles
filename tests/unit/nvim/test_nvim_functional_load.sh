#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Functional Neovim load test. Goes beyond syntax/luacheck: it boots a real
# headless Neovim and `require`s every config module and plugin spec,
# asserting each executes without error and that plugin specs return valid
# lazy.nvim tables. Catches runtime faults (nil calls, bad vim API usage,
# malformed specs) that static linting cannot. Hermetic — requiring a plugin
# spec returns its table without installing or loading the plugin.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

CFG="$REPO_ROOT/defaults/dot_config/nvim/lua"

# Skip gracefully where Neovim is unavailable or too old (the config itself
# requires >= 0.11.2). Keeps the suite green on minimal runners while still
# running for real wherever nvim is installed.
_nvim_too_old() {
  local v
  v="$(nvim --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  [[ -z "$v" ]] && return 0
  local maj min
  maj="${v%%.*}"
  min="$(printf '%s' "$v" | cut -d. -f2)"
  ((maj > 0)) && return 1
  ((min >= 11)) && return 1
  return 0
}

if ! command -v nvim >/dev/null 2>&1 || _nvim_too_old; then
  test_start "nvim_functional_load_skipped"
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${YELLOW:-}⚠${NC:-} $CURRENT_TEST: nvim missing or < 0.11.2 — functional load skipped"
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
  exit 0
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
harness="$tmp/harness.lua"
out="$tmp/results.txt"

cat >"$harness" <<'LUA'
local cfg = vim.env.NVIM_TEST_CFG
package.path = cfg .. "/?.lua;" .. cfg .. "/?/init.lua;" .. package.path
local lines = {}
local function check(mod, want_table)
  local ok, v = pcall(require, mod)
  if not ok then
    lines[#lines + 1] = "FAIL " .. mod .. " :: " .. tostring(v):gsub("\n", " ")
  elseif want_table and type(v) ~= "table" then
    lines[#lines + 1] = "FAIL " .. mod .. " :: expected table spec, got " .. type(v)
  else
    lines[#lines + 1] = "PASS " .. mod
  end
end
for _, m in ipairs({ "config.options", "config.keymaps", "config.autocmds" }) do
  check(m, false)
end
local files = vim.fn.glob(cfg .. "/plugins/*.lua", true, true)
table.sort(files)
for _, f in ipairs(files) do
  local n = f:match("plugins/([%w_]+)%.lua$")
  if n then check("plugins." .. n, true) end
end
local fh = assert(io.open(vim.env.NVIM_TEST_OUT, "w"))
fh:write(table.concat(lines, "\n") .. "\n")
fh:close()
vim.cmd("qa!")
LUA

NVIM_TEST_CFG="$CFG" NVIM_TEST_OUT="$out" \
  nvim --headless --noplugin -u NONE -c "luafile $harness" -c "qa!" >/dev/null 2>&1 || true

test_start "nvim_functional_harness_ran"
if [[ -s "$out" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: headless nvim produced no results"
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
  exit 1
fi

# One assertion per module: it must functionally load (PASS).
while IFS= read -r line; do
  [[ -n "$line" ]] || continue
  status="${line%% *}"
  rest="${line#* }"
  mod="${rest%% ::*}"
  test_start "nvim_functional_${mod//./_}"
  if [[ "$status" == "PASS" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: ${rest#* :: }"
  fi
done <"$out"

# Every plugin spec file must have been exercised.
test_start "nvim_functional_all_plugin_specs_loaded"
expected="$(find "$CFG/plugins" -maxdepth 1 -name '*.lua' | wc -l | tr -d ' ')"
checked="$(grep -c 'plugins\.' "$out" || true)"
assert_equals "$expected" "$checked" "all $expected plugin specs functionally loaded"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
