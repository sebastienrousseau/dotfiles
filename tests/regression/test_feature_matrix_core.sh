#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Regression for: GH-881
# Regression: FEATURE-MATRIX coverage for the bin/dot dispatcher and the
# core.sh command group (sync/apply/update/add/diff/status/cd/edit/commit/
# uninstall), plus the dispatcher-level behaviours every other command
# inherits: the universal --help intercept, the route table's flag aliases,
# unknown-command handling, user-supplied commands, and the two environment
# variables that change the CLI's own rendering.
#
# Each function here backs one row of docs/reference/FEATURE-MATRIX.md and is
# verified to exist by scripts/qa/check-feature-matrix.sh.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/feature_matrix_lib.sh"

trap fm_sandbox_teardown EXIT
fm_sandbox_setup

# ── dispatcher: version ────────────────────────────────────────────────────

test_fm_version() {
  test_start "fm_version"
  fm_run version
  fm_expect_rc 0
  test_start "fm_version_reports_dotfiles_version"
  fm_expect_out_matches '\.dotfiles [0-9]+\.[0-9]+\.[0-9]+'
}

test_fm_version_long_flag() {
  test_start "fm_version_long_flag"
  fm_run --version
  fm_expect_rc 0
  test_start "fm_version_long_flag_matches_subcommand"
  fm_expect_out_matches '\.dotfiles [0-9]+\.[0-9]+\.[0-9]+'
}

test_fm_version_short_flag() {
  test_start "fm_version_short_flag"
  fm_run -v
  fm_expect_rc 0
  test_start "fm_version_short_flag_matches_subcommand"
  fm_expect_out_matches '\.dotfiles [0-9]+\.[0-9]+\.[0-9]+'
}

# ── dispatcher: help ───────────────────────────────────────────────────────

test_fm_help_overview() {
  test_start "fm_help_overview"
  fm_run help
  fm_expect_rc 0
  test_start "fm_help_overview_has_start_here"
  fm_expect_out "Start Here"
}

test_fm_help_no_args() {
  test_start "fm_help_no_args"
  fm_run
  fm_expect_rc 0
  test_start "fm_help_no_args_shows_overview"
  fm_expect_out "Start Here"
}

test_fm_help_long_flag() {
  test_start "fm_help_long_flag"
  fm_run --help
  fm_expect_rc 0
  test_start "fm_help_long_flag_shows_overview"
  fm_expect_out "Start Here"
}

test_fm_help_short_flag() {
  test_start "fm_help_short_flag"
  fm_run -h
  fm_expect_rc 0
  test_start "fm_help_short_flag_shows_overview"
  fm_expect_out "Start Here"
}

test_fm_help_all() {
  test_start "fm_help_all"
  fm_run help all
  fm_expect_rc 0
  test_start "fm_help_all_lists_full_reference"
  fm_expect_out "Command Reference"
  # `help all` is the source the command index is generated from, so it has to
  # stay substantially larger than the overview.
  test_start "fm_help_all_is_larger_than_overview"
  local all_lines
  all_lines="$(printf '%s' "$FM_OUT" | wc -l | tr -d ' ')"
  fm_run help
  local overview_lines
  overview_lines="$(printf '%s' "$FM_OUT" | wc -l | tr -d ' ')"
  if [[ "$all_lines" -gt "$overview_lines" ]]; then
    fm_pass "$all_lines > $overview_lines lines"
  else
    fm_fail "help all ($all_lines lines) is not larger than help ($overview_lines)"
  fi
}

test_fm_help_topic() {
  test_start "fm_help_topic"
  fm_run help doctor
  fm_expect_rc 0
  test_start "fm_help_topic_names_the_command"
  fm_expect_out "dot doctor"
  test_start "fm_help_topic_has_summary"
  fm_expect_out "Summary"
}

test_fm_help_unknown_topic() {
  test_start "fm_help_unknown_topic"
  fm_run help definitely-not-a-command
  fm_expect_rc 1
  test_start "fm_help_unknown_topic_says_so"
  fm_expect_err "Unknown help topic"
}

test_fm_help_universal_intercept() {
  # The 2026-07 audit: `dot <cmd> --help` used to run the command. The
  # dispatcher now intercepts before routing. `edit` is the sharpest probe —
  # unintercepted it would exec $EDITOR — and `upgrade` the most expensive.
  local cmd
  for cmd in edit upgrade sandbox backup; do
    test_start "fm_help_universal_intercept_${cmd}"
    fm_run "$cmd" --help
    if [[ "$FM_RC" -ne 0 ]]; then
      fm_fail "dot $cmd --help exited $FM_RC"
      continue
    fi
    if [[ "$FM_OUT" != *"dot $cmd"* ]]; then
      fm_fail "dot $cmd --help did not render help for '$cmd'"
      continue
    fi
    fm_pass
  done

  # -h is the same path.
  test_start "fm_help_universal_intercept_short_flag"
  fm_run edit -h
  fm_expect_rc 0

  # And the intercept must not have written anything: $EDITOR is a recording
  # stub for this check, and must never have been invoked.
  fm_stub fm-editor "printf 'RAN\\n' >>'$FM_SANDBOX/editor-ran.log'"
  test_start "fm_help_universal_intercept_does_not_spawn_editor"
  EDITOR="$FM_SANDBOX/bin/fm-editor" fm_run edit --help
  if [[ -e "$FM_SANDBOX/editor-ran.log" ]]; then
    fm_fail "dot edit --help spawned \$EDITOR"
  else
    fm_pass "editor never invoked"
  fi
}

# ── dispatcher: search ─────────────────────────────────────────────────────

test_fm_search() {
  test_start "fm_search"
  fm_run search theme
  fm_expect_rc 0
  test_start "fm_search_finds_matching_command"
  fm_expect_out "theme"
}

test_fm_search_missing_keyword() {
  test_start "fm_search_missing_keyword"
  fm_run search
  fm_expect_rc 1
  test_start "fm_search_missing_keyword_prints_usage"
  fm_expect_out "Usage: dot search"
}

test_fm_search_no_match() {
  test_start "fm_search_no_match"
  fm_run search zzz-no-such-command-zzz
  fm_expect_rc 0
  test_start "fm_search_no_match_says_so"
  fm_expect_out "No commands matching"
}

# ── dispatcher: unknown + user commands ────────────────────────────────────

test_fm_unknown_command() {
  test_start "fm_unknown_command"
  fm_run zzz-not-a-command
  fm_expect_rc 1
  test_start "fm_unknown_command_message"
  fm_expect_err "Unknown command"
}

test_fm_user_custom_command() {
  local dir="$XDG_CONFIG_HOME/dotfiles/commands"
  mkdir -p "$dir"
  printf '#!/usr/bin/env bash\nprintf "custom-ran:%%s\\n" "${1:-}"\nexit 7\n' \
    >"$dir/fmdemo.sh"

  test_start "fm_user_custom_command"
  fm_run fmdemo hello
  fm_expect_out "custom-ran:hello"

  # A user command's exit code must reach the caller, and its `exit` must not
  # kill the dispatcher (bin/dot sources it in a subshell for exactly this).
  test_start "fm_user_custom_command_propagates_exit_code"
  fm_expect_rc 7

  rm -rf "$dir"
}

# ── dispatcher: rendering environment ──────────────────────────────────────

test_fm_env_dotfiles_show_logo() {
  test_start "fm_env_dotfiles_show_logo_suppresses_banner"
  DOTFILES_SHOW_LOGO=0 fm_run version
  if [[ "$FM_OUT" == *"◈"* ]]; then
    fm_fail "banner glyph still printed with DOTFILES_SHOW_LOGO=0"
  else
    fm_pass "no banner"
  fi
  test_start "fm_env_dotfiles_show_logo_still_reports_version"
  fm_expect_out_matches '\.dotfiles [0-9]+\.'
}

test_fm_env_no_color() {
  test_start "fm_env_no_color"
  NO_COLOR=1 fm_run version
  fm_expect_rc 0
  test_start "fm_env_no_color_strips_ansi"
  if printf '%s' "$FM_OUT" | grep -q $'\033\['; then
    fm_fail "ANSI escape sequences present despite NO_COLOR=1"
  else
    fm_pass "no ANSI escapes"
  fi
}

# ── core.sh ────────────────────────────────────────────────────────────────

test_fm_sync() {
  test_start "fm_sync"
  fm_run sync --check
  fm_expect_rc 0
  test_start "fm_sync_announces_apply"
  fm_expect_any "Applying dotfiles" "Chezmoi apply"
}

test_fm_apply() {
  test_start "fm_apply"
  fm_run apply --dry-run
  fm_expect_rc 0
  test_start "fm_apply_is_alias_of_sync"
  fm_expect_any "Applying dotfiles" "Chezmoi apply"
}

test_fm_update() {
  test_start "fm_update"
  fm_run update
  fm_expect_rc 0
  test_start "fm_update_announces_update"
  fm_expect_any "Updating" "update"
}

test_fm_add() {
  printf 'demo\n' >"$FM_SANDBOX/work/added.txt"
  test_start "fm_add"
  fm_run add "$FM_SANDBOX/work/added.txt"
  fm_expect_rc 0
  test_start "fm_add_no_breakage"
  fm_expect_no_forbidden
}

test_fm_add_usage() {
  test_start "fm_add_usage"
  fm_run add
  fm_expect_rc 1
  test_start "fm_add_usage_message"
  fm_expect_out "Usage: dot add"
}

test_fm_diff() {
  test_start "fm_diff"
  fm_run diff
  fm_expect_rc 0
  test_start "fm_diff_no_breakage"
  fm_expect_no_forbidden
}

test_fm_status() {
  test_start "fm_status"
  fm_run status
  fm_expect_rc 0
  test_start "fm_status_reports_clean_tree"
  fm_expect_out "Clean"
}

test_fm_status_drift() {
  # A drifted tree must surface chezmoi's report rather than claiming clean.
  fm_stub chezmoi 'if [[ "$1" == status ]]; then printf " M .zshrc\n"; fi; exit 0'
  test_start "fm_status_drift"
  fm_run status
  fm_expect_rc 0
  test_start "fm_status_drift_lists_the_file"
  fm_expect_out ".zshrc"
  test_start "fm_status_drift_does_not_claim_clean"
  if [[ "$FM_OUT" == *"no local drift"* ]]; then
    fm_fail "reported a clean tree while chezmoi listed drift"
  else
    fm_pass
  fi
  fm_stub chezmoi 'exit 0'
}

test_fm_cd() {
  test_start "fm_cd"
  fm_run cd
  fm_expect_rc 0
  test_start "fm_cd_prints_an_existing_directory"
  if [[ -d "$FM_OUT" ]]; then
    fm_pass "$FM_OUT"
  else
    fm_fail "not a directory: '$FM_OUT'"
  fi
}

test_fm_edit() {
  test_start "fm_edit"
  EDITOR=true fm_run edit
  fm_expect_rc 0
}

test_fm_env_editor() {
  # $EDITOR must receive the source directory as its argument.
  fm_stub fm-editor "printf '%s\\n' \"\$1\" >'$FM_SANDBOX/edited-path'"
  test_start "fm_env_editor"
  EDITOR="$FM_SANDBOX/bin/fm-editor" fm_run edit
  fm_expect_rc 0
  test_start "fm_env_editor_receives_source_dir"
  if [[ -s "$FM_SANDBOX/edited-path" ]] && [[ -d "$(cat "$FM_SANDBOX/edited-path")" ]]; then
    fm_pass "$(cat "$FM_SANDBOX/edited-path")"
  else
    fm_fail "\$EDITOR was not called with the source directory"
  fi
  rm -f "$FM_SANDBOX/edited-path"
}

test_fm_commit() {
  local repo="$FM_SANDBOX/work/commitrepo"
  mkdir -p "$repo"
  git -C "$repo" init -q 2>/dev/null || true
  test_start "fm_commit"
  # Not a `( cd … && fm_run )` subshell: fm_run's captured output would not
  # survive it, and the assertions below would silently read a stale run.
  local prev_pwd="$PWD"
  cd "$repo" || return 0
  fm_run commit
  cd "$prev_pwd" || return 0
  # With nothing staged the helper must refuse cleanly rather than invoking a
  # model. It is the one exit path reachable without an AI provider.
  fm_expect_rc_in 0 1
  # The contract is that `dot commit` REFUSES cleanly rather than invoking a
  # model — not which refusal it reaches first. There are two, and which one
  # fires depends on the host: with an AI provider installed (a developer
  # machine) it gets as far as the staged-changes check; with none (a CI
  # runner) it stops at the provider check. Asserting only the first was a
  # macOS assumption, and it failed on the Linux runner where no provider
  # exists.
  test_start "fm_commit_refuses_without_staged_changes"
  fm_expect_any "No staged changes" "staged" "No AI provider found"
}

test_fm_smoke_uninstall() {
  fm_smoke uninstall
}

test_fm_smoke_uninstall_force() {
  # --force takes the same intercepted help path; the real flag would purge
  # the managed environment, so only the intercept is exercised.
  test_start "fm_smoke_uninstall_force"
  fm_run uninstall --force --help
  fm_expect_rc 0
  test_start "fm_smoke_uninstall_force_renders_help"
  fm_expect_out "dot uninstall"
}

# ── run ────────────────────────────────────────────────────────────────────

echo ""
echo "── FEATURE-MATRIX: dispatcher + core ──"
echo ""

test_fm_version
test_fm_version_long_flag
test_fm_version_short_flag
test_fm_help_overview
test_fm_help_no_args
test_fm_help_long_flag
test_fm_help_short_flag
test_fm_help_all
test_fm_help_topic
test_fm_help_unknown_topic
test_fm_help_universal_intercept
test_fm_search
test_fm_search_missing_keyword
test_fm_search_no_match
test_fm_unknown_command
test_fm_user_custom_command
test_fm_env_dotfiles_show_logo
test_fm_env_no_color
test_fm_sync
test_fm_apply
test_fm_update
test_fm_add
test_fm_add_usage
test_fm_diff
test_fm_status
test_fm_status_drift
test_fm_cd
test_fm_edit
test_fm_env_editor
test_fm_commit
test_fm_smoke_uninstall
test_fm_smoke_uninstall_force

fm_finish
