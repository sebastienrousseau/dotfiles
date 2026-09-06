#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural coverage for the `a2a-card`, `conformance` and unknown-command
# arms of scripts/dot/commands/agent.sh (`cmd_mode`), driven through the real
# dispatcher (`meta.sh agent …`) inside the coverage sandbox. Split from
# test_dot_agent_dispatch.sh to stay inside the coverage runner's 60s
# per-file budget.
#
# Child stderr is captured to a file and replayed to our own stderr so the
# xtrace records the coverage runner relies on are not swallowed.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

META="$REPO_ROOT/scripts/dot/commands/meta.sh"
AGENT_MODULE="$REPO_ROOT/scripts/dot/commands/agent.sh"
REAL_PROFILES="$REPO_ROOT/defaults/dot_config/dotfiles/agent-profiles.json"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

STATE_DIR="$XDG_STATE_HOME/dotfiles"
CHECKPOINT_DIR="$STATE_DIR/checkpoints"
SESSIONS="$STATE_DIR/agent-sessions.jsonl"

# `timeout` (used by `agent delegate`) is coreutils-only on macOS; shim it so
# the delegate arm is deterministic on every platform.
cat >"$DOTFILES_COV_TMPDIR/bin/timeout" <<'EOF'
#!/usr/bin/env bash
shift
exec "$@"
EOF
chmod +x "$DOTFILES_COV_TMPDIR/bin/timeout"

# run_cmd <cmd…> — sets OUT / ERR / RC. stderr is replayed (xtrace-safe).
run_cmd() {
  local errf="$DOTFILES_COV_TMPDIR/stderr.$$"
  OUT="$("$@" 2>"$errf" </dev/null)"
  RC=$?
  ERR="$(grep -v '^+*@COV@' "$errf" 2>/dev/null || true)"
  [[ "${DOTFILES_COV_ECHO_STDERR:-0}" == "1" ]] && cat "$errf" >&2
  rm -f "$errf"
  return 0
}

meta() { run_cmd bash "$META" "$@"; }

# ── a2a-card (real card) ────────────────────────────────────────────────
test_start "a2a_card_renders_summary"
meta agent a2a-card
assert_equals 0 "$RC" "rc"
assert_contains "A2A v0.3 Agent Card" "$OUT" "header"
assert_contains "Skills" "$OUT" "skills row"

test_start "a2a_card_json"
meta agent a2a-card --json
assert_equals 0 "$RC" "rc"
assert_equals "0.3" "$(printf '%s' "$OUT" | jq -r .specVersion)" "raw card"

test_start "a2a_card_validate_shipped_card_passes"
meta agent a2a-card --validate ignored-positional
assert_equals 0 "$RC" "rc"
assert_contains "specVersion" "$OUT" "validation rows"

# ── a2a-card (broken card via a fake repo root) ─────────────────────────
# resolve_source_dir() derives the repo root from lib/dot's own location, so
# a fake root that symlinks lib/ + scripts/dot/ back to the repo lets us
# swap in a deliberately broken .well-known/agent-card.json.
#
# The fake root deliberately lives OUTSIDE the sandbox tmpdir: the coverage
# aggregator resolves each traced BASH_SOURCE path after the test exits, and
# a fake root torn down with the sandbox would leave those records pointing
# at a dangling path, so the lines executed through it would not be counted.
# The fixed name is wiped on entry, so at most one such tree ever exists.
FAKE="${TMPDIR:-/tmp}/dotfiles-cov-agent-fakeroot"
rm -rf "$FAKE"
mkdir -p "$FAKE/scripts/diagnostics" "$FAKE/.well-known"
ln -s "$REPO_ROOT/lib" "$FAKE/lib"
ln -s "$REPO_ROOT/scripts/dot" "$FAKE/scripts/dot"
cat >"$FAKE/scripts/diagnostics/a2a-conformance.sh" <<'EOF'
#!/usr/bin/env bash
echo "stub-conformance $*"
EOF
chmod +x "$FAKE/scripts/diagnostics/a2a-conformance.sh"
FAKE_META="$FAKE/scripts/dot/commands/meta.sh"
fmeta() { AGENT_PROFILE_CONFIG="$REAL_PROFILES" run_cmd bash "$FAKE_META" "$@"; }

test_start "a2a_card_validate_invalid_json_exits_1"
printf '{oops' >"$FAKE/.well-known/agent-card.json"
fmeta agent a2a-card --strict
assert_equals 1 "$RC" "rc"
assert_contains "invalid" "$OUT" "JSON invalid row"

test_start "a2a_card_validate_reports_every_missing_field"
printf '{"specVersion":"0.2","skills":[]}' >"$FAKE/.well-known/agent-card.json"
fmeta agent a2a-card -s
assert_equals 1 "$RC" "strict exit"
assert_contains "expected 0.3, got 0.2" "$OUT" "specVersion"
assert_contains "missing or empty" "$OUT" "skills"
assert_contains "authentication" "$OUT" "authentication row"
assert_contains "missing method" "$OUT" "signing"

test_start "a2a_card_missing_file"
rm -f "$FAKE/.well-known/agent-card.json"
fmeta agent a2a-card
assert_equals 1 "$RC" "rc"
assert_contains "A2A v0.3 card not found" "$ERR" "error"

test_start "conformance_execs_script_with_args"
fmeta agent conformance --json
assert_equals 0 "$RC" "rc"
assert_contains "stub-conformance --json" "$OUT" "args forwarded"

# ── unknown ─────────────────────────────────────────────────────────────
test_start "mode_unknown_subcommand"
meta mode bogus
assert_equals 1 "$RC" "rc"
assert_contains "Usage: dot mode [list|current" "$ERR" "usage"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
