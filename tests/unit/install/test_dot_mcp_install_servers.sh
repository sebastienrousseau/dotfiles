#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural coverage for defaults/dot_local/share/dot-mcp/executable_install-servers.sh,
# the apply-time installer of the third-party MCP servers: npm ci
# --ignore-scripts from the committed package-lock.json, and one venv per
# Python server from a hash-pinned requirements file with --require-hashes.
# npm and uv are stubs that log their argv; nothing reaches a registry.
# The committed manifests themselves are checked for a hash on every pin.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

refute_contains() { # <needle> <actual> <msg>
  if [[ "$2" != *"$1"* ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $3"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $3 (found '$1')"
  fi
}

SRC_DIR="$REPO_ROOT/defaults/dot_local/share/dot-mcp"
INSTALLER="$SRC_DIR/executable_install-servers.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export HOME="$WORK/home"
mkdir -p "$HOME"

STUBS="$WORK/stubs"
LOG="$WORK/calls.log"
mkdir -p "$STUBS"

# npm stub: log cwd and argv; DOT_TEST_NPM_RC sets the status.
cat >"$STUBS/npm" <<'SH'
#!/usr/bin/env bash
printf 'npm %s :: %s\n' "$PWD" "$*" >>"$DOT_TEST_LOG"
exit "${DOT_TEST_NPM_RC:-0}"
SH
# uv stub: `uv venv DIR` makes DIR/bin/python; `uv pip install` logs and
# returns DOT_TEST_UV_RC.
cat >"$STUBS/uv" <<'SH'
#!/usr/bin/env bash
printf 'uv %s\n' "$*" >>"$DOT_TEST_LOG"
if [[ "$1" == "venv" ]]; then
  for a in "$@"; do last="$a"; done
  mkdir -p "$last/bin" && : >"$last/bin/python"
  exit 0
fi
exit "${DOT_TEST_UV_RC:-0}"
SH
chmod +x "$STUBS/npm" "$STUBS/uv"

# A deployed-like copy of the manifests, as chezmoi lays them out.
ROOT="$WORK/dot-mcp"
mkdir -p "$ROOT/node" "$ROOT/python"
cp "$SRC_DIR/node/package.json" "$SRC_DIR/node/package-lock.json" "$ROOT/node/"
cp -R "$SRC_DIR/python/." "$ROOT/python/"

# Minimal PATH: the stubs plus the dirs holding coreutils and bash.
BASE_PATH="$STUBS:/usr/bin:/bin"

run_installer() { # [env…]
  : >"$LOG"
  env PATH="$BASE_PATH" DOT_MCP_HOME="$ROOT" DOT_TEST_LOG="$LOG" "$@" \
    bash "$INSTALLER" >"$WORK/out" 2>&1
  RC=$?
}

test_start "installer_exists_and_parses"
assert_file_exists "$INSTALLER" "installer is committed"
assert_true "bash -n '$INSTALLER'" "valid bash"

test_start "npm_server_installs_with_npm_ci_and_no_scripts"
run_installer
assert_equals 0 "$RC" "rc: $(cat "$WORK/out")"
assert_contains "npm $ROOT/node :: ci --ignore-scripts" "$(cat "$LOG")" "npm ci --ignore-scripts in the node dir"
refute_contains "npm $ROOT/node :: install" "$(cat "$LOG")" "never npm install (which rewrites the lock)"

test_start "python_servers_install_with_require_hashes"
for s in git sqlite; do
  assert_contains "uv venv" "$(grep "python/$s/venv" "$LOG")" "$s gets its own venv"
  assert_contains "pip install --python $ROOT/python/$s/venv/bin/python --require-hashes -r $ROOT/python/$s/requirements.txt" \
    "$(cat "$LOG")" "$s installs from its hash-pinned requirements"
done

test_start "a_rejected_python_install_leaves_no_venv_and_fails"
run_installer DOT_TEST_UV_RC=1
assert_not_equals 0 "$RC" "rc"
assert_dir_not_exists "$ROOT/python/git/venv" "no partial git venv"
assert_dir_not_exists "$ROOT/python/sqlite/venv" "no partial sqlite venv"
assert_contains "install failed" "$(cat "$WORK/out")" "the failure is reported"

test_start "a_rejected_npm_install_fails"
run_installer DOT_TEST_NPM_RC=1
assert_not_equals 0 "$RC" "rc"
assert_contains "memory" "$(cat "$WORK/out")" "names the npm server set"

test_start "missing_tools_skip_cleanly"
rm -f "$STUBS/npm" "$STUBS/uv"
run_installer
assert_equals 0 "$RC" "rc"
assert_contains "npm not found" "$(cat "$WORK/out")" "npm skip message"
assert_contains "uv not found" "$(cat "$WORK/out")" "uv skip message"
assert_equals "" "$(cat "$LOG")" "nothing ran"

test_start "a_dir_without_manifests_is_skipped"
mkdir -p "$ROOT/python/empty"
run_installer
assert_equals 0 "$RC" "rc"
refute_contains "empty" "$(cat "$LOG")" "no install for a dir without requirements.txt"

# ── the committed manifests ─────────────────────────────────────────────
test_start "every_python_pin_carries_a_hash"
for req in "$SRC_DIR"/python/*/requirements.txt; do
  # A requirement starts at column 0; it must be name==version followed by
  # at least one --hash line before the next requirement.
  bad="$(awk '
    /^[A-Za-z0-9]/ { if (name != "" && !hashed) print name; name = $1; hashed = 0
                     if ($1 !~ /==/) print "unpinned:" $1; next }
    /--hash=sha256:[0-9a-f]{64}/ { hashed = 1 }
    END { if (name != "" && !hashed) print name }' "$req")"
  assert_equals "" "$bad" "$(basename "$(dirname "$req")"): every pin is exact and hashed"
done

test_start "the_npm_lock_has_integrity_and_no_install_scripts"
lock="$SRC_DIR/node/package-lock.json"
assert_equals "0" "$(jq '[.packages | to_entries[] | select(.key != "" and (.value.integrity // "" | startswith("sha512-") | not))] | length' "$lock")" \
  "every package has a sha512 integrity"
assert_equals "0" "$(jq '[.packages[] | select(.hasInstallScript)] | length' "$lock")" "no package needs install scripts"
assert_equals "0" "$(jq '[.packages | to_entries[] | select(.key != "" and (.value.resolved // "" | startswith("https://registry.npmjs.org/") | not))] | length' "$lock")" \
  "every package resolves from the npm registry"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
