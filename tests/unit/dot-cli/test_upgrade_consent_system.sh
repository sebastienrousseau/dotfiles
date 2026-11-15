#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# `dot system update` (plugins/system/libexec/system/upgrade.sh): the
# system-package consent and the phases it gates. Sudo is cached before
# the phases while there is a terminal; a brew cask that may need sudo is
# named when there is none; the consented package manager runs its own
# upgrade; mise self-updates only when dot installed it. Fakes record calls.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-consent-system.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/home/.local/bin"

# Each fake records "<name> <args>" and exits FAIL_<name> (0 by default);
# brew prints OUTDATED for `brew outdated`, sudo fails `-n true` unless
# SUDO_CACHED=1.
for tool in apt-get dnf pacman zypper mise; do
  printf '#!/bin/sh\necho "%s $*" >>"%s/calls"\nexit "${FAIL_%s:-0}"\n' \
    "$tool" "$WORK" "$(printf '%s' "$tool" | tr -c 'a-z\n' '_')" >"$WORK/bin/$tool"
done
cat >"$WORK/bin/brew" <<EOF
#!/bin/sh
echo "brew \$*" >>"$WORK/calls"
case "\$1" in
  outdated) [ -n "\${OUTDATED:-}" ] && printf '%s\n' \$OUTDATED; exit 0 ;;
  upgrade) exit "\${FAIL_brew_upgrade:-0}" ;;
esac
exit 0
EOF
cat >"$WORK/bin/sudo" <<EOF
#!/bin/sh
echo "sudo \$*" >>"$WORK/calls"
if [ "\$1" = -n ] && [ "\$2" = true ]; then [ "\${SUDO_CACHED:-0}" = 1 ]; exit; fi
exit "\${FAIL_sudo:-0}"
EOF
chmod +x "$WORK/bin/"*
cp "$WORK/bin/mise" "$WORK/home/.local/bin/mise"

# Children run under this test's own bash: the coverage runner sends their
# trace records to a descriptor of its own on bash 4.1+, so capturing their
# stderr below loses nothing. A bash found on the PATH below could be macOS's
# /bin/bash 3.2, which writes them to stderr instead.
BASH_BIN="$BASH"

# run CODE...: source the upgrade library with the UI and prompts stubbed,
# then run CODE; prints its stdout and stderr. CAN_ASK=1 means a terminal,
# ANSWER is dot_consent's status, PM is the system package manager.
run() {
  : >"$WORK/calls"
  HOME="$WORK/home" PATH="$WORK/bin:/usr/bin:/bin" "$BASH_BIN" -c '
    set -uo pipefail
    source "$1/plugins/system/libexec/system/upgrade.sh"
    ui_info() { echo "info: $*"; }
    ui_warn() { echo "warn: $*"; }
    dot_can_ask() { [[ "${CAN_ASK:-0}" == 1 ]]; }
    dot_consent() { return "${ANSWER:-0}"; }
    dot_upgrade_system_pm() { [[ -n "${PM:-}" ]] && printf "%s" "$PM"; }
    shift
    eval "$*"' _ "$REPO_ROOT" "$@" 2>&1
}
calls() { cat "$WORK/calls"; }

# ── sudo ────────────────────────────────────────────────────────────────
test_start "sudo_ready_when_already_cached"
assert_equals "0" "$(SUDO_CACHED=1 run '_dot_upgrade_sudo_ready; echo $?')" "cached sudo is ready"
assert_false "[[ \"\$(calls)\" == *'sudo -v'* ]]" "and no password is asked"

test_start "sudo_not_ready_with_nobody_to_ask"
assert_equals "1" "$(run '_dot_upgrade_sudo_ready; echo $?')" "no terminal, no sudo"

test_start "sudo_asked_once_with_a_terminal"
out="$(CAN_ASK=1 run '_dot_upgrade_sudo_ready; echo "rc=$?"')"
assert_contains "need your password once" "$out" "says why it asks"
assert_contains "rc=0" "$out" "sudo -v answered"
assert_contains "sudo -v" "$(calls)" "sudo -v caches the credentials"

# ── consent ─────────────────────────────────────────────────────────────
test_start "consent_without_a_package_manager_leaves_it_empty"
assert_equals "[]" "$(run '_dot_upgrade_consent_system; echo "[$DOT_UPGRADE_SYSTEM]"')" "nothing to upgrade"

test_start "consent_declined_leaves_it_empty"
assert_equals "[]" "$(PM=apt-get ANSWER=1 run '_dot_upgrade_consent_system; echo "[$DOT_UPGRADE_SYSTEM]"')" "no means no"

test_start "consent_with_sudo_records_the_manager"
assert_equals "[apt-get]" "$(PM=apt-get SUDO_CACHED=1 run '_dot_upgrade_consent_system; echo "[$DOT_UPGRADE_SYSTEM]"')" "yes and sudo"

test_start "consent_without_sudo_skips_system_packages"
out="$(PM=dnf run '_dot_upgrade_consent_system; echo "[$DOT_UPGRADE_SYSTEM]"')"
assert_contains "sudo is needed and could not be confirmed" "$out" "says why"
assert_contains "[]" "$out" "and records nothing"

test_start "consent_for_brew_needs_no_sudo"
assert_equals "[brew]" "$(PM=brew run '_dot_upgrade_consent_system; echo "[$DOT_UPGRADE_SYSTEM]"')" "brew with no outdated casks"

# ── brew casks ──────────────────────────────────────────────────────────
test_start "outdated_casks_without_sudo_are_named"
out="$(OUTDATED="docker zoom" run '_dot_upgrade_brew_sudo')"
assert_contains "docker zoom may need sudo" "$out" "each cask named"

test_start "outdated_casks_with_sudo_cached_are_quiet"
assert_equals "" "$(OUTDATED=docker SUDO_CACHED=1 run '_dot_upgrade_brew_sudo')" "nothing to warn about"

test_start "brew_left_names_the_casks_and_fails"
out="$(OUTDATED="docker zoom" run '_dot_upgrade_brew_left; echo "rc=$?"')"
assert_contains "Still outdated: docker zoom" "$out" "the casks left"
assert_contains "brew upgrade --cask docker zoom" "$out" "and the command to finish"
assert_contains "rc=1" "$out" "the phase still fails"

test_start "brew_left_with_nothing_outdated_fails_quietly"
assert_equals "rc=1" "$(run '_dot_upgrade_brew_left; echo "rc=$?"')" "a failed upgrade stays failed"

# ── the system phase ────────────────────────────────────────────────────
test_start "system_phase_runs_each_manager"
for pm in apt-get dnf pacman zypper; do
  run "_dot_upgrade_system $pm" >/dev/null
  assert_contains "$pm" "$(calls)" "$pm upgrades through sudo -n"
done

test_start "system_phase_brew_failure_names_what_is_left"
out="$(FAIL_brew_upgrade=1 OUTDATED=docker run '_dot_upgrade_system brew; echo "rc=$?"')"
assert_contains "Still outdated: docker" "$out" "the cask left behind"
assert_contains "rc=1" "$out" "and the phase fails"

test_start "system_phase_unknown_manager_fails"
assert_equals "rc=1" "$(run '_dot_upgrade_system portage; echo "rc=$?"')" "no guessing"

# ── nix ─────────────────────────────────────────────────────────────────
test_start "nix_steps_run_with_a_flake_and_nix"
mkdir -p "$WORK/src/nix" && : >"$WORK/src/nix/flake.nix"
out="$(run 'has_command() { true; }; _upgrade_step() { echo "step $1"; }; dot_upgrade_nix_steps "'"$WORK/src"'"')"
assert_equals "step nix-flake|step nix-gc" "$(printf '%s\n' "$out" | paste -sd'|' -)" "flake update, then garbage collection"

test_start "nix_steps_skip_without_nix"
out="$(run 'has_command() { false; }; _upgrade_step() { echo "step $1"; }; dot_upgrade_nix_steps "'"$WORK/src"'"')"
assert_equals "" "$out" "no nix, no nix steps"

# ── mise ────────────────────────────────────────────────────────────────
test_start "mise_installed_by_dot_self_updates"
PATH_FIRST="$WORK/home/.local/bin"
HOME="$WORK/home" PATH="$PATH_FIRST:$WORK/bin:/usr/bin:/bin" "$BASH_BIN" -c '
  source "$1/plugins/system/libexec/system/upgrade.sh"; : >"$2/calls"; _dot_upgrade_mise' _ "$REPO_ROOT" "$WORK" 2>&1
assert_equals "mise self-update --yes|mise install|mise upgrade" "$(paste -sd'|' - <"$WORK/calls")" "self-update, install, upgrade"

test_start "mise_from_elsewhere_is_left_to_its_manager"
run '_dot_upgrade_mise' >/dev/null
assert_equals "mise install|mise upgrade" "$(paste -sd'|' - <"$WORK/calls")" "no self-update"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
