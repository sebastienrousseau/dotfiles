#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Regression for: GH-881
# Regression: FEATURE-MATRIX coverage for the aliases.sh command group —
# `dot aliases {list,search,why,stats,cheatsheet,tiers}` and `dot alias-check`.
#
# Split out of test_feature_matrix_tools.sh: every one of these rows shells
# out to the alias manifest, which walks the whole chezmoi alias template
# tree, and together they pushed that file past the 180s per-suite budget
# tests/regression/test_test_framework_invariants.sh allows when it re-runs
# each suite to check the RUN == PASSED + FAILED invariant.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/feature_matrix_lib.sh"

trap fm_sandbox_teardown EXIT
fm_sandbox_setup

test_fm_aliases_list() {
  test_start "fm_aliases_list"
  fm_run aliases list
  fm_expect_rc_in 0 1
  test_start "fm_aliases_list_is_populated"
  fm_expect_nonempty
  test_start "fm_aliases_list_has_a_table_header"
  fm_expect_any "Name" "Aliases"
}

test_fm_aliases_search() {
  test_start "fm_aliases_search"
  fm_run aliases search git
  fm_expect_rc_in 0 1
  test_start "fm_aliases_search_reports_the_query"
  fm_expect_any "git" "Alias Search"
}

test_fm_aliases_search_nomatch() {
  test_start "fm_aliases_search_nomatch"
  fm_run aliases search zzz-no-such-alias-zzz
  fm_expect_rc 1
  test_start "fm_aliases_search_nomatch_says_so"
  fm_expect_any "No matches" "zzz-no-such-alias-zzz"
  test_start "fm_aliases_search_missing_term"
  fm_run aliases search
  fm_expect_rc 1
  test_start "fm_aliases_search_missing_term_message"
  fm_expect_any "Usage: dot aliases search" "search"
}

test_fm_aliases_why() {
  test_start "fm_aliases_why"
  fm_run aliases why ll
  fm_expect_rc_in 0 1
  test_start "fm_aliases_why_shows_the_definition"
  fm_expect_any "ll" "Alias Details"
}

test_fm_aliases_why_unknown() {
  test_start "fm_aliases_why_unknown"
  fm_run aliases why zzz-no-such-alias-zzz
  fm_expect_rc 1
  test_start "fm_aliases_why_unknown_says_so"
  fm_expect_any "not found" "zzz-no-such-alias-zzz"
}

test_fm_aliases_stats() {
  printf ': 1700000000:0;ll\n: 1700000001:0;ll\n: 1700000002:0;gs\n' \
    >"$FM_SANDBOX/.zsh_history"
  test_start "fm_aliases_stats"
  fm_run aliases stats
  fm_expect_rc_in 0 1
  test_start "fm_aliases_stats_counts_from_history"
  fm_expect_any "ll" "Alias Usage"
  rm -f "$FM_SANDBOX/.zsh_history"
}

test_fm_aliases_stats_missing() {
  rm -f "$FM_SANDBOX/.zsh_history"
  test_start "fm_aliases_stats_missing"
  HISTFILE="$FM_SANDBOX/definitely-no-history" fm_run aliases stats
  fm_expect_rc 1
  test_start "fm_aliases_stats_missing_says_so"
  fm_expect_err "not found"
}

test_fm_aliases_cheatsheet_stdout() {
  test_start "fm_aliases_cheatsheet_stdout"
  fm_run aliases cheatsheet --output -
  fm_expect_rc_in 0 1
  test_start "fm_aliases_cheatsheet_stdout_is_markdown"
  fm_expect_any "# Alias Cheatsheet" "Cheatsheet"
}

test_fm_aliases_cheatsheet() {
  local out="$FM_SANDBOX/work/cheatsheet.md"
  test_start "fm_aliases_cheatsheet"
  fm_run aliases cheatsheet --output "$out"
  fm_expect_rc_in 0 1
  test_start "fm_aliases_cheatsheet_wrote_the_file"
  fm_expect_file "$out"
  test_start "fm_aliases_cheatsheet_rejects_unknown_option"
  fm_run aliases cheatsheet --zzz-not-an-option
  fm_expect_rc 1
}

test_fm_aliases_cheatsheet_default() {
  # With no --output the cheatsheet is written into the source tree's docs/.
  # Drive the sandbox copy so the checkout is left alone.
  local repo
  repo="$(fm_repo_copy_aliases)"
  test_start "fm_aliases_cheatsheet_default"
  fm_run_bin "$repo/bin/dot" aliases cheatsheet
  fm_expect_rc_in 0 1
  test_start "fm_aliases_cheatsheet_default_did_not_touch_the_checkout"
  if [[ -n "$(git -C "$REPO_ROOT" status --porcelain -- docs 2>/dev/null)" ]]; then
    fm_fail "the checkout's docs/ was modified"
  else
    fm_pass "checkout untouched"
  fi
}

test_fm_aliases_tiers() {
  test_start "fm_aliases_tiers"
  fm_run aliases tiers
  fm_expect_rc_in 0 1
  test_start "fm_aliases_tiers_reports_the_tiers"
  fm_expect_any "Alias Tiers" "Ecosystems"
}

test_fm_env_dotfiles_alias_tiers() {
  # Each of the five knobs must be reflected in the report rather than
  # ignored: pass a distinctive value and require it back.
  test_start "fm_env_dotfiles_alias_tiers_profile"
  DOTFILES_ALIAS_PROFILE=fm-profile fm_run aliases tiers
  fm_expect_out "fm-profile"

  test_start "fm_env_dotfiles_alias_tiers_ecosystems"
  DOTFILES_ALIAS_ECOSYSTEMS=python fm_run aliases tiers
  fm_expect_out "python"

  test_start "fm_env_dotfiles_alias_tiers_buckets"
  DOTFILES_ALIAS_BUCKETS=fm-bucket fm_run aliases tiers
  fm_expect_out "fm-bucket"

  test_start "fm_env_dotfiles_alias_tiers_security_mode"
  DOTFILES_SECURITY_MODE=fm-strict fm_run aliases tiers
  fm_expect_out "fm-strict"

  test_start "fm_env_dotfiles_alias_tiers_dangerous"
  DOTFILES_ENABLE_DANGEROUS_ALIASES=1 fm_run aliases tiers
  fm_expect_out "Dangerous Aliases"

  # Disabling an ecosystem must actually mark it disabled.
  test_start "fm_env_dotfiles_alias_tiers_disables_an_ecosystem"
  DOTFILES_ALIAS_ECOSYSTEMS=python fm_run aliases tiers
  if printf '%s' "$FM_OUT" | grep -Eq 'node.*disabled|disabled.*node'; then
    fm_pass "node reported disabled"
  else
    fm_fail "node not marked disabled when ecosystems=python"
  fi
}

test_fm_aliases_unknown() {
  test_start "fm_aliases_unknown"
  fm_run aliases zzz-not-a-subcommand
  fm_expect_rc 1
  test_start "fm_aliases_unknown_message"
  fm_expect_any "Unknown aliases subcommand" "zzz-not-a-subcommand"
}

test_fm_alias_check() {
  test_start "fm_alias_check"
  fm_run alias-check
  # In a sandboxed HOME the deployed alias file is absent, so a non-zero
  # "some aliases missing" verdict is the correct answer.
  fm_expect_rc_in 0 1
  test_start "fm_alias_check_reports_each_alias"
  fm_expect_any "Alias Check" "alias"
}

# ── run ────────────────────────────────────────────────────────────────────

echo ""
echo "── FEATURE-MATRIX: aliases ──"
echo ""

test_fm_aliases_list
test_fm_aliases_search
test_fm_aliases_search_nomatch
test_fm_aliases_why
test_fm_aliases_why_unknown
test_fm_aliases_stats
test_fm_aliases_stats_missing
test_fm_aliases_cheatsheet_stdout
test_fm_aliases_cheatsheet
test_fm_aliases_cheatsheet_default
test_fm_aliases_tiers
test_fm_env_dotfiles_alias_tiers
test_fm_aliases_unknown
test_fm_alias_check

fm_finish
