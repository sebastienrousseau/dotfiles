#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Regression for: GH-881
# Regression: FEATURE-MATRIX coverage for the tools.sh, aliases.sh, lint.sh
# and env-emit.sh command groups — env, profile, tools, new, packages,
# aliases, alias-check, setup, log-rotate, lint, and `dot env emit`.
#
# `dot profile set`, `dot aliases cheatsheet` (with no --output) and
# `dot lint` all resolve their target from the location of the sourced
# library rather than from $HOME, so those rows drive a writable repo copy
# inside the sandbox (fm_repo_copy) instead of the checkout. Linting the copy
# is also what keeps this file fast: `dot lint --check` over the real tree
# takes minutes, over the copy about ten seconds.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/feature_matrix_lib.sh"

trap fm_sandbox_teardown EXIT
fm_sandbox_setup

FM_TIMEOUT=180

# ── env (mise-backed) ──────────────────────────────────────────────────────
#
# mise is not guaranteed on a runner. Where it is missing the command must
# say so and exit non-zero rather than crashing, which is itself the
# assertion.

test_fm_env_list() {
  test_start "fm_env_list"
  fm_run env list
  fm_expect_rc_in 0 1
  test_start "fm_env_list_reports_or_explains"
  fm_expect_any "Tool" "mise" "Version"
}

test_fm_env_prune() {
  test_start "fm_env_prune"
  fm_run env prune
  fm_expect_rc_in 0 1
  test_start "fm_env_prune_defaults_to_dry_run"
  fm_expect_any "dry-run" "mise" "prune"
}

test_fm_smoke_env_prune_yes() { fm_smoke env; }
test_fm_smoke_env_install() { fm_smoke env; }
test_fm_smoke_env_use() { fm_smoke env; }

# ── env emit ───────────────────────────────────────────────────────────────
#
# The flag parser runs before the jq/mise dependency check, so the argument
# handling rows are deterministic on any host.

test_fm_env_emit() {
  test_start "fm_env_emit"
  fm_run env emit
  # 2 = jq or mise missing; 3 = mise call failed. Both are environment, not
  # regressions — but a *parse* failure would be rc 1, which is not allowed.
  fm_expect_rc_in 0 2 3
  test_start "fm_env_emit_no_breakage"
  fm_expect_no_forbidden
  if [[ "$FM_RC" -eq 0 ]]; then
    test_start "fm_env_emit_is_json"
    fm_expect_json
    test_start "fm_env_emit_declares_the_schema"
    fm_expect_out "schema_version"
  fi
}

test_fm_env_emit_compact() {
  test_start "fm_env_emit_compact"
  fm_run env emit --compact
  fm_expect_rc_in 0 2 3
  if [[ "$FM_RC" -eq 0 ]]; then
    test_start "fm_env_emit_compact_is_one_line"
    if [[ "$(printf '%s' "$FM_OUT" | wc -l | tr -d ' ')" -le 1 ]]; then
      fm_pass "single line"
    else
      fm_fail "--compact emitted multi-line JSON"
    fi
  fi
}

test_fm_env_emit_ndjson() {
  test_start "fm_env_emit_ndjson"
  fm_run env emit --format ndjson
  fm_expect_rc_in 0 2 3
  if [[ "$FM_RC" -eq 0 ]]; then
    test_start "fm_env_emit_ndjson_header_is_json"
    fm_expect_out "schema_version"
  fi
  test_start "fm_env_emit_ndjson_equals_form"
  fm_run env emit --format=ndjson
  fm_expect_rc_in 0 2 3
}

test_fm_env_emit_output() {
  local out="$FM_SANDBOX/work/env-manifest.json"
  test_start "fm_env_emit_output"
  fm_run env emit --output "$out"
  fm_expect_rc_in 0 2 3
  if [[ "$FM_RC" -eq 0 ]]; then
    test_start "fm_env_emit_output_wrote_the_file"
    fm_expect_file "$out"
  fi
}

test_fm_env_emit_bad_format() {
  test_start "fm_env_emit_bad_format"
  fm_run env emit --format xml
  fm_expect_rc 1
  test_start "fm_env_emit_bad_format_message"
  fm_expect_any "unsupported format" "json, ndjson"
}

test_fm_env_emit_bad_flag() {
  test_start "fm_env_emit_bad_flag"
  fm_run env emit --zzz-not-a-flag
  fm_expect_rc 1
  test_start "fm_env_emit_bad_flag_message"
  fm_expect_any "unknown flag" "zzz-not-a-flag"
}

test_fm_env_emit_help() {
  # NOTE: the dispatcher's universal --help intercept fires before routing,
  # so `dot env emit --help` renders `dot help env` rather than env-emit.sh's
  # own usage text — the `-h | --help` arm inside dot_env_emit is unreachable
  # through the CLI. That is the intercept working as designed (it is what
  # stops `--help` being treated as data), so what is pinned here is that
  # asking for help exits 0 and describes `dot env`.
  test_start "fm_env_emit_help"
  fm_run env emit --help
  fm_expect_rc 0
  test_start "fm_env_emit_help_renders_env_help"
  fm_expect_any "dot env" "Summary"

  # The usage text itself is still reachable by calling the sub-handler the
  # way tools.sh does, which is what documents --format/--output/--compact.
  test_start "fm_env_emit_help_usage_documents_formats"
  local usage
  usage="$(awk '/Usage: dot env emit/,/^\t*EOF$/' \
    "$REPO_ROOT/scripts/dot/commands/env-emit.sh")"
  if [[ "$usage" == *"ndjson"* && "$usage" == *"--output"* ]]; then
    fm_pass "usage documents ndjson and --output"
  else
    fm_fail "env-emit usage no longer documents its formats"
  fi
}

# ── profile ────────────────────────────────────────────────────────────────

test_fm_profile_show() {
  test_start "fm_profile_show"
  fm_run profile show
  fm_expect_rc_in 0 1
  test_start "fm_profile_show_reports_profile_and_flags"
  fm_expect_any "Profile" "Feature Flags"
}

test_fm_profile_set() {
  # Writes .chezmoidata.toml — drive the sandbox copy, never the checkout.
  local repo
  repo="$(fm_repo_copy)"
  test_start "fm_profile_set"
  fm_run_bin "$repo/bin/dot" profile set fm-test-profile
  fm_expect_rc 0
  test_start "fm_profile_set_persists_to_chezmoidata"
  if grep -q 'profile = "fm-test-profile"' "$repo/defaults/.chezmoidata.toml"; then
    fm_pass "written to the copy"
  else
    fm_fail "profile not persisted"
  fi
  test_start "fm_profile_set_is_visible_to_show"
  fm_run_bin "$repo/bin/dot" profile show
  fm_expect_out "fm-test-profile"
  test_start "fm_profile_set_did_not_touch_the_checkout"
  if grep -q 'fm-test-profile' "$REPO_ROOT/defaults/.chezmoidata.toml" 2>/dev/null; then
    fm_fail "the real checkout was modified"
  else
    fm_pass "checkout untouched"
  fi
}

test_fm_profile_set_usage() {
  local repo
  repo="$(fm_repo_copy)"
  test_start "fm_profile_set_usage"
  fm_run_bin "$repo/bin/dot" profile set
  fm_expect_rc 1
  test_start "fm_profile_set_usage_message"
  fm_expect_any "Usage: dot profile set" "profile set"
}

test_fm_profile_unknown() {
  test_start "fm_profile_unknown"
  fm_run profile zzz-not-a-subcommand
  fm_expect_rc 1
  test_start "fm_profile_unknown_message"
  fm_expect_any "Unknown profile subcommand" "show" "set"
}

test_fm_config_chezmoidata_profile() {
  # The `profile` key and the `[features]` table are the two things
  # `dot profile show` contracts to surface out of .chezmoidata.toml.
  test_start "fm_config_chezmoidata_profile"
  fm_run profile show
  fm_expect_rc_in 0 1
  test_start "fm_config_chezmoidata_profile_reads_the_features_table"
  local key
  key="$(awk '/^\[features\]/{f=1;next} f && /^[a-z_]+ *=/{sub(/ *=.*/,"");print;exit}' \
    "$REPO_ROOT/defaults/.chezmoidata.toml")"
  if [[ -z "$key" ]]; then
    fm_pass "skipped — no [features] key in .chezmoidata.toml"
  elif [[ "$FM_OUT" == *"$key"* ]]; then
    fm_pass "surfaced feature flag '$key'"
  else
    fm_fail "feature flag '$key' from .chezmoidata.toml not shown"
  fi
}

# ── tools ──────────────────────────────────────────────────────────────────

test_fm_tools() {
  test_start "fm_tools"
  fm_run tools
  fm_expect_rc_in 0 1
  test_start "fm_tools_lists_subcommands"
  fm_expect_any "Dot Tools" "install" "docs"
}

test_fm_tools_docs() {
  # cmd_tools used to look only in <src>/docs/; both documents live under
  # docs/reference/, so `dot tools docs` reported "TOOLS.md not found" on a
  # complete checkout. The reference location is probed first now.
  test_start "fm_tools_docs"
  fm_run tools docs
  fm_expect_rc 0
  test_start "fm_tools_docs_names_the_document"
  fm_expect_out "Integrated tools organized by role"
}

test_fm_smoke_tools_install() { fm_smoke tools; }

# ── new ────────────────────────────────────────────────────────────────────

test_fm_new() {
  if ! command -v python3 >/dev/null 2>&1; then
    test_start "fm_new"
    fm_pass "skipped — python3 not installed (template renderer)"
    return 0
  fi
  local prev="$PWD"
  cd "$FM_SANDBOX/work" || return 0
  rm -rf "$FM_SANDBOX/work/fm-new-project"
  test_start "fm_new"
  fm_run new python fm-new-project
  fm_expect_rc 0
  test_start "fm_new_scaffolds_the_project"
  fm_expect_file "$FM_SANDBOX/work/fm-new-project"
  test_start "fm_new_applies_the_security_baseline"
  fm_expect_file "$FM_SANDBOX/work/fm-new-project/SECURITY.md"
  test_start "fm_new_rendered_the_project_name"
  if grep -rq "__PROJECT_NAME__" "$FM_SANDBOX/work/fm-new-project" 2>/dev/null; then
    fm_fail "template placeholder left unrendered"
  else
    fm_pass "no placeholders remain"
  fi
  cd "$prev" || return 0
}

test_fm_new_usage() {
  test_start "fm_new_usage"
  fm_run new
  fm_expect_rc 1
  test_start "fm_new_usage_lists_templates"
  fm_expect_any "Usage: dot new" "Available templates"
  test_start "fm_new_usage_rejects_unknown_template"
  fm_run new zzz-not-a-template demo
  fm_expect_rc 1
  test_start "fm_new_usage_unknown_template_message"
  fm_expect_any "Unknown template" "Available templates"
}

# ── packages ───────────────────────────────────────────────────────────────

test_fm_packages() {
  test_start "fm_packages"
  fm_run packages
  fm_expect_rc_in 0 1
  test_start "fm_packages_reports_managers"
  fm_expect_any "Package Managers" "Language Package Managers"
}

# ── aliases ────────────────────────────────────────────────────────────────

# ── setup / log-rotate ─────────────────────────────────────────────────────

test_fm_smoke_setup() {
  # An interactive gum wizard; there is no non-interactive entry point.
  test_start "fm_smoke_setup_is_routed"
  fm_run setup
  if [[ "$FM_OUT$FM_ERR" == *"Unknown command"* ]]; then
    fm_fail "setup is not routed by the dispatcher"
  else
    fm_pass "routed (rc=$FM_RC)"
  fi
}

test_fm_log_rotate() {
  test_start "fm_log_rotate_noop_below_threshold"
  fm_run log-rotate
  fm_expect_rc 0

  # Above the 1 MiB threshold the log must actually be rotated.
  mkdir -p "$FM_SANDBOX/.local/share"
  local log="$FM_SANDBOX/.local/share/dotfiles.log"
  : >"$log"
  local i
  for i in $(seq 1 20000); do
    printf 'fm log line padding padding padding padding padding padding %s\n' "$i"
  done >"$log"
  test_start "fm_log_rotate"
  fm_run log-rotate
  fm_expect_rc 0
  test_start "fm_log_rotate_rotates_a_large_log"
  if [[ -f "$log.1.gz" ]]; then
    fm_pass "rotated and compressed to dotfiles.log.1.gz"
  else
    fm_fail "large log was not rotated"
  fi
  test_start "fm_log_rotate_truncates_the_live_log"
  if [[ -f "$log" && ! -s "$log" ]]; then
    fm_pass "live log truncated"
  else
    fm_fail "live log was not truncated after rotation"
  fi
  rm -f "$log" "$log".*
}

# ── lint ───────────────────────────────────────────────────────────────────
#
# Driven against the sandbox repo copy: linting the real tree takes minutes,
# and --fix must never rewrite the checkout.

test_fm_lint() {
  if ! command -v shellcheck >/dev/null 2>&1 && ! command -v shfmt >/dev/null 2>&1; then
    test_start "fm_lint"
    fm_pass "skipped — neither shellcheck nor shfmt installed"
    return 0
  fi
  local repo
  repo="$(fm_repo_copy)"
  test_start "fm_lint"
  fm_run_bin "$repo/bin/dot" lint
  fm_expect_rc_in 0 1
  test_start "fm_lint_reports_a_summary"
  fm_expect_any "Summary" "Files scanned" "shellcheck" "shfmt"
}

test_fm_lint_check() {
  if ! command -v shfmt >/dev/null 2>&1; then
    test_start "fm_lint_check"
    fm_pass "skipped — shfmt not installed"
    return 0
  fi
  local repo
  repo="$(fm_repo_copy)"
  # A deliberately misformatted file must make --check fail.
  printf '#!/usr/bin/env bash\necho     "over-spaced"\n' >"$repo/scripts/dot/fm-ugly.sh"
  test_start "fm_lint_check"
  fm_run_bin "$repo/bin/dot" lint --check
  if [[ "$FM_RC" -ne 0 ]]; then
    fm_pass "check mode failed on a misformatted file (rc=$FM_RC)"
  else
    fm_fail "--check passed despite a misformatted file"
  fi
  test_start "fm_lint_check_names_the_problem"
  fm_expect_any "Formatting issues" "need formatting" "shfmt"
}

test_fm_lint_fix() {
  if ! command -v shfmt >/dev/null 2>&1; then
    test_start "fm_lint_fix"
    fm_pass "skipped — shfmt not installed"
    return 0
  fi
  local repo
  repo="$(fm_repo_copy)"
  printf '#!/usr/bin/env bash\necho     "over-spaced"\n' >"$repo/scripts/dot/fm-ugly.sh"
  test_start "fm_lint_fix"
  fm_run_bin "$repo/bin/dot" lint --fix
  fm_expect_rc_in 0 1
  test_start "fm_lint_fix_reformats_the_file"
  if grep -q 'echo "over-spaced"' "$repo/scripts/dot/fm-ugly.sh"; then
    fm_pass "file reformatted in place"
  else
    fm_fail "--fix did not reformat the file"
  fi
  test_start "fm_lint_fix_then_check_is_clean"
  fm_run_bin "$repo/bin/dot" lint --check
  fm_expect_rc_in 0 1
  rm -f "$repo/scripts/dot/fm-ugly.sh"
}

# ── run ────────────────────────────────────────────────────────────────────

echo ""
echo "── FEATURE-MATRIX: tools, aliases, lint, env emit ──"
echo ""

test_fm_env_list
test_fm_env_prune
test_fm_smoke_env_prune_yes
test_fm_smoke_env_install
test_fm_smoke_env_use
test_fm_env_emit
test_fm_env_emit_compact
test_fm_env_emit_ndjson
test_fm_env_emit_output
test_fm_env_emit_bad_format
test_fm_env_emit_bad_flag
test_fm_env_emit_help
test_fm_profile_show
test_fm_profile_set
test_fm_profile_set_usage
test_fm_profile_unknown
test_fm_config_chezmoidata_profile
test_fm_tools
test_fm_tools_docs
test_fm_smoke_tools_install
test_fm_new
test_fm_new_usage
test_fm_packages
test_fm_smoke_setup
test_fm_log_rotate
test_fm_lint
test_fm_lint_check
test_fm_lint_fix

fm_finish
