#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Regression test: pre-commit luacheck + stylua hooks must reject
# misformatted Lua, and CI + pre-commit must pin the same versions.
#
# Regression for: GH-865

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
# shellcheck source=../../framework/assertions.sh
source "$SCRIPT_DIR/../../framework/assertions.sh"

PRECOMMIT_CFG="$REPO_ROOT/config/pre-commit-config.yaml"
CI_REUSABLE="$REPO_ROOT/.github/workflows/reusable-lua-lint.yml"

# -----------------------------------------------------------------------------
# Structural: hooks present and pinned
# -----------------------------------------------------------------------------

test_start "precommit_has_luacheck"
assert_file_contains "$PRECOMMIT_CFG" "lunarmodules/luacheck" \
  "pre-commit config must include the luacheck hook"

test_start "precommit_has_stylua"
assert_file_contains "$PRECOMMIT_CFG" "JohnnyMorganz/StyLua" \
  "pre-commit config must include the stylua hook"

test_start "precommit_scopes_to_lua"
# Both hooks must restrict themselves to .lua files. Use fgrep to avoid
# nested-backslash quoting headaches between bash, awk, and grep regex.
count=$(grep -Fc 'files: \.lua$' "$PRECOMMIT_CFG" || true)
if (( count >= 2 )); then
  assert_exit_code 0 "true"
else
  assert_exit_code 0 "false  # expected ≥2 lua-scoped hooks; got $count"
fi

# -----------------------------------------------------------------------------
# Version-parity: same pinned versions in pre-commit and CI
# -----------------------------------------------------------------------------

test_start "luacheck_version_matches"
pc_lua=$(awk '/lunarmodules\/luacheck/,/rev:/' "$PRECOMMIT_CFG" | awk '/rev:/ {gsub(/[v"]/,"",$2); print $2; exit}')
ci_lua=$(awk '/luacheck_version:/,/type:/' "$CI_REUSABLE" | awk '/default:/ {gsub(/["v]/,"",$2); print $2; exit}')
if [[ -n "$pc_lua" && "$pc_lua" == "$ci_lua" ]]; then
  assert_exit_code 0 "true"
else
  assert_exit_code 0 "false  # luacheck versions differ: pre-commit=$pc_lua ci=$ci_lua"
fi

test_start "stylua_version_matches"
pc_sl=$(awk '/JohnnyMorganz\/StyLua/,/rev:/' "$PRECOMMIT_CFG" | awk '/rev:/ {gsub(/[v"]/,"",$2); print $2; exit}')
ci_sl=$(awk '/stylua_version:/,/type:/' "$CI_REUSABLE" | awk '/default:/ {gsub(/["v]/,"",$2); print $2; exit}')
if [[ -n "$pc_sl" && "$pc_sl" == "$ci_sl" ]]; then
  assert_exit_code 0 "true"
else
  assert_exit_code 0 "false  # stylua versions differ: pre-commit=$pc_sl ci=$ci_sl"
fi

# -----------------------------------------------------------------------------
# Behavioural: deliberately-misformatted Lua is rejected by stylua.
# (Skipped automatically if stylua isn't installed locally — CI installs it.)
# -----------------------------------------------------------------------------

if command -v stylua >/dev/null 2>&1; then
  tmpfile="$(mktemp -t stylua_regression.XXXXXX.lua)"
  trap 'rm -f "$tmpfile"' EXIT
  # Intentionally bad spacing + 8-space indent (stylua default is 2 spaces / tabs)
  cat > "$tmpfile" <<'EOF'
local       function    foo(   x,y    )
        return   x   +    y
end
EOF

  test_start "stylua_rejects_misformatted"
  if stylua --check "$tmpfile" >/dev/null 2>&1; then
    assert_exit_code 0 "false  # stylua accepted misformatted Lua"
  else
    assert_exit_code 0 "true"
  fi

  # Sanity: a well-formatted file passes
  good="$(mktemp -t stylua_good.XXXXXX.lua)"
  printf 'local function foo(x, y)\n\treturn x + y\nend\n' > "$good"
  test_start "stylua_accepts_clean"
  if stylua --check "$good" >/dev/null 2>&1; then
    assert_exit_code 0 "true"
  else
    assert_exit_code 0 "false  # stylua rejected well-formatted Lua"
  fi
  rm -f "$good"
fi

if command -v luacheck >/dev/null 2>&1; then
  tmpfile2="$(mktemp -t luacheck_regression.XXXXXX.lua)"
  # Use a clear runtime issue: shadowed local — luacheck warns by default
  cat > "$tmpfile2" <<'EOF'
local x = 1
local x = 2
return x
EOF

  test_start "luacheck_rejects_problem"
  if luacheck --no-color --codes "$tmpfile2" >/dev/null 2>&1; then
    assert_exit_code 0 "false  # luacheck accepted file with obvious issues"
  else
    assert_exit_code 0 "true"
  fi
  rm -f "$tmpfile2"
fi

# -----------------------------------------------------------------------------
# Existing tree: every committed Lua file must pass both linters.
# -----------------------------------------------------------------------------

if command -v stylua >/dev/null 2>&1; then
  test_start "existing_lua_passes_stylua"
  if stylua --check "$REPO_ROOT/defaults/dot_config/nvim" >/dev/null 2>&1; then
    assert_exit_code 0 "true"
  else
    assert_exit_code 0 "false  # committed Lua tree fails stylua"
  fi
fi

if command -v luacheck >/dev/null 2>&1; then
  test_start "existing_lua_passes_luacheck"
  if luacheck --no-color "$REPO_ROOT/defaults/dot_config/nvim" >/dev/null 2>&1; then
    assert_exit_code 0 "true"
  else
    assert_exit_code 0 "false  # committed Lua tree fails luacheck"
  fi
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
