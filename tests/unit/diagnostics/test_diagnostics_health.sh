#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for health diagnostic script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

HEALTH_FILE="$REPO_ROOT/scripts/diagnostics/health.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

# health.sh runs from a fixture repo: a copy of the script, lib/dot and the
# chezmoi data, with scripts/ops/heal.sh replaced by a stub that records
# how --fix called it, so nothing on the host is changed. Each case reads
# the JSON report (--json) and asserts one check's status and message.
HL="$DOTFILES_COV_TMPDIR/health-fixture"
mkdir -p "$HL/repo/scripts/diagnostics" "$HL/repo/scripts/ops" "$HL/repo/defaults" "$HL/bin"
cp "$HEALTH_FILE" "$HL/repo/scripts/diagnostics/health.sh"
cp -R "$REPO_ROOT/lib" "$HL/repo/"
cp "$REPO_ROOT/defaults/.chezmoidata.toml" "$HL/repo/defaults/.chezmoidata.toml"
printf '#!/bin/sh\necho "heal $*" >>"%s/heal.log"\n' "$HL" >"$HL/repo/scripts/ops/heal.sh"
chmod +x "$HL/repo/scripts/ops/heal.sh"

# stub <name> [body]: a fake tool in the fixture PATH.
stub() {
  printf '#!/bin/sh\n%s\n' "${2:-exit 0}" >"$HL/bin/$1"
  chmod +x "$HL/bin/$1"
}

# health <home> [VAR=value...] -- [flags...]: run the fixture health.sh with a
# clean environment; stdout to $HL/out, exit status in H_RC.
health() {
  local home="$1"
  shift
  local -a envs=()
  while [[ "${1:-}" != "--" ]]; do
    envs+=("$1")
    shift
  done
  shift
  mkdir -p "$home"
  H_RC=0
  env -i HOME="$home" PATH="$HL/bin:/usr/bin:/bin" NO_COLOR=1 DOTFILES_NONINTERACTIVE=1 \
    ${envs[@]+"${envs[@]}"} bash "$HL/repo/scripts/diagnostics/health.sh" "$@" >"$HL/out" 2>/dev/null || H_RC=$?
}

# check_of <name>: "status|message" of that check in the last JSON report.
check_of() {
  python3 -c 'import json,sys
d=json.load(open(sys.argv[1]))
m=[r for r in d["results"] if r["check"]==sys.argv[2]]
print(m[0]["status"]+"|"+m[0]["message"] if m else "missing")' "$HL/out" "$1" 2>/dev/null || echo "invalid-json"
}

test_start "health_json_flags"
health "$HL/h-json" -- -j
short="$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["results"]) > 0)' "$HL/out" 2>/dev/null)"
health "$HL/h-json" -- --json
long="$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["results"]) > 0)' "$HL/out" 2>/dev/null)"
assert_equals "True|True" "$short|$long" "-j and --json both emit a JSON report with results"

test_start "health_verbose_flags"
health "$HL/h-v" -- -v
v1="$H_RC:$(grep -c Summary "$HL/out")"
health "$HL/h-v" -- --verbose
assert_equals "0:1|0:1" "$v1|$H_RC:$(grep -c Summary "$HL/out")" "-v and --verbose run the full report"

stub zsh
test_start "health_active_shell_supported"
health "$HL/h-shell" SHELL=/opt/bin/fish -- -j
assert_equals "pass|fish" "$(check_of 'Active shell')" "a supported active shell passes"

test_start "health_active_shell_unsupported"
health "$HL/h-shell" SHELL=/opt/bin/tcsh -- -j
assert_equals "warn|Current: /opt/bin/tcsh" "$(check_of 'Active shell')" "an unsupported active shell warns"

test_start "health_zinit_not_required_for_fish"
health "$HL/h-zinit" SHELL=/opt/bin/zsh -- -j
assert_equals "pass|Not required for $(sed -n 's/^default_shell = "\(.*\)".*/\1/p' "$HL/repo/defaults/.chezmoidata.toml")" \
  "$(check_of 'Zinit plugin manager')" "zinit is not required when the default shell is not zsh"

test_start "health_zinit_warns_when_zsh_is_default"
cp "$HL/repo/defaults/.chezmoidata.toml" "$HL/data.bak"
sed -i.tmp 's/^default_shell = ".*"/default_shell = "zsh"/' "$HL/repo/defaults/.chezmoidata.toml"
health "$HL/h-zinit" SHELL=/opt/bin/zsh -- -j
cp "$HL/data.bak" "$HL/repo/defaults/.chezmoidata.toml"
assert_equals "warn|Not found" "$(check_of 'Zinit plugin manager')" "zinit is missing when zsh is the default and active shell"

stub node 'echo v24.0.0'
stub mise
test_start "health_node_manager_mise"
health "$HL/h-node" -- -j
assert_equals "pass|mise" "$(check_of 'Node version manager')" "mise counts as the node version manager"

test_start "health_nerd_font_found"
mkdir -p "$HL/h-font/.local/share/fonts"
: >"$HL/h-font/.local/share/fonts/FiraCodeNerdFont-Regular.ttf"
health "$HL/h-font" -- -j
assert_equals "pass|" "$(check_of 'Nerd Font available')" "a Nerd Font in ~/.local/share/fonts passes"

stub gpg
test_start "health_git_signing_ssh"
G="$HL/h-git"
mkdir -p "$G/.ssh" "$G/.config/git"
: >"$G/.ssh/signing.pub"
: >"$G/.config/git/allowed_signers"
printf '[gpg]\n\tformat = ssh\n[user]\n\tsigningkey = ~/.ssh/signing.pub\n' >"$G/.gitconfig"
health "$G" -- -j
assert_equals "pass|ssh" "$(check_of 'Git signing')" "a complete SSH signing setup passes"

test_start "health_fix_runs_heal"
: >"$HL/heal.log"
health "$HL/h-fix" -- -f -j
fix_short="$(cat "$HL/heal.log")"
: >"$HL/heal.log"
health "$HL/h-fix" -- --fix -j
assert_equals "heal |heal " "$fix_short|$(cat "$HL/heal.log")" "-f and --fix run heal.sh without --force"

test_start "health_fix_force_passes_force"
: >"$HL/heal.log"
health "$HL/h-fix" -- -f -F -j
force_short="$(cat "$HL/heal.log")"
: >"$HL/heal.log"
health "$HL/h-fix" -- --fix --force -j
assert_equals "heal --force|heal --force" "$force_short|$(cat "$HL/heal.log")" "-F/--force passes --force to heal.sh"

test_start "health_force_alone_does_not_heal"
: >"$HL/heal.log"
health "$HL/h-fix" -- -F -j
assert_equals "" "$(cat "$HL/heal.log")" "--force without --fix changes nothing"
rm -f "$HL/bin/zsh" "$HL/bin/node" "$HL/bin/mise" "$HL/bin/gpg"

# A diagnostic tool has to survive the tools it is diagnosing. Every probed
# binary is replaced with one that exits 1, which is what a broken install, a
# shim with no backing tool, or a sandboxed HOME actually looks like.
#
# Only `zsh` used to be faked here, and the test passed or failed depending on
# whether the *host* happened to have a working node — green in CI, red
# locally where `node` resolved to a mise shim under the sandbox HOME. The
# abort was never in the zsh path at all: `node_version=$(node --version)`
# takes the substitution's exit status, so under `set -e` it killed the report
# mid-section with no Summary and rc=1.
test_start "health_failed_zsh_timing_still_prints_summary"
for _broken in zsh node python3 git stat; do
  printf '#!/usr/bin/env bash\nexit 1\n' >"$DOTFILES_COV_TMPDIR/bin/$_broken"
  chmod +x "$DOTFILES_COV_TMPDIR/bin/$_broken"
done
health_output=$(NO_COLOR=1 DOTFILES_NONINTERACTIVE=1 bash "$HEALTH_FILE" 2>&1)
health_rc=$?
assert_equals "0" "$health_rc" "a failing probed tool must not abort health"
assert_output_contains "Summary" "printf '%s' \"\$health_output\""

echo ""
echo "Health diagnostic tests completed."
# Slice 2: drive real line coverage of the script under test
cov_exercise_script "$HEALTH_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
