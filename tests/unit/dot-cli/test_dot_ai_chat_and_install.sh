#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# `dot ai chat`, `dot ai install` and `dot ai serve`.
#
# These three route through lib/dot/ai-commands.sh, and each ends in an exec
# or an installer — so no suite had run them: chat would replace the test
# process with a real CLI, install would reach for mise, serve would start a
# proxy. Every one of those is a stub here, on a PATH that carries nothing
# else, against the fixture source tree.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"
source "$SCRIPT_DIR/../../framework/module_fixture.sh"

cov_setup_sandbox
trap cov_teardown_sandbox EXIT

FX="$(dot_fixture_new ai-chat)"
mkdir -p "$FX/home" "$FX/stubs"
dot_fixture_basebin "$FX/basebin"
DOT_FIXTURE_HOME="$FX/home"

ai_run() {
  DOT_FIXTURE_PATH="$FX/stubs:$FX/basebin" dot_fixture_run "$FX" ai "$@"
}

# ── 1. chat resolves a tool's short name to its binary ─────────────────────
test_start "ai_chat_reports_an_uninstalled_tool"
ai_run ai chat cl
assert_equals "1" "$DOT_FIXTURE_RC" "chatting to a missing tool should exit 1"
assert_contains "not installed" "$DOT_FIXTURE_OUT" "the failure should say so"

test_start "ai_chat_execs_the_resolved_binary"
dot_fixture_stub "$FX/stubs" claude 0
ai_run ai chat cl
assert_equals "0" "$DOT_FIXTURE_RC" "an installed tool should be launched"
assert_contains "claude" "$DOT_FIXTURE_OUT" \
  "the short name 'cl' should resolve to the claude binary"

test_start "ai_chat_resolves_kiro_to_kiro_cli"
dot_fixture_stub "$FX/stubs" kiro-cli 0
ai_run ai chat kiro
assert_equals "0" "$DOT_FIXTURE_RC" "kiro should resolve to kiro-cli"
assert_contains "kiro-cli" "$DOT_FIXTURE_OUT" \
  "the short name 'kiro' should resolve to the kiro-cli binary"

# ── 2. install survives a failing package manager ──────────────────────────
test_start "ai_install_continues_past_a_failed_install"
dot_fixture_stub "$FX/stubs" mise 1
ai_run ai install codex
assert_contains "install failed" "$DOT_FIXTURE_OUT" \
  "a failing install should be reported without aborting the run"
assert_equals "1" "$DOT_FIXTURE_RC" "a failed install must not end in success"
assert_contains "1 tool(s) not installed" "$DOT_FIXTURE_OUT" "the failure count is reported"

test_start "ai_install_reports_a_missing_package_manager"
rm -f "$FX/stubs/mise"
ai_run ai install codex
assert_contains "not installed" "$DOT_FIXTURE_OUT" \
  "with no mise at all the missing prerequisite should be named"
assert_contains "mise" "$DOT_FIXTURE_OUT" "the prerequisite is mise"
assert_equals "1" "$DOT_FIXTURE_RC" "nothing could be installed"

test_start "ai_install_yes_installs_mise_then_the_tool"
# --yes consents to the prerequisite: mise comes from Homebrew, then the tool.
# The brew stub "installs" mise by copying a logging mise stub into place.
cat >"$FX/mise-stub" <<'EOF'
#!/usr/bin/env bash
printf 'mise %s\n' "$*" >>"$MISE_LOG"
EOF
cat >"$FX/stubs/brew" <<'EOF'
#!/usr/bin/env bash
printf 'brew %s\n' "$*" >>"$BREW_LOG"
cp "$MISE_STUB" "$STUB_DIR/mise" && chmod +x "$STUB_DIR/mise"
EOF
chmod +x "$FX/stubs/brew"
export BREW_LOG="$FX/brew.log" MISE_LOG="$FX/mise.log" MISE_STUB="$FX/mise-stub" STUB_DIR="$FX/stubs"
ai_run ai install codex --yes
assert_contains "brew install mise" "$(cat "$FX/brew.log" 2>/dev/null)" "mise is installed with consent"
assert_contains "mise use -g npm:@openai/codex@0.159.3" "$(cat "$FX/mise.log" 2>/dev/null)" \
  "then the tool installs through it"
assert_equals "0" "$DOT_FIXTURE_RC" "the install succeeds"
rm -f "$FX/stubs/brew" "$FX/stubs/mise"
unset BREW_LOG MISE_LOG MISE_STUB STUB_DIR

# ── 3. serve delegates to the proxy ────────────────────────────────────────
test_start "ai_serve_requires_the_proxy"
ai_run ai serve
assert_equals "1" "$DOT_FIXTURE_RC" "serve without the proxy should exit 1"
assert_contains "not found" "$DOT_FIXTURE_OUT" "the failure should name it"

test_start "ai_serve_hands_over_to_the_proxy"
dot_fixture_stub "$FX/stubs" dot-ai-proxy 0
ai_run ai serve status
assert_equals "0" "$DOT_FIXTURE_RC" "serve status should exit 0"
assert_contains "dot-ai-proxy status" "$DOT_FIXTURE_OUT" \
  "the subcommand should be passed through to the proxy"

print_summary
