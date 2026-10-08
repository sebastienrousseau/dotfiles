#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016,SC2034
# AI CLIs install at the versions pinned in [ai_tools] in .chezmoidata.toml,
# never @latest: `dot ai install` (ai_install_tool) reads the pin at run
# time, a package with no pin is refused, and `dot upgrade` lists newer
# releases as bumps to review instead of moving the pins itself.
#
# mise is a stub that records its calls and answers `mise latest`.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d -t ai-pins.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"
CALLS="$WORK/calls.log"
cat >"$WORK/bin/mise" <<EOF
#!/bin/sh
echo "mise \$*" >>"$CALLS"
if [ "\$1" = latest ]; then
  case "\$2" in
    npm:@openai/codex) echo 9.9.9 ;;
    *) echo "\${MISE_SAME:-}" ;;
  esac
fi
exit 0
EOF
chmod +x "$WORK/bin/mise"

# lib <snippet>: run <snippet> with the AI libraries loaded; prints output
# and then rc=<status>.
lib() {
  local rc=0 out
  : >"$CALLS"
  out="$(env -i HOME="$WORK" PATH="$WORK/bin:/usr/bin:/bin" NO_COLOR=1 MISE_SAME="${MISE_SAME:-}" \
    bash -c 'source "$1/lib/dot/ui.sh"; source "$1/lib/dot/utils.sh"
      '"$1" _ "$REPO_ROOT" 2>&1)" || rc=$?
  printf '%s\nrc=%s\n' "$out" "$rc"
}
rc_of() { sed -n 's/^rc=//p' <<<"$1" | tail -n 1; }

test_start "pinned_version_read_from_data"
assert_equals "0.159.3" "$(lib '_ai_pinned_version npm:@openai/codex' | head -n 1)" \
  "the [ai_tools] pin for codex is read at run time"

test_start "pinned_version_ignores_package_options"
assert_equals "0.86.2" "$(lib '_ai_pinned_version "pipx:aider-chat[uvx_args=--python 3.12]"' | head -n 1)" \
  "mise package options are not part of the pin key"

test_start "pinned_version_only_from_ai_tools_table"
assert_equals "" "$(lib '_ai_pinned_version gopls' | head -n 1)" \
  "keys of other tables are not AI pins"

test_start "every_mapped_provider_is_pinned"
r="$(lib 'for b in codex copilot crush aider opencode sgpt ollama kiro-cli autohand qwen zai; do
  p="$(_ai_mise_pkg "$b")"; [[ -n "$(_ai_pinned_version "$p")" ]] || printf "%s " "$b"; done')"
assert_equals "" "$(head -n 1 <<<"$r")" "every provider dot ai can install has a pin"

test_start "vibe_is_not_installable"
assert_equals "" "$(lib '_ai_mise_pkg vibe' | head -n 1)" "mistral-vibe is no longer offered (quarantined dependency)"

test_start "install_uses_the_pin"
r="$(lib 'ai_install_tool codex Codex')"
assert_equals "0|mise use -g npm:@openai/codex@0.159.3" "$(rc_of "$r")|$(cat "$CALLS")" \
  "dot ai install runs mise use at the pinned version"

test_start "unpinned_package_refused"
r="$(lib 'ai_pinned_spec npm:not-pinned')"
assert_equals "1|" "$(rc_of "$r")|$(head -n 1 <<<"$r" | grep -o '@.*' || true)" \
  "a package without a pin yields no install spec"

test_start "upgrade_proposes_bumps"
r="$(lib 'ai_pin_bumps')"
assert_contains "npm:@openai/codex 0.159.3 -> 9.9.9" "$r" "a newer release is listed as a bump"

test_start "upgrade_bumps_leave_pins_alone"
assert_equals "0" "$(grep -c '^mise use' "$CALLS")" "listing bumps installs nothing"

test_start "upgrade_no_bump_when_current"
r="$(MISE_SAME=0.86.2 lib 'ai_pin_bumps')"
assert_equals "0" "$(grep -c 'pipx:aider-chat' <<<"$r")" "a tool already at its newest release is not listed"

print_summary
