#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034,SC2016
# Strict alias policy (aliases.policy.strict_mode): run each piece instead of
# grepping for it. Everything runs in a sandbox HOME with stub git, docker,
# rm and chezmoi on PATH, so nothing real is deleted, reset or applied.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

SAFETY="$REPO_ROOT/defaults/dot_config/shell/05-core-safety.sh"
ALIASES="$REPO_ROOT/defaults/.chezmoitemplates/aliases"
SB="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/alias-strict.XXXXXX")" && pwd)"
trap 'rm -rf "$SB"' EXIT
mkdir -p "$SB/home" "$SB/bin"
CALLS="$SB/calls.log"

# stub <name>: a fake tool that records its arguments.
stub() {
  printf '#!/bin/sh\necho "%s $*" >>"%s"\n' "$1" "$CALLS" >"$SB/bin/$1"
  chmod +x "$SB/bin/$1"
}
stub git
stub docker
stub rm
stub chezmoi

# in_bash <script>: run bash with the sandbox HOME, stub PATH and no TTY.
in_bash() {
  env -i HOME="$SB/home" PATH="$SB/bin:/usr/bin:/bin" USER=tester "$BASH" --norc --noprofile \
    -c "$1" </dev/null 2>"$SB/err"
}

# ── The shipped default ────────────────────────────────────────────────────
test_start "strict_mode_default_false"
assert_equals "False" \
  "$(python3 -c 'import sys, tomllib; print(tomllib.load(open(sys.argv[1], "rb"))["aliases"]["policy"]["strict_mode"])' \
    "$REPO_ROOT/defaults/.chezmoidata.toml")" "strict mode ships off"

# ── dot_confirm_destructive ────────────────────────────────────────────────
test_start "confirm_passes_when_strict_mode_off"
rc=0
in_bash "source '$SAFETY'; DOTFILES_ALIAS_STRICT_MODE=0 dot_confirm_destructive 'wipe'" || rc=$?
assert_equals "0" "$rc" "without strict mode a destructive action is not gated"

test_start "confirm_refuses_without_tty_in_strict_mode"
rc=0
in_bash "source '$SAFETY'; DOTFILES_ALIAS_STRICT_MODE=1 dot_confirm_destructive 'wipe'" || rc=$?
assert_equals "1|[STRICT] Refusing wipe without TTY confirmation." "$rc|$(cat "$SB/err")" \
  "strict mode refuses a destructive action with no terminal to confirm on"

test_start "confirm_forced_logs_to_default_file"
rc=0
in_bash "source '$SAFETY'; DOTFILES_ALIAS_STRICT_MODE=1 DOTFILES_FORCE_DESTRUCTIVE=1 dot_confirm_destructive 'wipe'" || rc=$?
assert_true '[[ $rc == 0 ]] && grep -q "action=wipe	mode=forced" "$SB/home/.dotfiles_destruction.log"' \
  "a forced action proceeds and is logged to ~/.dotfiles_destruction.log"

test_start "confirm_honours_custom_log"
in_bash "source '$SAFETY'; DOTFILES_ALIAS_STRICT_MODE=1 DOTFILES_FORCE_DESTRUCTIVE=1 DOTFILES_DESTRUCTIVE_LOG='$SB/custom.log' dot_confirm_destructive 'wipe2'" || true
assert_true 'grep -q "action=wipe2" "$SB/custom.log"' "DOTFILES_DESTRUCTIVE_LOG chooses the log file"

# ── Destructive helpers are gated in strict mode ───────────────────────────
# gcom exists only with DOTFILES_ENABLE_DANGEROUS_ALIASES=1 and resets to
# the primary branch (from git_primary_branch, not an argument).
test_start "git_gcom_gated_in_strict_mode"
: >"$CALLS"
out="$(in_bash "DOTFILES_ENABLE_DANGEROUS_ALIASES=1; source '$SAFETY'; source '$ALIASES/git/git.aliases.sh'
type -t gcom; DOTFILES_ALIAS_STRICT_MODE=1 gcom")" || true
assert_true '[[ $out == function* ]] && ! grep -q "reset --hard" "$CALLS"' \
  "gcom exists and does not hard-reset without confirmation"

test_start "git_gcom_runs_when_strict_mode_off"
: >"$CALLS"
in_bash "DOTFILES_ENABLE_DANGEROUS_ALIASES=1; source '$SAFETY'; source '$ALIASES/git/git.aliases.sh'
DOTFILES_ALIAS_STRICT_MODE=0 gcom" || true
assert_true 'grep -q "reset --hard origin/" "$CALLS"' "gcom hard-resets when strict mode is off"

test_start "docker_prune_gated_in_strict_mode"
: >"$CALLS"
out="$(in_bash "source '$SAFETY'; source '$ALIASES/docker/docker.aliases.sh'; type -t dpruneaf; DOTFILES_ALIAS_STRICT_MODE=1 dpruneaf")" || true
assert_true '[[ $out == function* ]] && ! grep -q "prune" "$CALLS"' "dpruneaf exists and does not prune without confirmation"

test_start "docker_prune_runs_when_strict_mode_off"
: >"$CALLS"
in_bash "source '$SAFETY'; source '$ALIASES/docker/docker.aliases.sh'; DOTFILES_ALIAS_STRICT_MODE=0 dpruneaf" || true
assert_true 'grep -q "prune" "$CALLS"' "dpruneaf prunes when strict mode is off"

test_start "interactive_del_gated_in_strict_mode"
: >"$CALLS"
# del (like the other file aliases) exists only with DOTFILES_SAFE_ALIASES=1.
out="$(in_bash "shopt -s expand_aliases; DOTFILES_SAFE_ALIASES=1; source '$SAFETY'; source '$ALIASES/interactive/interactive.aliases.sh'
DOTFILES_ALIAS_STRICT_MODE=1
alias del >/dev/null && echo defined
eval 'del target-file'")" || true
assert_true '[[ $out == *defined* ]] && ! grep -q "^rm" "$CALLS"' "del exists and removes nothing without confirmation"

test_start "interactive_del_runs_when_strict_mode_off"
: >"$CALLS"
in_bash "shopt -s expand_aliases; DOTFILES_SAFE_ALIASES=1; source '$SAFETY'; source '$ALIASES/interactive/interactive.aliases.sh'
DOTFILES_ALIAS_STRICT_MODE=0
eval 'del target-file'" || true
assert_true 'grep -q "^rm .*-rfvi target-file" "$CALLS"' "del removes (via the stub rm) when strict mode is off"

# ── Apply paths run alias governance in strict mode ────────────────────────
# A fixture tree: the real apply script and libraries, a stub governance
# script that records the policy it was given.
FX="$SB/repo"
mkdir -p "$FX/scripts/ops" "$FX/scripts/diagnostics"
cp "$REPO_ROOT/scripts/ops/chezmoi-apply.sh" "$FX/scripts/ops/"
cp -R "$REPO_ROOT/lib" "$FX/"
printf '#!/bin/sh\necho "governance policy=$DOTFILES_ALIAS_POLICY" >>"%s"\n' "$CALLS" >"$FX/scripts/diagnostics/alias-governance.sh"

# apply_script <strict>: run the fixture apply script with the stub chezmoi.
apply_script() {
  : >"$CALLS"
  env -i HOME="$SB/home" PATH="$SB/bin:/usr/bin:/bin" NO_COLOR=1 DOTFILES_NONINTERACTIVE=1 \
    DOTFILES_ALIAS_STRICT_MODE="$1" DOTFILES_SNAPSHOT_ON_APPLY=0 DOTFILES_POST_APPLY_REPAIR=0 \
    DOTFILES_CHEZMOI_STATUS=0 "$BASH" "$FX/scripts/ops/chezmoi-apply.sh" >/dev/null 2>&1 </dev/null || true
}

test_start "apply_script_runs_strict_governance"
apply_script 1
assert_true 'grep -q "governance policy=strict" "$CALLS" && grep -q "^chezmoi apply" "$CALLS"' \
  "chezmoi-apply.sh runs alias governance with the strict policy, then applies"

test_start "apply_script_skips_governance_when_off"
apply_script 0
assert_false 'grep -q "governance" "$CALLS"' "without strict mode no governance runs"

test_start "install_lib_runs_strict_governance"
: >"$CALLS"
env -i HOME="$SB/home" PATH="$SB/bin:/usr/bin:/bin" DOTFILES_ALIAS_STRICT_MODE=1 "$BASH" --norc --noprofile -c \
  "source '$REPO_ROOT/install/lib/chezmoi.sh' >/dev/null 2>&1; apply_chezmoi '$FX' 1" >/dev/null 2>&1 </dev/null || true
assert_true 'grep -q "governance policy=strict" "$CALLS" && grep -q "^chezmoi apply" "$CALLS"' \
  "the installer's apply_chezmoi runs strict governance before applying"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
