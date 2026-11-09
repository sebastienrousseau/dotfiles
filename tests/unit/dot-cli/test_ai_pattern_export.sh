#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Behaviour tests for `dot ai pattern export --hc` (plugins/ai/libexec/
# patterns.sh, plan P0.5): each prompt pattern becomes a herdr-core
# template in $XDG_CONFIG_HOME/herdr-core/templates, and the templates
# chezmoi deploys from defaults/dot_config/herdr-core/templates render to
# the same bytes as the export.
#
# AUTO-GENERATED: false (hand-written)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

exec 21>&2
export BASH_XTRACEFD=21

PATTERNS="$REPO_ROOT/plugins/ai/libexec/patterns.sh"
DOT_AI="$REPO_ROOT/plugins/ai/dot-ai"
SHIPPED="$REPO_ROOT/defaults/dot_config/ai/patterns"
DEPLOYED="$REPO_ROOT/defaults/dot_config/herdr-core/templates"

# The real chezmoi, found before the sandbox puts its stub first on PATH.
CHEZMOI="$(command -v chezmoi || true)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

PATTERN_DIR="$XDG_CONFIG_HOME/ai/patterns"
OUT="$XDG_CONFIG_HOME/herdr-core/templates"
mkdir -p "$PATTERN_DIR"
printf '# Identity: Dotfiles Architect\n\nThink in systems.\n' >"$PATTERN_DIR/architect.md"
printf '# Hardener\n\nTrust nothing.\n' >"$PATTERN_DIR/hardener.md"

_run() { bash "$PATTERNS" "$@" 2>&1; }

test_start "export_hc_writes_every_pattern_as_a_template"
rm -rf "$OUT"
_out="$(_run export --hc)"
assert_equals 0 "$?" "export --hc exits 0"
assert_equals $'---\ndescription: Dotfiles Architect\ncommand: claude\n---\n# Identity: Dotfiles Architect\n\nThink in systems.' \
  "$(cat "$OUT/architect.md")" "front matter, then the pattern, the Identity: prefix dropped"
assert_equals $'---\ndescription: Hardener\ncommand: claude\n---\n# Hardener\n\nTrust nothing.' \
  "$(cat "$OUT/hardener.md")" "a plain heading is the description"
assert_contains "hc run architect" "$_out" "says how to run it"

test_start "export_hc_agent_without_hooks_waits_quietly"
_out="$(_run export --hc --agent aider hardener)"
assert_equals 0 "$?" "export --agent exits 0"
assert_equals $'---\ndescription: Hardener\ncommand: aider\nready: quiet\n---' \
  "$(head -5 "$OUT/hardener.md")" "an agent that does not report waits for quiet"
_out="$(_run export --hc --agent codex hardener)"
assert_equals "command: codex" "$(sed -n 3p "$OUT/hardener.md")" "codex runs it"
assert_equals "---" "$(sed -n 4p "$OUT/hardener.md")" "codex reports, so no ready line"
_out="$(_run export --hc --agent gemini)"
assert_equals "0" "$?" "--agent with no names after it exports them all"
assert_equals "command: gemini|command: gemini" "$(sed -n 3p "$OUT/architect.md")|$(sed -n 3p "$OUT/hardener.md")" "with that agent"

test_start "export_hc_names_only_the_patterns_asked_for"
rm -rf "$OUT"
_out="$(_run export --hc hardener)"
assert_file_exists "$OUT/hardener.md" "the named pattern is written"
assert_file_not_exists "$OUT/architect.md" "no other"

test_start "export_hc_reports_an_unknown_pattern"
_out="$(_run export --hc nope)"
assert_equals 1 "$?" "an unknown pattern exits 1"
assert_contains "Pattern not found" "$_out" "and says so"
assert_file_not_exists "$OUT/nope.md" "nothing written for it"

test_start "export_without_hc_or_with_a_bad_option_is_a_usage_error"
_out="$(_run export)"
assert_equals 1 "$?" "export alone exits 1"
assert_contains "dot ai pattern export --hc [--agent AGENT]" "$_out" "usage printed"
_out="$(_run export --hc --bogus)"
assert_equals 1 "$?" "an unknown option exits 1"
_out="$(_run export --hc --agent)"
assert_equals 1 "$?" "--agent without a name exits 1"

test_start "dot_ai_routes_pattern_export"
rm -rf "$OUT"
_out="$(bash "$DOT_AI" pattern export --hc architect 2>&1)"
assert_equals 0 "$?" "dot ai pattern export exits 0"
assert_file_exists "$OUT/architect.md" "dot ai pattern export wrote the template"

test_start "every_shipped_pattern_has_a_deployed_template"
_names() { # DIR SUFFIX: the files' names without it
  local f
  for f in "$1"/*"$2"; do
    f="${f##*/}"
    echo "${f%"$2"}"
  done
}
_want="$(_names "$SHIPPED" .md)"
_have="$(_names "$DEPLOYED" .md.tmpl)"
assert_equals "$_want" "$_have" "templates match patterns one to one"

test_start "deployed_templates_render_as_the_export_writes_them"
if [[ -z "$CHEZMOI" ]]; then
  echo "  chezmoi unavailable: render parity skipped"
else
  rm -rf "$PATTERN_DIR" "$OUT"
  cp -R "$SHIPPED" "$PATTERN_DIR"
  _run export --hc >/dev/null
  : >"$DOTFILES_COV_TMPDIR/chezmoi.toml"
  for _t in "$DEPLOYED"/*.md.tmpl; do
    _n="$(basename "$_t" .md.tmpl)"
    _render="$("$CHEZMOI" execute-template --config "$DOTFILES_COV_TMPDIR/chezmoi.toml" \
      --source "$REPO_ROOT" <"$_t" 2>&1)"
    assert_equals "$(cat "$OUT/$_n.md")" "$_render" "$_n renders as the export writes it"
  done
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
