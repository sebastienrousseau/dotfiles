#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Action tests for the `bm` directory-bookmark CLI.
#
# bm reads and writes $HOME/.config/shell/bookmarks, so every case runs
# against the sandbox HOME and asserts both the printed output and the
# resulting bookmarks file.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# The assertions below capture each child's stdout and stderr, which
# would also swallow the xtrace records the repo's coverage runner reads
# from stderr. Hand every child a copy of this test's real stderr on
# fd 21 and point BASH_XTRACEFD at it, so its line records still reach
# the runner while the captured text stays clean.
exec 21>&2

BM_FILE="$REPO_ROOT/defaults/dot_local/bin/executable_bm"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

TMP="$DOTFILES_COV_TMPDIR"
BM_HOME="$TMP/bm-home"
BOOKMARKS="$BM_HOME/.config/shell/bookmarks"
mkdir -p "$BM_HOME" "$TMP/bm-work/alpha" "$TMP/bm-work/beta"

BM_OUT=""
BM_RC=0
# _run_bm <cwd> [args...]
_run_bm() {
  local cwd="$1"
  shift
  BM_RC=0
  BM_OUT="$(
    cd "$cwd" &&
      env BASH_XTRACEFD=21 HOME="$BM_HOME" "$BASH" "$BM_FILE" "$@" </dev/null 2>&1
  )" || BM_RC=$?
}

_bm_expect() {
  local label="$1" want_rc="$2"
  shift 2
  local needle problems=""
  [[ "$BM_RC" == "$want_rc" ]] || problems="${problems}\n      rc: want $want_rc, got $BM_RC"
  for needle in "$@"; do
    [[ "$BM_OUT" == *"$needle"* ]] || problems="${problems}\n      missing: $needle"
  done
  test_start "$label"
  if [[ -z "$problems" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST$problems"
    printf '%s\n' "$BM_OUT" | sed 's/^/      /'
  fi
}

# =======================================================================
# 1. Usage: -h exits 0, no argument at all exits 1.
# =======================================================================
_run_bm "$TMP" -h
_bm_expect "help_flag_exits_0" 0 "Usage: bm <add|goto|list|remove|update> [name]"

_run_bm "$TMP" --help
_bm_expect "long_help_flag_exits_0" 0 "Usage: bm <add|goto|list|remove|update>"

_run_bm "$TMP"
_bm_expect "no_action_exits_1" 1 "Usage: bm <add|goto|list|remove|update>"

test_start "bookmarks_file_is_created_on_first_run"
assert_file_exists "$BOOKMARKS" "bm must create the bookmarks file if absent"

# =======================================================================
# 2. add — records the current working directory.
# =======================================================================
_run_bm "$TMP/bm-work/alpha" add alpha
_bm_expect "add_records_current_directory" 0 "Bookmark 'alpha' added for" "bm-work/alpha"

test_start "add_wrote_the_bookmark_line"
assert_file_contains "$BOOKMARKS" "alpha " "the bookmarks file must gain an alpha entry"

_run_bm "$TMP" add
_bm_expect "add_without_name_exits_1" 1 "Usage: bm add <name>"

# =======================================================================
# 3. goto — resolves a bookmark, rejects unknown and stale ones.
# =======================================================================
_run_bm "$TMP" goto alpha
_bm_expect "goto_prints_bookmarked_path" 0 "bm-work/alpha"

_run_bm "$TMP" goto
_bm_expect "goto_without_name_exits_1" 1 "Usage: bm goto <name>"

_run_bm "$TMP" goto nosuchmark
_bm_expect "goto_unknown_bookmark_exits_1" 1 "Bookmark 'nosuchmark' not found or invalid directory"

printf 'stale %s\n' "$TMP/bm-work/deleted" >>"$BOOKMARKS"
_run_bm "$TMP" goto stale
_bm_expect "goto_stale_directory_exits_1" 1 "Bookmark 'stale' not found or invalid directory"

# =======================================================================
# 4. list — prints the file when stdout is not a terminal.
# =======================================================================
_run_bm "$TMP" list
_bm_expect "list_prints_bookmarks" 0 "alpha " "stale "

# =======================================================================
# 5. update — replaces the recorded path for an existing name.
# =======================================================================
_run_bm "$TMP/bm-work/beta" update alpha
_bm_expect "update_rewrites_the_path" 0 "Bookmark 'alpha' updated to" "bm-work/beta"

test_start "update_replaced_the_old_entry"
_alpha_lines="$(grep -c '^alpha ' "$BOOKMARKS" || true)"
if [[ "$_alpha_lines" == "1" ]] && grep -q "^alpha .*bm-work/beta$" "$BOOKMARKS"; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: expected exactly one alpha entry pointing at beta"
  sed 's/^/      /' "$BOOKMARKS"
fi

_run_bm "$TMP" update
_bm_expect "update_without_name_exits_1" 1 "Usage: bm update <name>"

# =======================================================================
# 6. remove — deletes the entry.
# =======================================================================
_run_bm "$TMP" remove alpha
_bm_expect "remove_deletes_the_entry" 0 "Bookmark 'alpha' removed"

test_start "remove_dropped_the_line"
if ! grep -q '^alpha ' "$BOOKMARKS"; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: alpha is still in the bookmarks file"
fi

_run_bm "$TMP" remove
_bm_expect "remove_without_name_exits_1" 1 "Usage: bm remove <name>"

# =======================================================================
# 7. Unknown action.
# =======================================================================
_run_bm "$TMP" teleport
_bm_expect "unknown_action_exits_1" 1 "Unknown action: teleport"

# =======================================================================
# 8. _sed_i picks the GNU branch when `sed --version` succeeds.
# =======================================================================
GNU_SED_BIN="$TMP/bm-gnused"
mkdir -p "$GNU_SED_BIN"
for tool in grep cut pwd mkdir touch dirname cat echo env; do
  p="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$GNU_SED_BIN/$tool"
done
ln -sf "$BASH" "$GNU_SED_BIN/bash"
cat >"$GNU_SED_BIN/sed" <<EOF
#!/usr/bin/env bash
# A GNU-style sed: it answers --version, and its -i takes no suffix
# argument. Delegates the edit to the host sed, adding the empty suffix
# the BSD form requires so the fixture works on either platform.
if [[ "\${1:-}" == "--version" ]]; then
  echo "sed (GNU sed) 4.9"
  exit 0
fi
args=()
for a in "\$@"; do
  if [[ "\$a" == "-i" ]] && $(command -v sed) --version >/dev/null 2>&1; then
    args+=("-i")
  elif [[ "\$a" == "-i" ]]; then
    args+=("-i" "")
  else
    args+=("\$a")
  fi
done
exec $(command -v sed) "\${args[@]}"
EOF
chmod +x "$GNU_SED_BIN/sed"

printf 'gnu %s\n' "$TMP/bm-work/alpha" >>"$BOOKMARKS"
BM_RC=0
BM_OUT="$(
  cd "$TMP" &&
    env BASH_XTRACEFD=21 PATH="$GNU_SED_BIN" HOME="$BM_HOME" "$BASH" "$BM_FILE" remove gnu </dev/null 2>&1
)" || BM_RC=$?
_bm_expect "gnu_sed_branch_removes_entry" 0 "Bookmark 'gnu' removed"

test_start "gnu_sed_branch_dropped_the_line"
if ! grep -q '^gnu ' "$BOOKMARKS"; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: the GNU sed branch did not remove the entry"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
