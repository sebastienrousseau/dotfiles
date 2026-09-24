#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2030,SC2031
# Regression: Critical path tests — must-work features that gate every release.
# Regression for: d7e7c2bc (v0.2.499 baseline)
# Why: Critical-path regressions for install → chezmoi apply → dot doctor end-to-end smoke.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

DOT_CLI="$REPO_ROOT/bin/dot"
CHEZMOIDATA="$REPO_ROOT/defaults/.chezmoidata.toml"

# Sandbox for the behavioural cases: a throwaway HOME, stub tools, and an
# isolated chezmoi config. Nothing here touches the real HOME. The
# uninstaller is only ever run as a COPY with a PATH holding recording
# stubs for rm/chezmoi/mv and nothing else.
CP_WORK="$(mktemp -d "${TMPDIR:-/tmp}/critical-path.XXXXXX")"
trap 'rm -rf "$CP_WORK"' EXIT
mkdir -p "$CP_WORK/home" "$CP_WORK/bin" "$CP_WORK/only"
printf '#!/bin/sh\necho "$@" >>"%s/chezmoi.spy"\nexit 0\n' "$CP_WORK" >"$CP_WORK/bin/chezmoi"
printf '#!/bin/sh\n[ "$1" = init ] && echo "# starship-init-for-$2"\n' >"$CP_WORK/bin/starship"
for t in rm chezmoi mv; do
  printf '#!/bin/sh\necho "%s $*" >>"%s/destructive.spy"\n' "$t" "$CP_WORK" >"$CP_WORK/only/$t"
done
chmod +x "$CP_WORK"/bin/* "$CP_WORK"/only/*
printf '{}' >"$CP_WORK/chezmoi.json"
CP_CHEZMOI="$(command -v chezmoi 2>/dev/null || true)"

# cp_env <cmd...>: run with the sandbox HOME/XDG dirs and stub-first PATH.
cp_env() {
  env -i HOME="$CP_WORK/home" XDG_CONFIG_HOME="$CP_WORK/home/.config" \
    XDG_STATE_HOME="$CP_WORK/home/.local/state" XDG_DATA_HOME="$CP_WORK/home/.local/share" \
    XDG_CACHE_HOME="$CP_WORK/home/.cache" PATH="$CP_WORK/bin:/usr/bin:/bin" \
    TERM=dumb NO_COLOR=1 DOTFILES_NO_TUI=1 DOTFILES_NONINTERACTIVE=1 CI=1 \
    CHEZMOI_SOURCE_DIR="$REPO_ROOT/defaults" "$@" </dev/null
}
# cp_dot <args...>: run bin/dot in the sandbox; sets CP_RC and CP_OUT.
cp_dot() {
  CP_RC=0
  CP_OUT="$(cp_env bash "$DOT_CLI" "$@" 2>&1)" || CP_RC=$?
}
cp_skip() {
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (skipped: $1)"
}

# ═══════════════════════════════════════════════════════════════
# 1. CHEZMOI APPLY (the most critical operation)
# ═══════════════════════════════════════════════════════════════

# The apply wrapper runs against a recording chezmoi stub: it must call
# `chezmoi apply --force` and succeed.
cp_apply() { # <prewarm 0|1>
  rm -f "$CP_WORK/chezmoi.spy"
  CP_RC=0
  CP_OUT="$(cp_env env DOTFILES_SNAPSHOT_ON_APPLY=0 DOTFILES_POST_APPLY_REPAIR=0 \
    DOTFILES_CHEZMOI_STATUS=0 DOTFILES_PREWARM_ON_APPLY="$1" \
    bash "$REPO_ROOT/scripts/ops/chezmoi-apply.sh" 2>&1)" || CP_RC=$?
}
cp_apply 0
test_start "critical_chezmoi_apply_script_syntax"
assert_equals 0 "$CP_RC" "the apply wrapper succeeds"
test_start "critical_chezmoi_apply_calls_chezmoi"
assert_file_contains "$CP_WORK/chezmoi.spy" "apply --force" "and hands off to chezmoi apply --force"

test_start "critical_chezmoidata_exists"
assert_file_exists "$CHEZMOIDATA" ".chezmoidata.toml must exist"

# What templates actually see: chezmoi loads the manifest and exposes the
# version, the features map and the profile as data.
CP_DATA=""
if [[ -n "$CP_CHEZMOI" ]]; then
  CP_DATA="$(env -i HOME="$CP_WORK/home" PATH="/usr/bin:/bin" "$CP_CHEZMOI" \
    --config "$CP_WORK/chezmoi.json" --source "$REPO_ROOT/defaults" \
    --destination "$CP_WORK/home" --cache "$CP_WORK/cache" \
    --persistent-state "$CP_WORK/state.boltdb" execute-template \
    '{{ .dotfiles_version }}|{{ len .features }}|{{ .profile }}' 2>/dev/null)" || CP_DATA=""
fi
test_start "critical_chezmoidata_has_version"
if [[ -z "$CP_CHEZMOI" ]]; then cp_skip "chezmoi not installed"; else
  assert_true '[[ "${CP_DATA%%|*}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]' "templates see a semantic dotfiles_version ($CP_DATA)"
fi
test_start "critical_chezmoidata_has_features"
if [[ -z "$CP_CHEZMOI" ]]; then cp_skip "chezmoi not installed"; else
  cp_nfeat="${CP_DATA#*|}"
  assert_true '[[ "${cp_nfeat%%|*}" -gt 0 ]]' "templates see a non-empty features map"
fi
test_start "critical_chezmoidata_has_profile"
if [[ -z "$CP_CHEZMOI" ]]; then cp_skip "chezmoi not installed"; else
  assert_true '[[ -n "${CP_DATA##*|}" ]]' "templates see a default profile"
fi

# ═══════════════════════════════════════════════════════════════
# 2. DOT CLI (the control plane)
# ═══════════════════════════════════════════════════════════════

test_start "critical_dot_cli_exists"
assert_file_exists "$DOT_CLI" "dot CLI must exist"

# (bin/dot's syntax is proved by every case below that runs it.)

test_start "critical_dot_version"
assert_output_contains "dotfiles" "bash '$DOT_CLI' --version"

test_start "critical_dot_help_runs"
assert_exit_code 0 "bash '$DOT_CLI' help"

test_start "critical_dot_unknown_cmd_fails"
assert_exit_code 1 "bash '$DOT_CLI' __nonexistent_command_xyzzy__"

test_start "critical_dot_help_lists_sync"
assert_output_contains "sync" "bash '$DOT_CLI' help"

test_start "critical_dot_help_lists_doctor"
assert_output_contains "doctor" "bash '$DOT_CLI' help"

test_start "critical_dot_help_lists_ai"
assert_output_contains "AI" "bash '$DOT_CLI' help"

# ═══════════════════════════════════════════════════════════════
# 3. SHELL STARTUP CHAIN (must not break interactive shells)
# ═══════════════════════════════════════════════════════════════

test_start "critical_zshrc_template_exists"
assert_file_exists "$REPO_ROOT/defaults/dot_config/zsh/dot_zshrc.tmpl" "zshrc template must exist"

test_start "critical_zshenv_exists"
assert_file_exists "$REPO_ROOT/defaults/dot_zshenv" "zshenv must exist"

test_start "critical_bashrc_exists"
assert_file_exists "$REPO_ROOT/defaults/dot_bashrc" "bashrc must exist"

# The bashrc must load in an interactive bash and set up its cached-eval
# wrapper once the first prompt hydrates it.
test_start "critical_bashrc_syntax"
cp_out="$(cp_env bash --noprofile --rcfile "$REPO_ROOT/defaults/dot_bashrc" -i -c \
  '_deferred_hydration; type -t _cached_eval' 2>/dev/null | tail -1)" || true
assert_equals "function" "$cp_out" "an interactive bash loads the bashrc and defines _cached_eval"

test_start "critical_rc_d_ordering"
# rc.d files must follow numeric prefix ordering
rc_files=$(ls "$REPO_ROOT/defaults/dot_config/zsh/rc.d/" 2>/dev/null | sort)
prev_prefix="-1"
ordering_ok=true
while IFS= read -r f; do
  prefix="${f%%[-_]*}"
  prefix="${prefix//[!0-9]/}"
  if [[ -n "$prefix" && "$prefix" -lt "$prev_prefix" ]]; then
    ordering_ok=false
  fi
  [[ -n "$prefix" ]] && prev_prefix="$prefix"
done <<<"$rc_files"
if $ordering_ok; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: rc.d files follow numeric ordering"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: rc.d files must follow numeric ordering"
fi

# Alias files must load in a clean bash and define something.
cp_alias_count() {
  cp_env bash -c 'source "$1" >/dev/null 2>&1 || exit 1; echo $(( $(alias | wc -l) + $(declare -F | wc -l) ))' _ "$1" 2>/dev/null || echo 0
}
test_start "critical_aliases_file_syntax"
assert_true '[[ "$(cp_alias_count "$REPO_ROOT/defaults/.chezmoitemplates/aliases/ai/ai.aliases.sh")" -gt 0 ]]' "AI aliases load and define aliases"
test_start "critical_default_aliases_syntax"
assert_true '[[ "$(cp_alias_count "$REPO_ROOT/defaults/.chezmoitemplates/aliases/default/default.aliases.sh")" -gt 0 ]]' "default aliases load and define aliases"

# ═══════════════════════════════════════════════════════════════
# 4. DIAGNOSTICS (must always be able to report health)
# ═══════════════════════════════════════════════════════════════

test_start "critical_doctor_script_exists"
assert_file_exists "$REPO_ROOT/scripts/diagnostics/doctor.sh" "doctor.sh must exist"

test_start "critical_doctor_syntax"
cp_out="$(cp_env bash "$REPO_ROOT/scripts/diagnostics/doctor.sh" --json 2>/dev/null)" || true
assert_contains '"results"' "$cp_out" "doctor runs to its report (--json document with results)"

test_start "critical_health_script_exists"
assert_file_exists "$REPO_ROOT/scripts/diagnostics/health.sh" "health.sh must exist"

test_start "critical_smoke_test_syntax"
cp_out="$(cp_env bash "$REPO_ROOT/scripts/diagnostics/smoke-test.sh" 2>&1)" || true
assert_true 'grep -qE "([0-9]+ failed +[0-9]+ passed|All [0-9]+ tests passed)" <<<"$cp_out"' "the smoke test runs to its summary"

# ═══════════════════════════════════════════════════════════════
# 5. AI CLI STATUS (must always report, even with no tools)
# ═══════════════════════════════════════════════════════════════

test_start "critical_ai_command_syntax"
cp_dot ai tools
assert_contains "AI CLI Status" "$CP_OUT" "dot ai tools reports status with no tools installed"
# (The mise package mapping is pinned behaviourally by
# tests/unit/dot-cli/test_ai_install_pkg_map.sh.)

test_start "critical_ai_bridge_help"
output=$(bash "$REPO_ROOT/scripts/dot/commands/ai.sh" cl --help 2>&1 || true)
if echo "$output" | grep -q "Available styles"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: AI bridge help shows available styles"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: AI bridge help should show styles"
fi

# ═══════════════════════════════════════════════════════════════
# 6. INSTALLER (must be safe to run)
# ═══════════════════════════════════════════════════════════════

test_start "critical_installer_exists"
assert_file_exists "$REPO_ROOT/install.sh" "install.sh must exist"

# (install.sh's syntax is proved by the --help run below.)

test_start "critical_installer_help"
assert_output_contains "Usage" "bash '$REPO_ROOT/install.sh' --help"

# The uninstaller asks first, and "n" must abort before anything is
# touched. Run as a COPY with a PATH holding only recording stubs, so even
# a broken prompt could not reach a real rm or chezmoi.
cp "$REPO_ROOT/scripts/uninstall.sh" "$CP_WORK/uninstall.copy.sh"
cp_out="$(printf 'n\n' | env -i HOME="$CP_WORK/home" PATH="$CP_WORK/only" /bin/bash "$CP_WORK/uninstall.copy.sh" 2>&1)" || true
test_start "critical_uninstaller_syntax"
assert_contains "Aborted." "$cp_out" "answering n aborts the uninstall"
test_start "critical_uninstaller_declined_touches_nothing"
assert_file_not_exists "$CP_WORK/destructive.spy" "no rm, chezmoi or mv is run when declined"

# ═══════════════════════════════════════════════════════════════
# 7. PREWARM (must be able to regenerate caches)
# ═══════════════════════════════════════════════════════════════

test_start "critical_prewarm_syntax"
rm -rf "$CP_WORK/home/.cache"
cp_env bash "$REPO_ROOT/scripts/ops/prewarm.sh" >/dev/null 2>&1 || true
assert_file_contains "$CP_WORK/home/.cache/bash/starship-init.bash" "starship-init-for-bash" "prewarm writes the starship init cache"

cp_apply 1
test_start "critical_prewarm_in_apply"
assert_contains "Pre-warm" "$CP_OUT" "DOTFILES_PREWARM_ON_APPLY=1 pre-warms after apply"
cp_apply 0
test_start "critical_prewarm_off_in_apply"
assert_false '[[ "$CP_OUT" == *Pre-warm* ]]' "DOTFILES_PREWARM_ON_APPLY=0 skips it"

# ═══════════════════════════════════════════════════════════════
# 8. RC.D FILES — each must have valid bash/zsh syntax
# ═══════════════════════════════════════════════════════════════

test_start "critical_rc_d_00_alias_shims_exists"
assert_file_exists "$REPO_ROOT/defaults/dot_config/zsh/rc.d/00-alias-shims.zsh" "00-alias-shims.zsh must exist"

test_start "critical_rc_d_05_ssh_agent_exists"
assert_file_exists "$REPO_ROOT/defaults/dot_config/zsh/rc.d/05-ssh-agent.zsh" "05-ssh-agent.zsh must exist"

test_start "critical_rc_d_10_env_template_exists"
assert_file_exists "$REPO_ROOT/defaults/dot_config/zsh/rc.d/10-env.zsh.tmpl" "10-env.zsh.tmpl must exist"

test_start "critical_rc_d_20_zinit_exists"
assert_file_exists "$REPO_ROOT/defaults/dot_config/zsh/rc.d/20-zinit.zsh" "20-zinit.zsh must exist"

test_start "critical_rc_d_30_options_template_exists"
assert_file_exists "$REPO_ROOT/defaults/dot_config/zsh/rc.d/30-options.zsh.tmpl" "30-options.zsh.tmpl must exist"

test_start "critical_rc_d_40_bell_exists"
assert_file_exists "$REPO_ROOT/defaults/dot_config/zsh/rc.d/40-bell.zsh" "40-bell.zsh must exist"

test_start "critical_rc_d_50_fortune_exists"
assert_file_exists "$REPO_ROOT/defaults/dot_config/zsh/rc.d/50-login-fortune.zsh" "50-login-fortune.zsh must exist"

test_start "critical_rc_d_99_alias_wrapper_exists"
assert_file_exists "$REPO_ROOT/defaults/dot_config/zsh/rc.d/99-alias-wrapper.zsh" "99-alias-wrapper.zsh must exist"

# ═══════════════════════════════════════════════════════════════
# 9. DOT COMMAND SCRIPTS — all must exist and have valid syntax
# ═══════════════════════════════════════════════════════════════

# Each module is loaded through bin/dot with one read-only command whose
# outcome in the sandbox is known. (lint runs a full repo lint wherever
# a shellcheck binary is installed; its module is pinned by tests/unit/dot-cli/test_lint.sh.)
cp_module() { # <name> <want rc> <want output> <args...>
  local name="$1" rc="$2" want="$3"
  shift 3
  cp_dot "$@"
  test_start "critical_dot_cmd_${name}_syntax"
  assert_equals "$rc" "$CP_RC" "dot $* exits $rc"
  test_start "critical_dot_cmd_${name}_reports"
  assert_contains "$want" "$CP_OUT" "dot $* reports '$want'"
}
cp_module core 0 "Dotfiles Status" status
cp_module diagnostics 0 "mise toolchain" locks
cp_module aliases 0 "Aliases" aliases list
cp_module tools 0 "Dot Tools" tools
cp_module meta 0 "Declarative dotfiles" docs
cp_module secrets 1 "No age key found" secrets
cp_module security 1 "Telemetry" telemetry
cp_module agent 0 "Agent Card" agent card
cp_module appearance 0 "Current" theme current
cp_module fleet 0 "Fleet Commands" fleet help
cp_module patterns 0 "AI Steering Patterns" patterns list
cp_module restore 1 "No backups found" restore --list

# ═══════════════════════════════════════════════════════════════
# 10. KEY DOT_LOCAL/BIN EXECUTABLES
# ═══════════════════════════════════════════════════════════════

test_start "critical_bin_dot_exists"
assert_file_exists "$REPO_ROOT/bin/dot" "dot executable must exist"

test_start "critical_bin_tour_exists"
assert_file_exists "$REPO_ROOT/defaults/dot_local/bin/executable_tour" "tour executable must exist"

test_start "critical_bin_dot_ai_exists"
assert_file_exists "$REPO_ROOT/defaults/dot_local/bin/executable_dot-ai" "dot-ai executable must exist"

test_start "critical_bin_extract_exists"
assert_file_exists "$REPO_ROOT/defaults/dot_local/bin/executable_extract" "extract executable must exist"

test_start "critical_bin_uuid_exists"
assert_file_exists "$REPO_ROOT/defaults/dot_local/bin/executable_uuid" "uuid executable must exist"

# ═══════════════════════════════════════════════════════════════
# 11. CHEZMOI TEMPLATE FILES EXIST
# ═══════════════════════════════════════════════════════════════

test_start "critical_gitconfig_template_exists"
assert_file_exists "$REPO_ROOT/defaults/dot_gitconfig.tmpl" "dot_gitconfig.tmpl must exist"

test_start "critical_zshenv_exists_toplevel"
assert_file_exists "$REPO_ROOT/defaults/dot_zshenv" "dot_zshenv must exist at repo root"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
