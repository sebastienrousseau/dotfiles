#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Behavioural tests for lib/dot/preflight.sh, lib/dot/upgrade.sh and
# lib/dot/ai-provision.sh: consent (default no), mise bootstrap, and the
# toolchain phases of `dot upgrade`. Every external tool is a stub on a PATH
# that carries nothing else; the one real terminal case runs under a pty.
# shellcheck disable=SC1090,SC1091,SC2016,SC2034

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

REAL_BASH="${BASH:-$(command -v bash)}"
REAL_PYTHON="$(command -v python3)"
WORK="$(mktemp -d -t dot-preflight.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
BASE="$WORK/base"
STUBS="$WORK/stubs"
mkdir -p "$BASE" "$STUBS" "$WORK/home"
# gzip: GNU tar execs it for -z (bsdtar on macOS has it built in).
for c in bash env cat cp sed awk grep tr head cut mktemp dirname basename rm mkdir chmod install tar gzip uname printf; do
  p="$(command -v "$c" 2>/dev/null)" && ln -sf "$p" "$BASE/$c"
done

# stub <name> [body]: a logging stub on the stub PATH.
stub() {
  printf '#!%s\nprintf "%s %%s\\n" "$*" >>"%s/calls"\n%s\n' "$REAL_BASH" "$1" "$WORK" "${2:-}" >"$STUBS/$1"
  chmod +x "$STUBS/$1"
}
calls() { cat "$WORK/calls" 2>/dev/null; }

# lib <code>: run <code> with the three libraries sourced, off any terminal.
lib() {
  : >"$WORK/calls"
  OUT="$(env -i HOME="$WORK/home" PATH="$STUBS:$BASE" TMPDIR="$WORK" NO_COLOR=1 \
    DOTFILES_YES="${YES:-0}" CI="${CI_VAR:-}" "$REAL_BASH" -c '
    set -uo pipefail
    source "$1/lib/dot/ui.sh"
    has_command() { command -v "$1" >/dev/null 2>&1; }
    source "$1/lib/dot/preflight.sh"
    source "$1/lib/dot/upgrade.sh"
    _ai_mise_pkg() { case "$1" in codex) echo npm:@openai/codex ;; esac; }
    _ai_in_scratch_dir() { "$@"; }
    ai_pinned_spec() { printf "%s@1.0.0\n" "$1"; }
    ai_pin_bumps() { :; }
    source "$1/lib/dot/ai-provision.sh"
    eval "$2"' _ "$REPO_ROOT" "$1" 2>&1)"
  RC=$?
}

# ── consent: never yes by default ───────────────────────────────────────
test_start "consent_without_a_terminal_is_no"
lib 'dot_consent "Install?" && echo YES || echo NO'
assert_contains "NO" "$OUT" "no terminal, no --yes: no"

test_start "consent_with_yes_is_yes"
YES=1 lib 'dot_consent "Install?" && echo YES || echo NO'
assert_contains "YES" "$OUT" "DOTFILES_YES=1 answers yes without asking"

test_start "yes_flag_sets_dotfiles_yes"
lib 'dot_apply_yes_flag codex --yes; echo "yes=$DOTFILES_YES"'
assert_contains "yes=1" "$OUT" "--yes anywhere in the arguments"

test_start "consent_at_a_terminal_reads_the_answer"
# A real pty: typed y is yes, typed n (or Enter) is no. CI is never asked.
tty_consent() {
  PREFLIGHT_INPUT="$1" "$REAL_PYTHON" - "$REAL_BASH" "$REPO_ROOT" <<'PY'
import errno, os, pty, sys
pid, fd = pty.fork()
if pid == 0:
    os.environ.update(NO_COLOR="1", DOTFILES_YES="0")
    os.environ.pop("CI", None)
    os.execv(sys.argv[1], [sys.argv[1], "-c",
        'source "$0/lib/dot/ui.sh"; source "$0/lib/dot/preflight.sh"; '
        'dot_consent "Install mise?" && echo ANSWER=yes || echo ANSWER=no', sys.argv[2]])
os.write(fd, os.environ["PREFLIGHT_INPUT"].encode())
out = b""
while True:
    try:
        data = os.read(fd, 4096)
    except OSError as exc:
        if exc.errno == errno.EIO:
            break
        raise
    if not data:
        break
    out += data
os.waitpid(pid, 0)
sys.stdout.write(out.decode(errors="replace"))
PY
}
assert_contains "ANSWER=yes" "$(tty_consent $'y\n')" "typed y is yes"
assert_contains "ANSWER=no" "$(tty_consent $'n\n')" "typed n is no"
assert_contains "ANSWER=no" "$(tty_consent $'\n')" "Enter alone is no"
assert_contains "[y/N]" "$(tty_consent $'\n')" "the default is shown as No"

# ── mise bootstrap ──────────────────────────────────────────────────────
test_start "mise_tag_comes_from_versions_env"
mkdir -p "$WORK/home/.config/dotfiles"
printf 'MISE_TAG="v2099.1.1"\n' >"$WORK/home/.config/dotfiles/versions.env"
lib '_dot_mise_tag'
assert_equals "v2099.1.1" "$OUT" "the deployed pin wins"
rm -f "$WORK/home/.config/dotfiles/versions.env"
lib '_dot_mise_tag'
assert_equals "v2026.3.8" "$OUT" "the built-in pin without it"

test_start "mise_asset_names_match_the_release"
stub uname 'case "$1" in -s) echo Darwin ;; -m) echo arm64 ;; esac'
lib '_dot_mise_asset'
assert_equals "mise-v2026.3.8-macos-arm64.tar.gz" "$OUT" "macOS arm64"
stub uname 'case "$1" in -s) echo Linux ;; -m) echo x86_64 ;; esac'
lib '_dot_mise_asset'
assert_equals "mise-v2026.3.8-linux-x64.tar.gz" "$OUT" "Linux x86_64"
rm -f "$STUBS/uname"

test_start "mise_install_method_prefers_brew"
stub brew
stub curl
lib 'dot_mise_install_method'
assert_equals "brew" "$OUT" "Homebrew when present"
rm -f "$STUBS/brew"
lib 'dot_mise_install_method'
assert_equals "release" "$OUT" "the verified release otherwise"
rm -f "$STUBS/curl"
lib 'dot_mise_install_method'
assert_equals "" "$OUT" "nothing without brew or curl"

test_start "mise_release_install_is_checksum_verified"
# The verified-download helper is replaced by a fake that records its
# arguments and writes a real tarball, so the extraction path is exercised.
mkdir -p "$WORK/pkg/mise/bin"
printf '#!%s\necho mise-fake\n' "$REAL_BASH" >"$WORK/pkg/mise/bin/mise"
tar -czf "$WORK/mise.tgz" -C "$WORK/pkg" mise
stub curl
lib 'download_verified_asset() { echo "verify $1 $2 $3" >>"$HOME/verify.log"; cp "'"$WORK"'/mise.tgz" "$4"; }
  _dot_install_mise_release && "$HOME/.local/bin/mise"'
assert_equals 0 "$RC" "installed"
assert_contains "mise-fake" "$OUT" "the release binary lands in ~/.local/bin"
assert_file_contains "$WORK/home/verify.log" "/SHASUMS256.txt" "verified against the published checksums"
rm -rf "$WORK/home/.local"

test_start "ensure_mise_unattended_changes_nothing"
stub brew
lib 'dot_ensure_mise "tools need it" && echo OK || echo DECLINED'
assert_contains "DECLINED" "$OUT" "no consent, no install"
assert_contains "not installed — tools need it" "$OUT" "says what and why"
assert_false "calls | grep -q 'brew install'" "brew is not run"

test_start "ensure_mise_with_yes_installs_via_brew"
stub brew 'printf "#!/bin/sh\n" >"'"$STUBS"'/mise"; chmod +x "'"$STUBS"'/mise"'
YES=1 lib 'dot_ensure_mise "tools need it" && echo OK || echo DECLINED'
assert_contains "OK" "$OUT" "installed with consent"
assert_contains "brew install mise" "$(calls)" "via Homebrew"
rm -f "$STUBS/brew" "$STUBS/mise"

# ── dot upgrade: questions first, then phases ──────────────────────────
test_start "upgrade_system_consent_unattended_is_no"
stub brew
lib 'dot_upgrade_prepare; echo "system=[$DOT_UPGRADE_SYSTEM]"'
assert_contains "system=[]" "$OUT" "no consent, no system upgrade"

test_start "upgrade_system_consent_with_yes_records_the_manager"
YES=1 lib 'stub_mise=1; dot_upgrade_prepare --yes; echo "system=[$DOT_UPGRADE_SYSTEM]"'
assert_contains "system=[brew]" "$OUT" "--yes includes system packages"

test_start "upgrade_system_needs_sudo_for_apt"
rm -f "$STUBS/brew"
stub apt-get
stub sudo 'exit 1'
YES=1 lib 'dot_upgrade_prepare; echo "rc=$? system=[$DOT_UPGRADE_SYSTEM]"'
assert_contains "rc=0 system=[]" "$OUT" "without cached sudo, apt is skipped unattended, and prepare still succeeds"
assert_contains "sudo is needed" "$OUT" "and says why"
rm -f "$STUBS/sudo" "$STUBS/apt-get"

test_start "system_upgrade_commands_per_manager"
stub brew
stub sudo
lib '_dot_upgrade_system brew; _dot_upgrade_system apt-get; _dot_upgrade_system dnf; _dot_upgrade_system pacman'
assert_contains "brew update" "$(calls)" "brew update"
assert_contains "brew upgrade" "$(calls)" "brew upgrade"
assert_contains "sudo -n env DEBIAN_FRONTEND=noninteractive apt-get -y upgrade" "$(calls)" "apt, non-interactive"
assert_contains "sudo -n dnf -y upgrade" "$(calls)" "dnf"
assert_contains "sudo -n pacman -Syu --noconfirm" "$(calls)" "pacman"
lib '_dot_upgrade_system zypper || echo REFUSED'
assert_contains "REFUSED" "$OUT" "an unknown manager is refused"
rm -f "$STUBS/brew" "$STUBS/sudo"

# A cask whose uninstall step runs sudo (a .pkg cask) fails `brew upgrade`
# when nobody can type the password. Warn before the phases run, and name
# what is left when it fails, instead of a bare "exited 1".
test_start "brew_casks_needing_sudo_are_named_up_front"
stub brew 'case "$*" in "outdated --cask --quiet") echo draft ;; esac'
stub sudo 'exit 1'
YES=1 lib 'dot_upgrade_prepare; echo "rc=$? system=[$DOT_UPGRADE_SYSTEM]"'
assert_contains "rc=0 system=[brew]" "$OUT" "brew formulae still upgrade unattended"
assert_contains "draft" "$OUT" "the outdated cask is named before the phases run"
assert_contains "sudo" "$OUT" "and the reason is given"

test_start "brew_casks_without_updates_need_no_warning"
stub brew
YES=1 lib 'dot_upgrade_prepare; echo "system=[$DOT_UPGRADE_SYSTEM]"'
assert_contains "system=[brew]" "$OUT" "brew is included"
assert_equals "0" "$(grep -c sudo <<<"$OUT")" "no outdated casks, no sudo warning"

test_start "brew_upgrade_failure_names_the_casks_left"
stub brew 'case "$*" in upgrade) exit 1 ;; "outdated --cask --quiet") echo draft ;; esac'
lib '_dot_upgrade_system brew; echo "rc=$?"'
assert_contains "rc=1" "$OUT" "the failure is still a failure"
assert_contains "draft" "$OUT" "the cask still outdated is named"
assert_contains "brew upgrade --cask draft" "$OUT" "with the command that finishes it"
stub brew 'case "$*" in upgrade) exit 1 ;; esac'
lib '_dot_upgrade_system brew; echo "rc=$?"'
assert_contains "rc=1" "$OUT" "a formula failure with no casks left is still a failure"
rm -f "$STUBS/brew" "$STUBS/sudo"

test_start "mise_phase_upgrades_from_home"
stub mise
lib '_dot_upgrade_mise; pwd'
assert_contains "mise install" "$(calls)" "missing tools installed"
assert_contains "mise upgrade" "$(calls)" "tools upgraded"
assert_false "calls | grep -q 'self-update'" "a package-managed mise is not self-updated"
assert_false "[[ \"\$OUT\" == \"\$WORK/home\" ]]" "the caller's directory is unchanged (subshell)"

test_start "mise_phase_self_updates_a_release_install"
mkdir -p "$WORK/home/.local/bin"
cp "$STUBS/mise" "$WORK/home/.local/bin/mise"
rm -f "$STUBS/mise"
lib 'PATH="$HOME/.local/bin:$PATH"; _dot_upgrade_mise'
assert_contains "mise self-update --yes" "$(calls)" "the dot-installed mise updates itself"
rm -rf "$WORK/home/.local"

test_start "toolchain_steps_render_skips_with_reasons"
stub brew
lib '_upgrade_step() { echo "STEP $1"; }; ui_step() { echo "SKIP $1 $4"; }
  DOT_UPGRADE_SYSTEM=""; dot_upgrade_toolchain_steps'
assert_contains "SKIP mise mise not installed" "$OUT" "no mise: a skip with how to get it"
assert_contains "SKIP system not requested" "$OUT" "no consent: a skip, not a failure"
stub mise
lib '_upgrade_step() { echo "STEP $1"; }; ui_step() { echo "SKIP $1 $4"; }
  DOT_UPGRADE_SYSTEM=brew; dot_upgrade_toolchain_steps'
assert_contains "STEP mise" "$OUT" "mise phase runs"
assert_contains "STEP system" "$OUT" "consented system phase runs"
rm -f "$STUBS/brew" "$STUBS/mise"

# ── dot ai provisioning ────────────────────────────────────────────────
test_start "ai_install_tool_statuses"
lib 'ai_install_tool definitely-not-a-tool; echo "rc=$?"'
assert_contains "rc=2" "$OUT" "no installer: 2"
lib 'ai_install_tool codex; echo "rc=$?"'
assert_contains "rc=2" "$OUT" "mise tool without mise: 2"
stub mise
lib 'ai_install_tool codex; echo "rc=$?"'
assert_contains "rc=0" "$OUT" "mise's own status decides"
stub mise 'exit 1'
lib 'ai_install_tool codex; echo "rc=$?"'
assert_contains "rc=1" "$OUT" "a failed mise install: 1"
rm -f "$STUBS/mise"

test_start "native_install_is_judged_by_the_result"
stub curl
lib 'install_goose_native() { :; }; ai_install_tool goose; echo "rc=$?"'
assert_contains "rc=1" "$OUT" "an installer that left no goose failed, whatever it returned"
lib 'install_goose_native() { mkdir -p "$HOME/.local/bin"; printf "#!/bin/sh\n" >"$HOME/.local/bin/goose"; chmod +x "$HOME/.local/bin/goose"; }
  ai_install_tool goose; echo "rc=$?"'
assert_contains "rc=0" "$OUT" "a goose in ~/.local/bin is a success"
rm -rf "$WORK/home/.local" "$STUBS/curl"

test_start "ai_prepare_reports_when_no_route_is_left"
lib 'ai_prepare goose codex; echo "rc=$?"'
assert_contains "rc=1" "$OUT" "no curl and no mise: nothing can install"
assert_contains "curl" "$OUT" "curl named"
stub curl
lib 'ai_prepare goose codex; echo "rc=$?"'
assert_contains "rc=0" "$OUT" "curl alone still installs the native tools"
rm -f "$STUBS/curl"

test_start "ai_doctor_prerequisite_rows"
stub mise
lib 'ai_prereq_rows'
assert_contains "installs most AI tools" "$OUT" "mise row"
assert_contains "missing — npm-based tools" "$OUT" "node reported missing with the fix"
rm -f "$STUBS/mise"

# ── failure paths: each must fail, not quietly succeed ──────────────────
test_start "consent_needs_an_answer_starting_with_y"
assert_contains "ANSWER=no" "$(tty_consent $'ny\n')" "an answer that merely contains y is no"

test_start "mise_asset_refuses_unsupported_platforms"
stub uname 'case "$1" in -s) echo FreeBSD ;; -m) echo x86_64 ;; esac'
lib '_dot_mise_asset; echo "rc=$?"'
assert_equals "rc=1" "$OUT" "an OS mise ships no build for"
stub uname 'case "$1" in -s) echo Linux ;; -m) echo sparc64 ;; esac'
lib '_dot_mise_asset; echo "rc=$?"'
assert_equals "rc=1" "$OUT" "a CPU mise ships no build for"
stub curl
lib 'download_verified_asset() { echo called >>"$HOME/dl.log"; }; _dot_install_mise_release; echo "rc=$?"'
assert_contains "rc=1" "$OUT" "the release install fails without an asset"
assert_file_not_exists "$WORK/home/dl.log" "and downloads nothing"
rm -f "$STUBS/uname" "$STUBS/curl"

test_start "mise_install_failures_are_failures"
lib 'dot_install_mise; echo "rc=$?"'
assert_contains "rc=1" "$OUT" "no way to install mise"
stub brew 'exit 1'
lib 'dot_install_mise; echo "rc=$?"'
assert_contains "rc=1" "$OUT" "brew install failing"
YES=1 lib 'dot_ensure_mise "tools need it"; echo "rc=$?"'
assert_contains "rc=1" "$OUT" "ensure reports the failure"
assert_contains "install failed" "$OUT" "and says so"
rm -f "$STUBS/brew"

test_start "upgrade_without_any_package_manager"
lib 'dot_upgrade_system_pm; echo "rc=$?"'
assert_equals "rc=1" "$OUT" "no package manager found"
YES=1 lib 'dot_upgrade_prepare --yes; echo "rc=$? system=[$DOT_UPGRADE_SYSTEM]"'
assert_contains "rc=0 system=[]" "$OUT" "prepare still succeeds (cmd_upgrade runs under set -e)"

test_start "mise_phase_needs_a_home"
stub mise
lib 'HOME=/nonexistent/dot-home; _dot_upgrade_mise; echo "rc=$?"'
assert_contains "rc=1" "$OUT" "an unusable HOME fails the phase"
assert_false "calls | grep -q 'mise '" "and runs no mise command"
rm -f "$STUBS/mise"

test_start "ai_install_method_reports_no_installer"
lib 'ai_install_method definitely-not-a-tool; echo "rc=$?"'
assert_equals "rc=1" "$OUT" "no installer: status 1, no output"
lib 'ai_install_method claude; echo " rc=$?"'
assert_equals "native:install_claude_native rc=0" "$OUT" "native: status 0"
lib 'ai_install_method codex; echo " rc=$?"'
assert_equals "mise:npm:@openai/codex rc=0" "$OUT" "mise: status 0"

test_start "native_install_without_curl_is_skipped"
lib 'install_goose_native() { echo RAN; }; ai_install_tool goose; echo "rc=$?"'
assert_contains "rc=2" "$OUT" "no curl: skipped, not success"
assert_false "[[ \"\$OUT\" == *RAN* ]]" "the installer is not run"

test_start "native_only_installs_do_not_offer_mise"
stub curl
lib 'ai_prepare goose claude; echo "rc=$?"'
assert_contains "rc=0" "$OUT" "native tools with curl are ready"
assert_false "[[ \"\$OUT\" == *mise* ]]" "mise is not mentioned for native-only tools"
rm -f "$STUBS/curl"

printf 'RESULTS:%s:%s:%s\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
