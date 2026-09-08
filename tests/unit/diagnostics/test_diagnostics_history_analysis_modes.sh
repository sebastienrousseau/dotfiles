#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Guard and analysis tests for scripts/diagnostics/history-analysis.sh.
#
# The script indexes a zsh history file into a SQLite database and
# prints the top commands and directories. Every case runs against a
# fixture history file inside the sandbox and a database path under the
# sandbox HOME, so the real ~/.zsh_history is never read.

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

HA_FILE="$REPO_ROOT/scripts/diagnostics/history-analysis.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

TMP="$DOTFILES_COV_TMPDIR"
HA_HOME="$TMP/ha-home"
mkdir -p "$HA_HOME"

HISTFIXTURE="$TMP/ha-history"
cat >"$HISTFIXTURE" <<'HIST'
: 1705276800:0;git status
: 1705276801:0;git status
: 1705276802:0;git commit -m wip
: 1705276803:0;cd /tmp/project
: 1705276804:0;cd /tmp/project
: 1705276805:0;cd /var/log
: 1705276806:0;ls -la
not a history line at all
: 1705276807:0;
HIST

HA_OUT=""
HA_RC=0
# _run_ha <bindir> [env...]
_run_ha() {
  local bindir="$1"
  shift
  HA_RC=0
  HA_OUT="$(
    env BASH_XTRACEFD=21 PATH="$bindir" HOME="$HA_HOME" DOTFILES_ACCESSIBILITY=1 "$@" \
      "$BASH" "$HA_FILE" </dev/null 2>&1
  )" || HA_RC=$?
}

_ha_expect() {
  local label="$1" want_rc="$2"
  shift 2
  local needle problems=""
  [[ "$HA_RC" == "$want_rc" ]] || problems="${problems}\n      rc: want $want_rc, got $HA_RC"
  for needle in "$@"; do
    [[ "$HA_OUT" == *"$needle"* ]] || problems="${problems}\n      missing: $needle"
  done
  test_start "$label"
  if [[ -z "$problems" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST$problems"
    printf '%s\n' "$HA_OUT" | sed 's/^/      /'
  fi
}

_ha_bin() {
  local dir="$TMP/ha-$1"
  shift
  mkdir -p "$dir"
  local tool p
  for tool in dirname basename mkdir cat env printf sed grep tr locale tput uname "$@"; do
    p="$(command -v "$tool" 2>/dev/null || true)"
    [[ -n "$p" ]] && ln -sf "$p" "$dir/$tool"
  done
  ln -sf "$BASH" "$dir/bash"
  printf '%s' "$dir"
}

FULL_BIN="$(_ha_bin full python3)"
NOPY_BIN="$(_ha_bin nopy)"
HSTATS_BIN="$(_ha_bin hstats)"
cat >"$HSTATS_BIN/hstats" <<'EOF'
#!/usr/bin/env bash
echo "hstats fallback report"
exit 0
EOF
chmod +x "$HSTATS_BIN/hstats"

# =======================================================================
# 1. Missing history file is a hard failure.
# =======================================================================
_run_ha "$FULL_BIN" HISTFILE="$TMP/ha-absent" \
  DOTFILES_HISTORY_DB="$HA_HOME/db/history.sqlite"
_ha_expect "missing_history_file_exits_1" 1 "History file" "not found:"

# =======================================================================
# 2. Without python3, fall back to hstats — or fail when it is absent.
# =======================================================================
_run_ha "$HSTATS_BIN" HISTFILE="$HISTFIXTURE" \
  DOTFILES_HISTORY_DB="$HA_HOME/db/history.sqlite"
_ha_expect "falls_back_to_hstats_without_python3" 0 \
  "python3" "not found; falling back to hstats" "hstats fallback report"

_run_ha "$NOPY_BIN" HISTFILE="$HISTFIXTURE" \
  DOTFILES_HISTORY_DB="$HA_HOME/db/history.sqlite"
_ha_expect "exits_1_without_python3_or_hstats" 1 "falling back to hstats"

# =======================================================================
# 3. Full analysis: the report ranks commands and cd targets.
# =======================================================================
DB_PATH="$HA_HOME/db/history.sqlite"
_run_ha "$FULL_BIN" HISTFILE="$HISTFIXTURE" DOTFILES_HISTORY_DB="$DB_PATH"
_ha_expect "analysis_reports_top_commands_and_directories" 0 \
  "History Analysis" "Top commands:" "3  cd" "3  git" "1  ls" \
  "Top directories (cd):" "2  /tmp/project" "1  /var/log"

test_start "analysis_creates_the_database"
assert_file_exists "$DB_PATH" "the history database must be created under the configured path"

test_start "analysis_is_idempotent"
_run_ha "$FULL_BIN" HISTFILE="$HISTFIXTURE" DOTFILES_HISTORY_DB="$DB_PATH"
if [[ "$HA_RC" == "0" && "$HA_OUT" == *"3  cd"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: a second run must not double-count rows"
  printf '%s\n' "$HA_OUT" | sed 's/^/      /'
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
