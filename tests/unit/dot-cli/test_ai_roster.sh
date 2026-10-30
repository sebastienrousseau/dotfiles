#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016,SC2034
#
# The AI roster (plugins/ai/roster.toml) is the only list of AI tools; every
# other list is generated from it by tools/docs/gen_roster.py. This checks
# that the generated files are current, that the generator refuses a bad
# roster, that the lookups resolve names and aliases, and that every agent
# the roster names can actually be run once and has a way to be installed.
#
# AUTO-GENERATED: false (hand-written)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

GEN="$REPO_ROOT/tools/docs/gen_roster.py"
_rt_tmp="$(mktemp -d -t dotfiles-roster.XXXXXX)"
trap 'rm -rf "$_rt_tmp"' EXIT

# fixture_root: a copy of every file the generator reads or writes.
fixture_root() {
  local root="$_rt_tmp/root.$RANDOM" path
  for path in plugins/ai/roster.toml plugins/ai/roster.json plugins/ai/dot-plugin.toml \
    defaults/.chezmoidata.toml lib/dot/data/ai-roster.sh defaults/dot_local/bin/executable_tmux-ai \
    defaults/dot_local/share/dot-ai-tui/roster_gen.go; do
    mkdir -p "$root/$(dirname "$path")"
    cp "$REPO_ROOT/$path" "$root/$path"
  done
  printf '%s\n' "$root"
}

test_start "roster_generated_files_are_current"
assert_equals "0" "$(python3 "$GEN" --check >/dev/null 2>&1 && echo 0 || echo $?)" "gen_roster.py --check passes on the tree"

test_start "roster_check_fails_when_a_tool_is_added"
root="$(fixture_root)"
printf '\n[[tool]]\nname = "newbot"\nbin = "newbot"\ntitle = "New Bot"\nsummary = "A new agent"\ngroup = "agents"\nrole = "agent"\n' \
  >>"$root/plugins/ai/roster.toml"
rc=0
err="$(python3 "$GEN" --check --root "$root" 2>&1)" || rc=$?
assert_equals "1" "$rc" "--check exits 1 when a generated file is stale"
assert_contains "stale: plugins/ai/dot-plugin.toml" "$err" "the manifest values are named as stale"
python3 "$GEN" --root "$root" >/dev/null
assert_file_contains "$root/defaults/dot_local/bin/executable_tmux-ai" "| zai | newbot)" "tmux-ai launches the new agent"
assert_file_contains "$root/lib/dot/data/ai-roster.sh" "newbot=newbot" "the shell lookups know it"
assert_file_contains "$root/defaults/dot_local/share/dot-ai-tui/roster_gen.go" '{name: "newbot", bin: "newbot", group: "agents"}' "the cockpit lists it"
assert_equals "0" "$(python3 "$GEN" --check --root "$root" >/dev/null 2>&1 && echo 0 || echo $?)" "regenerating clears the drift"

test_start "roster_rejects_an_unpinned_package"
root="$(fixture_root)"
printf '\n[[tool]]\nname = "loose"\nbin = "loose"\ntitle = "Loose"\nsummary = "x"\ngroup = "coding"\nrole = "coding"\npackage = "npm:loose"\n' \
  >>"$root/plugins/ai/roster.toml"
rc=0
err="$(python3 "$GEN" --check --root "$root" 2>&1)" || rc=$?
assert_equals "2" "$rc" "a package with no [ai_tools] pin is refused"
assert_contains "has no pin" "$err" "the error names the missing pin"

test_start "roster_rejects_a_name_used_twice"
root="$(fixture_root)"
printf '\n[[tool]]\nname = "cl"\nbin = "cl"\ntitle = "Clash"\nsummary = "x"\ngroup = "coding"\nrole = "coding"\n' \
  >>"$root/plugins/ai/roster.toml"
rc=0
err="$(python3 "$GEN" --check --root "$root" 2>&1)" || rc=$?
assert_equals "2" "$rc" "a name that is already an alias is refused"
assert_contains "cl names two tools" "$err" "the error names the clash"

test_start "roster_lookups_resolve_names_and_aliases"
source "$REPO_ROOT/lib/dot/ai-roster.sh"
assert_equals "claude" "$(ai_roster_bin cl)" "cl is claude"
assert_equals "kiro-cli" "$(ai_roster_bin kiro)" "kiro runs kiro-cli"
assert_equals "cursor-agent" "$(ai_roster_bin cursor)" "cursor runs cursor-agent"
assert_equals "1" "$(ai_roster_bin nosuchtool >/dev/null && echo 0 || echo 1)" "an unknown name is not in the roster"
assert_equals "pipx:aider-chat[uvx_args=--python 3.12]" "$(ai_roster_package aider)" "a package with = in it survives the lookup"
assert_equals "install_cursor_native" "$(ai_roster_native cursor-agent)" "native installers are looked up by binary"
assert_equals "kiro-cli login" "$(ai_roster_login kiro-cli)" "a tool's login command comes from the roster"
assert_equals "1" "$(ai_roster_login claude >/dev/null && echo 0 || echo 1)" "a tool that signs in on first use has none"

test_start "roster_rejects_a_login_that_is_not_a_string"
root="$(fixture_root)"
printf '\n[[tool]]\nname = "listy"\nbin = "listy"\ntitle = "Listy"\nsummary = "x"\ngroup = "coding"\nrole = "coding"\nlogin = ["listy", "login"]\n' \
  >>"$root/plugins/ai/roster.toml"
rc=0
err="$(python3 "$GEN" --check --root "$root" 2>&1)" || rc=$?
assert_equals "2" "$rc" "a login given as a list is refused"
assert_contains "listy login must be a string" "$err" "the error names the tool"

# Every agent runs once through its own one-shot form: a stub on PATH for
# each binary records that it was called, and an arm missing from
# _ai_invoke_provider fails as "Unsupported tool".
test_start "every_roster_agent_has_a_one_shot_form"
stubs="$_rt_tmp/bin"
mkdir -p "$stubs"
for bin in "${AI_ROSTER_BINS[@]}"; do
  printf '#!/usr/bin/env bash\ncat >/dev/null 2>&1 || true\ntouch "%s/%s.ran"\n' "$_rt_tmp" "$bin" >"$stubs/$bin"
  chmod +x "$stubs/$bin"
done
for i in "${!AI_ROSTER_NAMES[@]}"; do
  name="${AI_ROSTER_NAMES[i]}" bin="${AI_ROSTER_BINS[i]}"
  rc=0
  PATH="$stubs:$PATH" bash -c '
    ui_err() { printf "%s: %s\n" "$1" "$2" >&2; }
    source "$1/lib/dot/ai-commands.sh"
    _ai_invoke_provider "$2" "hello" </dev/null' _ "$REPO_ROOT" "$name" >/dev/null 2>&1 || rc=$?
  assert_equals "0" "$rc" "$name runs once"
  assert_file_exists "$_rt_tmp/$bin.ran" "$name calls $bin"
done

# Every roster tool has an install method, except those its users install
# themselves (no package and no native installer in the roster).
test_start "roster_tools_resolve_an_install_method"
methods="$(bash -c '
  source "$1/lib/dot/ai-install.sh"
  source "$1/lib/dot/ai-provision.sh"
  for b in claude codex kiro-cli cursor-agent passmcp-graph vibe; do
    printf "%s=%s\n" "$b" "$(ai_install_method "$b" || echo none)"
  done' _ "$REPO_ROOT")"
assert_contains "claude=native:install_claude_native" "$methods" "claude uses its native installer"
assert_contains "codex=mise:npm:@openai/codex" "$methods" "codex installs through mise"
assert_contains "kiro-cli=mise:kiro-cli" "$methods" "kiro-cli installs through its mise plugin"
assert_contains "cursor-agent=native:install_cursor_native" "$methods" "cursor-agent uses its native installer"
assert_contains "passmcp-graph=mise:github:sebastienrousseau/passmcp-graph" "$methods" "passmcp companions install through mise"
assert_contains "vibe=none" "$methods" "vibe has no installer in the roster"

test_summary
