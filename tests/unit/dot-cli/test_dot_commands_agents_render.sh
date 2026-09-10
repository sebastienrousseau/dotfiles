#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Behaviour tests for `dot agents` (scripts/dot/commands/agents.sh):
# list, check (missing CLAUDE.md, missing AGENTS.md, in sync, drifted),
# render (all eleven harness targets, and that a render makes check
# pass), help and the unknown-subcommand error.
#
# Every case runs against a throwaway "repo" whose root the command
# discovers through a `chezmoi source-path` shim, so `render` writes
# AGENTS.md, .cursor/, .codex/ and friends into the sandbox — never
# into this checkout. The repo-root guard is exercised too: a
# candidate without .chezmoidata.toml must be rejected.
#
# AUTO-GENERATED: false (hand-written)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# Hand children a copy of the real stderr so their xtrace still reaches
# the coverage runner even though the probes capture output with 2>&1.
exec 21>&2
export BASH_XTRACEFD=21

DOT_BIN="$REPO_ROOT/bin/dot"
BASH_BIN="$(command -v bash)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

CLAUDE_BODY='## Conventions

- Two-space indent.
- Conventional commits.
'

# _repo <name> [--no-data] [--no-claude] — a fake repo root; prints it.
_repo() {
  local name="$1"
  local root="$DOTFILES_COV_TMPDIR/repos/$name"
  shift
  mkdir -p "$root"
  local with_data=1 with_claude=1
  local opt
  for opt in "$@"; do
    case "$opt" in
      --no-data) with_data=0 ;;
      --no-claude) with_claude=0 ;;
    esac
  done
  ((with_data)) && printf 'dotfiles_version = "1.0.0"\n' >"$root/.chezmoidata.toml"
  if ((with_claude)); then
    printf '# CLAUDE.md — Project guide\n\n%s' "$CLAUDE_BODY" >"$root/CLAUDE.md"
  fi
  printf '%s\n' "$root"
}

# _shim_root <root> — a bin dir whose `chezmoi source-path` answers
# <root>; prints the bin dir.
_shim_root() {
  local root="$1"
  local dir
  dir="$DOTFILES_COV_TMPDIR/shims/$(basename "$root")"
  mkdir -p "$dir"
  cat >"$dir/chezmoi" <<EOF
#!/usr/bin/env bash
[[ "\${1:-}" == "source-path" ]] && echo "$root"
exit 0
EOF
  chmod +x "$dir/chezmoi"
  printf '%s\n' "$dir"
}

_agents() { # <bin-dir> [args…]
  local dir="$1"
  shift
  PATH="$dir:$PATH" "$BASH_BIN" "$DOT_BIN" agents "$@" 2>&1
}

# ── list ─────────────────────────────────────────────────────────────
test_start "agents_list_shows_every_harness_and_its_render_state"
_root="$(_repo list)"
_bin="$(_shim_root "$_root")"
_out="$(_agents "$_bin" list)"
_rc=$?
assert_equals 0 "$_rc" "list exits 0"
assert_contains "Agent harness targets" "$_out" "header printed"
assert_contains "$_root/AGENTS.md" "$_out" "agents-md target resolved under the fixture root"
assert_contains "not yet rendered" "$_out" "unrendered targets are flagged"
for _h in agents-md cursor codex windsurf zed roo cline aider continue jules; do
  assert_contains "$_h" "$_out" "harness $_h listed"
done

test_start "agents_defaults_to_list"
_out="$(_agents "$_bin")"
assert_equals 0 "$?" "no subcommand exits 0"
assert_contains "Agent harness targets" "$_out" "bare invocation lists targets"

# ── check ────────────────────────────────────────────────────────────
test_start "agents_check_requires_claude_md"
_root="$(_repo nocanon --no-claude)"
_bin="$(_shim_root "$_root")"
_out="$(_agents "$_bin" check)"
_rc=$?
assert_equals 2 "$_rc" "missing CLAUDE.md exits 2"
assert_contains "not found at $_root/CLAUDE.md" "$_out" "the expected path is named"

test_start "agents_check_reports_a_missing_agents_md"
_root="$(_repo unrendered)"
_bin="$(_shim_root "$_root")"
_out="$(_agents "$_bin" check)"
_rc=$?
assert_equals 1 "$_rc" "missing AGENTS.md exits 1"
assert_contains "run 'dot agents render'" "$_out" "the fix is suggested"

# ── render ───────────────────────────────────────────────────────────
test_start "agents_render_writes_every_harness_file"
_root="$(_repo rendered)"
_bin="$(_shim_root "$_root")"
_out="$(_agents "$_bin" render)"
_rc=$?
assert_equals 0 "$_rc" "render exits 0"
for _f in AGENTS.md .cursor/rules/dotfiles.mdc .codex/config.toml \
  .windsurf/rules.md .zed/agent-config.toml .roo/rules.md .clinerules \
  .aider.conf.yml .continuerc.json .jules/system.md .agy/AGY.md; do
  assert_file_exists "$_root/$_f" "render wrote $_f"
done
assert_contains "rendered → $_root/AGENTS.md" "$_out" "AGENTS.md render reported"

test_start "agents_render_propagates_the_claude_body"
# Regression: render used to pipe the body through
# `sed '1s/^# CLAUDE\.md.*/# AGENTS.md — AI Assistant Guidelines/'`, but
# `_agents_body` drops the H1 by design, so line 1 was never the CLAUDE.md
# title, the substitution never fired, and the rendered file carried no title
# at all. The title is printed directly now.
assert_file_contains "$_root/AGENTS.md" "# AGENTS.md — AI Assistant Guidelines" \
  "the rendered file declares its own title"
test_start "agents_render_puts_the_title_before_the_body"
_title_line="$(grep -n '^# AGENTS\.md' "$_root/AGENTS.md" | head -1 | cut -d: -f1)"
_body_line="$(grep -n '^## Conventions' "$_root/AGENTS.md" | head -1 | cut -d: -f1)"
if [[ -n "$_title_line" && -n "$_body_line" && "$_title_line" -lt "$_body_line" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (title on line $_title_line)"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: title=$_title_line body=$_body_line"
fi
test_start "agents_render_propagates_the_claude_body"
assert_file_contains "$_root/AGENTS.md" "## Conventions" "the first body heading survives"
assert_file_contains "$_root/AGENTS.md" "Conventional commits." "the CLAUDE.md body is carried over"
assert_file_contains "$_root/AGENTS.md" "Canonical source: CLAUDE.md" "the do-not-edit header is present"
assert_file_contains "$_root/.windsurf/rules.md" "Conventional commits." "the same body reaches per-harness files"
assert_file_contains "$_root/.zed/agent-config.toml" 'agent_context = "AGENTS.md"' "Zed gets a pointer, not a copy"
assert_file_contains "$_root/.aider.conf.yml" "AGENTS.md" "Aider config points at the bundle"
assert_file_contains "$_root/.continuerc.json" "systemMessage" "Continue pointer written as JSON"

test_start "agents_check_passes_immediately_after_a_render"
_out="$(_agents "$_bin" check)"
_rc=$?
assert_equals 0 "$_rc" "a freshly rendered tree is in sync"
assert_contains "in sync with CLAUDE.md" "$_out" "sync is reported"

test_start "agents_check_is_insensitive_to_blank_line_differences"
# `render` writes one more blank line after its header block than
# CLAUDE.md carries, so the two extracted bodies ALWAYS differ by a
# blank line — the whole verdict rests on that being ignored. Adding
# more blank lines must not manufacture drift either. (macOS 14's diff
# drops --ignore-blank-lines under -q, which made every freshly
# rendered tree look drifted there.)
printf '\n\n' >>"$_root/AGENTS.md"
_out="$(_agents "$_bin" check)"
_rc=$?
assert_equals 0 "$_rc" "extra blank lines are not drift"
assert_contains "in sync with CLAUDE.md" "$_out" "still reported as in sync"

test_start "agents_check_detects_drift"
printf '\n- A rule added only to CLAUDE.md.\n' >>"$_root/CLAUDE.md"
_out="$(_agents "$_bin" check)"
_rc=$?
assert_equals 1 "$_rc" "drift exits 1"
assert_contains "drifted from CLAUDE.md" "$_out" "drift is reported"
_out="$(_agents "$_bin" render)"
_out="$(_agents "$_bin" check)"
assert_equals 0 "$?" "re-rendering clears the drift"

test_start "agents_list_marks_rendered_targets"
_out="$(_agents "$_bin" list)"
assert_contains "rendered" "$_out" "rendered state is shown after a render"

# ── guard, help and unknown subcommands ──────────────────────────────
test_start "agents_refuses_a_root_without_chezmoidata"
_root="$(_repo foreign --no-data)"
_bin="$(_shim_root "$_root")"
_out="$(cd "$_root" && PATH="$_bin:$PATH" "$BASH_BIN" "$DOT_BIN" agents check 2>&1)"
_rc=$?
assert_not_equals 0 "$_rc" "a checkout that is not the dotfiles repo is refused"
assert_file_not_exists "$_root/AGENTS.md" "and nothing is written into it"

test_start "agents_help"
_root="$(_repo helpdir)"
_bin="$(_shim_root "$_root")"
# `dot agents -h`/`--help` is intercepted by the CLI's own help
# registry; `dot agents help` reaches the command's usage text.
_out="$(_agents "$_bin" help)"
_rc=$?
assert_equals 0 "$_rc" "help exits 0"
assert_contains "Usage: dot agents <subcommand>" "$_out" "usage printed"
assert_contains "render   Regenerate AGENTS.md" "$_out" "render documented"

test_start "agents_unknown_subcommand_fails"
_out="$(_agents "$_bin" bogus)"
_rc=$?
assert_equals 1 "$_rc" "unknown subcommand exits 1"
assert_contains "Unknown subcommand" "$_out" "the error names the problem"
assert_contains "dot agents --help" "$_out" "and points at the help"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
