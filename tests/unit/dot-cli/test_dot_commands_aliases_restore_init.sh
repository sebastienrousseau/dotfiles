#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural tests for three dot command files:
#
#   scripts/dot/commands/aliases.sh   aliases list/search/why/stats/…
#   scripts/dot/commands/restore.sh   restore from backup or a git ref
#   scripts/dot/commands/init.sh      bootstrap a foreign dotfiles repo
#
# aliases.sh and init.sh only define functions (the dot driver sources them
# and calls cmd_aliases / cmd_init), so they are sourced the same way here.
# restore.sh is a script and is run as one. git, chezmoi and rg are
# PATH-shadowed recording stubs and every path lives in the sandbox, so no
# repository is checked out and no file outside the sandbox is restored.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

ALIASES="$REPO_ROOT/scripts/dot/commands/aliases.sh"
RESTORE="$REPO_ROOT/scripts/dot/commands/restore.sh"
INIT="$REPO_ROOT/scripts/dot/commands/init.sh"
UTILS="$REPO_ROOT/lib/dot/utils.sh"
REAL_BASH="${BASH:-$(command -v bash)}"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox
BIN="$DOTFILES_COV_TMPDIR/bin"
WORK="$DOTFILES_COV_TMPDIR/work"
mkdir -p "$WORK"

test_start "command_files_exist"
for f in "$ALIASES" "$RESTORE" "$INIT"; do
  assert_file_exists "$f" "$(basename "$f") must exist"
done

_pass() {
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
}
_fail() {
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $1"
}

CALLS="$WORK/calls"
: >"$CALLS"
cat >"$BIN/git" <<EOF
#!$REAL_BASH
printf 'git %s\n' "\$*" >>"$CALLS"
case "\$*" in
  *log*) printf 'abc1234 a commit\n' ;;
  *"diff --stat"*) printf ' file.txt | 2 +-\n' ;;
  *diff*) printf 'diff --git a/file b/file\n' ;;
esac
exit "\${FAKE_GIT_RC:-0}"
EOF
cat >"$BIN/chezmoi" <<EOF
#!$REAL_BASH
printf 'chezmoi %s\n' "\$*" >>"$CALLS"
case "\${1:-}" in
  source-path) printf '%s\n' "\${FAKE_SOURCE_PATH:-\$HOME/.local/share/chezmoi}" ;;
esac
exit "\${FAKE_CHEZMOI_RC:-0}"
EOF
# rg stands in for ripgrep: aliases.sh calls `rg -i <pattern>`, so drop the
# flag and hand the pattern to grep.
cat >"$BIN/rg" <<EOF
#!$REAL_BASH
args=()
for a in "\$@"; do
  [[ "\$a" == -* ]] && continue
  args+=("\$a")
done
exec /usr/bin/grep -i -- "\${args[0]:-}"
EOF
chmod +x "$BIN/git" "$BIN/chezmoi" "$BIN/rg"

OUT="$WORK/out.txt"
ERR="$WORK/err.txt"

# ---------------------------------------------------------------------------
# aliases.sh — sourced alongside utils.sh, which supplies ui_*, die and
# require_source_dir. A fixture source tree provides the alias manifest and
# the deprecations table.
# ---------------------------------------------------------------------------
ALIAS_SRC="$WORK/alias-src"
mkdir -p "$ALIAS_SRC/scripts/diagnostics" "$ALIAS_SRC/scripts/dot/data"
cat >"$ALIAS_SRC/scripts/diagnostics/aliases-manifest.sh" <<EOF
#!$REAL_BASH
printf '%s\t%s\t%s\t%s\n' gs 'git status' aliases.sh 12
printf '%s\t%s\t%s\t%s\n' ll 'eza -l' aliases.sh 20
printf '%s\t%s\t%s\t%s\n' old 'legacy thing' aliases.sh 30
EOF
chmod +x "$ALIAS_SRC/scripts/diagnostics/aliases-manifest.sh"
printf 'old\tnew\tv1.0.0\tuse new instead\n' \
  >"$ALIAS_SRC/scripts/dot/data/alias-deprecations.tsv"
cat >"$ALIAS_SRC/scripts/diagnostics/aliases-cheatsheet.sh" <<EOF
#!$REAL_BASH
printf '# Cheatsheet\n'
EOF
chmod +x "$ALIAS_SRC/scripts/diagnostics/aliases-cheatsheet.sh"

# aliases <snippet> — source utils.sh + aliases.sh with the fixture tree as
# the resolved source dir, then run the snippet. Stdout is captured; stderr
# is replayed so the coverage runner keeps its xtrace records.
aliases() {
  local snippet="$1" rc=0
  PATH="$BIN:/usr/bin:/bin" \
    "$REAL_BASH" -c "
      source '$UTILS'
      set +e
      require_source_dir() { printf '%s\n' '$ALIAS_SRC'; }
      source '$ALIASES'
      $snippet
    " </dev/null >"$OUT" 2>"$ERR" || rc=$?
  cat "$ERR" >&2
  printf '%s' "$rc"
}

test_start "aliases_list_renders_every_alias"
rc="$(aliases 'cmd_aliases list')"
assert_equals "0" "$rc" "list exits 0"
assert_file_contains "$OUT" "gs" "each alias name is listed"
assert_file_contains "$OUT" "git status" "each alias value is listed"
assert_file_contains "$OUT" "aliases.sh:12" "the definition site is listed"

test_start "aliases_defaults_to_list"
rc="$(aliases 'cmd_aliases')"
assert_equals "0" "$rc" "the default subcommand exits 0"
assert_file_contains "$OUT" "Aliases" "the listing header is printed"

test_start "aliases_search_filters_and_reports_misses"
rc="$(aliases 'cmd_aliases search git')"
assert_equals "0" "$rc" "a matching search exits 0"
assert_file_contains "$OUT" "gs" "the matching alias is shown"
rc="$(aliases 'cmd_aliases search zzzznomatch')"
assert_equals "1" "$rc" "a search with no matches returns 1"
assert_file_contains "$OUT" "No matches" "the miss is reported"
rc="$(aliases 'cmd_aliases search')"
assert_equals "1" "$rc" "search without a term fails"
assert_file_contains "$ERR" "Usage: dot aliases search" "the usage line is shown"

test_start "aliases_why_explains_an_alias_and_its_deprecation"
rc="$(aliases 'cmd_aliases why old')"
assert_equals "0" "$rc" "why exits 0 for a known alias"
assert_file_contains "$OUT" "legacy thing" "the alias value is shown"
assert_file_contains "$OUT" "Deprecated" "the deprecation is flagged"
assert_file_contains "$OUT" "new" "the replacement is named"
assert_file_contains "$OUT" "v1.0.0" "the removal version is named"

test_start "aliases_why_reports_an_unknown_alias"
rc="$(aliases 'cmd_aliases why definitely-not-an-alias')"
assert_equals "1" "$rc" "an unknown alias returns 1"
assert_file_contains "$OUT" "not found" "the miss is reported"
rc="$(aliases 'cmd_aliases why')"
assert_equals "1" "$rc" "why without a name fails"
assert_file_contains "$ERR" "Usage: dot aliases why" "the usage line is shown"

test_start "aliases_stats_counts_history_usage"
HIST="$WORK/zsh_history"
printf ': 1700000000:0;gs\n: 1700000001:0;gs\n: 1700000002:0;ll\nunrelated\n' >"$HIST"
rc="$(aliases "HISTFILE='$HIST' cmd_aliases stats")"
assert_equals "0" "$rc" "stats exits 0"
assert_file_contains "$OUT" "Alias Usage" "the report header is printed"
assert_file_contains "$OUT" "gs" "the most-used alias is counted"

test_start "aliases_stats_requires_a_history_file"
rc="$(aliases "HISTFILE='$WORK/absent-history' cmd_aliases stats")"
assert_equals "1" "$rc" "a missing history file fails"
assert_file_contains "$ERR" "History file not found" "the error names the file"

test_start "aliases_cheatsheet_writes_where_asked"
sheet="$WORK/cheatsheet/ALIASES.md"
rc="$(aliases "cmd_aliases cheatsheet --output '$sheet'")"
assert_equals "0" "$rc" "the cheatsheet exits 0"
assert_file_exists "$sheet" "the cheatsheet is written to the requested path"
assert_file_contains "$OUT" "Generated" "the destination is reported"
rc="$(aliases 'cmd_aliases cheatsheet --output -')"
assert_equals "0" "$rc" "writing to stdout exits 0"
assert_file_contains "$OUT" "# Cheatsheet" "the cheatsheet is printed"

test_start "aliases_cheatsheet_validates_its_options"
rc="$(aliases 'cmd_aliases cheatsheet --output')"
assert_equals "1" "$rc" "--output without a path fails"
rc="$(aliases 'cmd_aliases cheatsheet --nope')"
assert_equals "1" "$rc" "an unknown option fails"
assert_file_contains "$ERR" "Unknown option for cheatsheet" "the error names the option"

test_start "aliases_tiers_reports_the_enabled_ecosystems"
rc="$(aliases 'DOTFILES_ALIAS_ECOSYSTEMS=python,node DOTFILES_ALIAS_BUCKETS=system cmd_aliases tiers')"
assert_equals "0" "$rc" "tiers exits 0"
assert_file_contains "$OUT" "Alias Tiers" "the report header is printed"
assert_file_contains "$OUT" "python" "an enabled ecosystem is listed"
assert_file_contains "$OUT" "disabled" "a disabled ecosystem is flagged"
rc="$(aliases 'cmd_aliases tiers')"
assert_equals "0" "$rc" "the default (all) exits 0"
assert_file_contains "$OUT" "enabled" "everything is enabled by default"

test_start "aliases_rejects_an_unknown_subcommand"
rc="$(aliases 'cmd_aliases not-a-subcommand')"
assert_equals "1" "$rc" "an unknown subcommand fails"
assert_file_contains "$ERR" "Unknown aliases subcommand" "the error names the subcommand"

test_start "alias_check_reports_missing_and_present_aliases"
CHECK_HOME="$WORK/check-home"
mkdir -p "$CHECK_HOME/.config/shell/custom" "$CHECK_HOME/.config/zsh"
rc="$(aliases "HOME='$CHECK_HOME' cmd_alias_check")"
assert_equals "1" "$rc" "a missing aliases file fails the check"
assert_file_contains "$OUT" "Aliases file missing" "the missing file is reported"
assert_file_contains "$OUT" "missing" "each missing alias is reported"
{
  for a in c q e l ll la lr lra lt lta h a d _ i; do printf "alias %s='x'\n" "$a"; done
} >"$CHECK_HOME/.config/shell/90-ux-aliases.sh"
: >"$CHECK_HOME/.config/shell/custom/auto_ls.zsh"
printf 'source auto_ls.zsh\n' >"$CHECK_HOME/.config/zsh/.zshrc"
rc="$(aliases "HOME='$CHECK_HOME' cmd_alias_check")"
assert_equals "0" "$rc" "a complete alias set passes"
assert_file_contains "$OUT" "All core aliases present" "the pass summary is printed"
assert_file_contains "$OUT" "auto-ls sourced" "the auto-ls hook is checked"

# ---------------------------------------------------------------------------
# restore.sh
# ---------------------------------------------------------------------------
# restore <args…> — run restore.sh with a sandboxed HOME and data dir.
restore() {
  local rc=0
  PATH="$BIN:/usr/bin:/bin" HOME="$RESTORE_HOME" \
    XDG_DATA_HOME="$RESTORE_HOME/.local/share" \
    XDG_STATE_HOME="$RESTORE_HOME/.local/state" \
    DOTFILES_DIR="$RESTORE_HOME/.dotfiles" \
    "$REAL_BASH" "$RESTORE" "$@" </dev/null >"$OUT" 2>"$ERR" || rc=$?
  cat "$ERR" >&2
  printf '%s' "$rc"
}
new_restore_home() {
  RESTORE_HOME="$WORK/restore-$1"
  rm -rf "$RESTORE_HOME"
  mkdir -p "$RESTORE_HOME"
}

test_start "restore_usage_and_unknown_options"
new_restore_home usage
rc="$(restore --help)"
assert_equals "0" "$rc" "--help exits 0"
assert_file_contains "$OUT" "Usage: dot restore" "usage is printed"
rc="$(restore -h)"
assert_equals "0" "$rc" "-h exits 0"
rc="$(restore)"
assert_equals "0" "$rc" "no arguments prints usage and exits 0"
assert_file_contains "$OUT" "--latest" "the options are documented"
rc="$(restore --nope)"
assert_equals "1" "$rc" "an unknown option fails"
assert_file_contains "$OUT" "Usage: dot restore" "usage follows the error"

test_start "restore_list_reports_an_empty_backup_directory"
new_restore_home empty
rc="$(restore --list)"
assert_equals "1" "$rc" "listing with no backup directory returns 1"
assert_file_contains "$OUT" "No backups found" "the empty state is reported"

test_start "restore_list_shows_backups_newest_first"
new_restore_home list
BACKUPS="$RESTORE_HOME/.local/share/dotfiles/backups"
mkdir -p "$BACKUPS/backup-20200101_000000" "$BACKUPS/backup-20240101_000000"
touch -t 202001010000 "$BACKUPS/backup-20200101_000000"
touch -t 202401010000 "$BACKUPS/backup-20240101_000000"
mkdir -p "$RESTORE_HOME/.dotfiles/.git"
rc="$(restore -l)"
assert_equals "0" "$rc" "listing exits 0"
assert_file_contains "$OUT" "Available Backups" "the header is printed"
assert_file_contains "$OUT" "backup-20240101_000000" "each backup is listed"
assert_file_contains "$OUT" "Git History" "the git history section is printed"
newest="$(grep -o 'backup-[0-9_]*' "$OUT" | head -1)"
assert_equals "backup-20240101_000000" "$newest" "the newest backup is listed first"

test_start "restore_latest_copies_the_newest_backup_back"
printf 'restored-content\n' >"$BACKUPS/backup-20240101_000000/.zshrc"
rc="$(restore --latest)"
assert_equals "0" "$rc" "restoring exits 0"
assert_file_contains "$OUT" "Restoring from: backup-20240101_000000" "the newest backup is chosen"
assert_file_exists "$RESTORE_HOME/.zshrc" "the file is restored into HOME"
assert_file_contains "$RESTORE_HOME/.zshrc" "restored-content" "the restored content matches the backup"

test_start "restore_latest_reports_an_empty_backup_store"
new_restore_home nolatest
mkdir -p "$RESTORE_HOME/.local/share/dotfiles/backups"
rc="$(restore -L)"
assert_equals "1" "$rc" "an empty backup directory returns 1"
assert_file_contains "$OUT" "No backups found" "the empty state is reported"

test_start "restore_from_a_git_ref_backs_up_first"
new_restore_home git
mkdir -p "$RESTORE_HOME/.dotfiles/.git"
: >"$CALLS"
rc="$(restore --git HEAD~1)"
assert_equals "0" "$rc" "restoring from a ref exits 0"
assert_file_contains "$OUT" "Restoring from git ref: HEAD~1" "the ref is named"
assert_file_contains "$CALLS" "checkout HEAD~1 -- ." "the checkout is performed"
assert_file_contains "$CALLS" "chezmoi apply" "chezmoi re-applies after the checkout"
backup_made="$(find "$RESTORE_HOME/.local/share/dotfiles/backups" -maxdepth 1 -name 'backup-*' | wc -l | tr -d ' ')"
assert_equals "1" "$backup_made" "a backup is taken before restoring"

test_start "restore_git_dry_run_only_shows_the_diff"
new_restore_home gitdry
mkdir -p "$RESTORE_HOME/.dotfiles/.git"
: >"$CALLS"
rc="$(restore --dry-run --git HEAD~1)"
assert_equals "0" "$rc" "the dry run exits 0"
assert_file_contains "$OUT" "Dry run" "the dry run announces itself"
assert_file_contains "$CALLS" "diff HEAD~1 --stat" "only a diff is requested"
assert_output_not_contains "checkout" "cat '$CALLS'"

test_start "restore_diff_shows_the_difference_for_a_ref"
new_restore_home diff
mkdir -p "$RESTORE_HOME/.dotfiles/.git"
: >"$CALLS"
rc="$(restore --diff v1.0.0)"
assert_equals "0" "$rc" "--diff exits 0"
assert_file_contains "$CALLS" "diff v1.0.0" "the ref is diffed"

test_start "restore_git_operations_need_a_repository"
new_restore_home norepo
rc="$(restore --git HEAD)"
assert_equals "1" "$rc" "no repository is an error"
assert_file_contains "$OUT" "No git repository found" "the error explains the failure"
rc="$(restore --diff HEAD)"
assert_equals "1" "$rc" "the same applies to --diff"

test_start "restore_uses_the_chezmoi_source_repository_when_present"
new_restore_home chezmoisrc
mkdir -p "$RESTORE_HOME/.local/share/chezmoi/.git"
: >"$CALLS"
rc="$(restore --diff HEAD)"
assert_equals "0" "$rc" "the chezmoi source repository is used"
assert_file_contains "$CALLS" "$RESTORE_HOME/.local/share/chezmoi" "git runs against the chezmoi source"

# ---------------------------------------------------------------------------
# init.sh
# ---------------------------------------------------------------------------
# init <snippet> — source init.sh (which pulls in ui.sh and utils.sh) and run
# the snippet.
init() {
  local snippet="$1" rc=0
  PATH="${INIT_PATH:-$BIN:/usr/bin:/bin}" HOME="$INIT_HOME" \
    "$REAL_BASH" -c "
      source '$INIT'
      set +e
      $snippet
    " </dev/null >"$OUT" 2>"$ERR" || rc=$?
  cat "$ERR" >&2
  printf '%s' "$rc"
}
new_init_home() {
  INIT_HOME="$WORK/init-$1"
  rm -rf "$INIT_HOME"
  mkdir -p "$INIT_HOME"
}

test_start "init_resolves_every_source_shorthand"
new_init_home resolve
rc="$(init '_init_resolve_url alice')"
assert_equals "0" "$rc" "a bare user resolves"
assert_file_contains "$OUT" "https://github.com/alice/dotfiles.git" "a bare user becomes a GitHub dotfiles URL"
init '_init_resolve_url alice/configs' >/dev/null
assert_file_contains "$OUT" "https://github.com/alice/configs.git" "owner/repo becomes a GitHub URL"
init '_init_resolve_url https://example.com/repo.git' >/dev/null
assert_file_contains "$OUT" "https://example.com/repo.git" "an explicit HTTPS URL is passed through"
init '_init_resolve_url git@github.com:alice/dotfiles.git' >/dev/null
assert_file_contains "$OUT" "git@github.com:alice/dotfiles.git" "an SSH URL is passed through"

test_start "init_refuses_plain_http_and_unsafe_shorthands"
rc="$(init '_init_resolve_url http://example.com/repo.git')"
assert_equals "2" "$rc" "plain HTTP is refused"
assert_file_contains "$ERR" "refusing plain HTTP" "the refusal explains why"
rc="$(init '_init_resolve_url "alice/../../etc"')"
assert_equals "2" "$rc" "a traversal-shaped owner/repo is refused"
assert_file_contains "$ERR" "invalid owner/repo" "the refusal names the problem"
rc="$(init '_init_resolve_url "alice;whoami"')"
assert_equals "2" "$rc" "a shell-metacharacter user is refused"
assert_file_contains "$ERR" "invalid user" "the refusal names the problem"

test_start "init_help_and_argument_validation"
rc="$(init 'cmd_init --help')"
assert_equals "0" "$rc" "--help exits 0"
assert_file_contains "$OUT" "Usage: dot init" "usage is printed"
rc="$(init 'cmd_init')"
assert_equals "1" "$rc" "no argument fails"
assert_file_contains "$OUT" "missing <user|repo|url>" "the error asks for a source"
rc="$(init 'cmd_init --not-a-flag')"
assert_equals "1" "$rc" "an unknown flag fails"
assert_file_contains "$OUT" "Unknown flag" "the error names the flag"
rc="$(init 'cmd_init alice bob')"
assert_equals "1" "$rc" "two positional arguments fail"
assert_file_contains "$OUT" "Too many arguments" "the error explains the refusal"

test_start "init_dry_run_makes_no_changes"
new_init_home dryrun
: >"$CALLS"
rc="$(init 'cmd_init alice --dry-run')"
assert_equals "0" "$rc" "the dry run exits 0"
assert_file_contains "$OUT" "Source URL" "the resolved URL is shown"
assert_file_contains "$OUT" "no changes made" "the dry run says so"
assert_output_not_contains "chezmoi init" "cat '$CALLS'"

test_start "init_requires_chezmoi"
NOCHEZMOI="$WORK/init-nochezmoi"
mkdir -p "$NOCHEZMOI"
for tool in bash sh printf cat grep sed awk mkdir rm head uname locale dirname; do
  p="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$NOCHEZMOI/$tool"
done
rc="$(INIT_PATH="$NOCHEZMOI" init 'cmd_init alice')"
assert_equals "127" "$rc" "a missing chezmoi is rc=127"
assert_file_contains "$OUT" "not installed" "the error says chezmoi is missing"

test_start "init_refuses_to_clobber_an_existing_source_directory"
new_init_home existing
mkdir -p "$INIT_HOME/.local/share/chezmoi"
rc="$(DOTFILES_NONINTERACTIVE=1 init 'cmd_init alice')"
assert_equals "1" "$rc" "an existing source directory is refused"
assert_file_contains "$OUT" "pass --force to overwrite" "the error says how to proceed"

test_start "init_clones_and_applies_with_force"
new_init_home force
mkdir -p "$INIT_HOME/.local/share/chezmoi"
: >"$CALLS"
rc="$(DOTFILES_NONINTERACTIVE=1 init 'cmd_init alice --force')"
assert_equals "0" "$rc" "the forced init exits 0"
assert_file_contains "$CALLS" "chezmoi init --source" "chezmoi is asked to initialise the source"
assert_file_contains "$CALLS" "--apply" "the tree is applied by default"
assert_file_contains "$CALLS" "https://github.com/alice/dotfiles.git" "the resolved URL is handed to chezmoi"
assert_file_contains "$OUT" "run 'dot doctor'" "the follow-up hint is printed"

test_start "init_no_apply_clones_without_applying"
new_init_home noapply
: >"$CALLS"
rc="$(DOTFILES_NONINTERACTIVE=1 init 'cmd_init alice --no-apply')"
assert_equals "0" "$rc" "--no-apply exits 0"
assert_output_not_contains "--apply" "cat '$CALLS'"
assert_file_contains "$OUT" "chezmoi diff" "the manual follow-up is suggested"

test_start "init_reports_a_failed_clone"
new_init_home failed
: >"$CALLS"
rc="$(DOTFILES_NONINTERACTIVE=1 FAKE_CHEZMOI_RC=3 init 'cmd_init alice')"
assert_equals "3" "$rc" "chezmoi's exit status is propagated"
assert_file_contains "$OUT" "chezmoi exited 3" "the failure is reported with its code"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
