#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Behaviour tests for scripts/theme/install-boot-logo.sh.
#
# The script hard-codes /usr/share/plymouth/themes/dotfiles and only
# writes after an EUID==0 check, so it is sourced in a subshell where
# uname, mkdir, cp and plymouth-set-default-theme are recording shell
# functions and PATH points at an empty directory. Its two heredoc
# writes are shell redirections: the cp stub (the last step before them)
# lowers the soft fd limit to 3 so both open() calls fail with EMFILE
# before anything is created,
# and the plymouth stub restores it. The subshell runs on the left of
# `||`, where errexit is suspended, so the arms after the refused writes
# still execute and are asserted. A probe checks the fd-limit guarantee
# first. Root-only cases are skipped when not root.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

SCRIPT="$REPO_ROOT/scripts/theme/install-boot-logo.sh"
THEME_DIR=/usr/share/plymouth/themes/dotfiles

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/bootlogo-cov.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home"
EMPTY="$SANDBOX/empty-path"
LOGO="$SANDBOX/logo.png"
LOG="$SANDBOX/calls.log"
mkdir -p "$HOME" "$EMPTY"
printf 'PNG' >"$LOGO"
ORIG_NOFILE="$(ulimit -Sn)"

# _boot <uname> <plymouth:0|1> [args…]
_boot() {
  local os="$1" plymouth="$2"
  shift 2
  (
    uname() { echo "$os"; }
    mkdir() { echo "mkdir $*" >>"$LOG"; }
    cp() {
      echo "cp $*" >>"$LOG"
      ulimit -Sn 3
    }
    if [[ "$plymouth" == 1 ]]; then
      plymouth-set-default-theme() {
        ulimit -Sn "$ORIG_NOFILE"
        echo "plymouth-set-default-theme $*" >>"$LOG"
      }
    fi
    PATH="$EMPTY"
    source "$SCRIPT" "$@"
  ) 2>&1 || echo "rc=$?"
}

test_start "non_linux_is_a_no_op"
out="$(_boot Darwin 1 --apply)"
assert_contains "Boot logo customization is Linux-only." "$out" "explains"
assert_false "[[ '$out' == *rc=* ]]" "exits 0"

test_start "missing_logo"
out="$(DOTFILES_BOOT_LOGO="$SANDBOX/none.png" _boot Linux 1 --apply)"
assert_contains "Boot logo not found: $SANDBOX/none.png" "$out" "names the logo"
assert_contains "set DOTFILES_BOOT_LOGO" "$out" "override hint"
assert_contains "rc=1" "$out" "exits 1"

test_start "default_logo_under_home"
out="$(unset DOTFILES_BOOT_LOGO && _boot Linux 1)"
assert_contains "Boot logo not found: $HOME/.config/dotfiles/boot/logo.png" "$out" "HOME default"

export DOTFILES_BOOT_LOGO="$LOGO"

test_start "dry_run_by_default"
: >"$LOG"
out="$(_boot Linux 1 --verbose)"
assert_contains "Dry run. Use --apply" "$out" "dry run message"
assert_false "[[ '$out' == *rc=* ]]" "exits 0"
assert_equals "" "$(cat "$LOG")" "nothing touched"

if [[ $EUID -ne 0 ]]; then
  test_start "apply_requires_root"
  : >"$LOG"
  out="$(_boot Linux 1 --apply)"
  assert_contains "Please run with sudo" "$out" "asks for sudo"
  assert_contains "rc=1" "$out" "exits 1"
  assert_equals "" "$(cat "$LOG")" "nothing touched"
else
  test_start "apply_without_plymouth"
  : >"$LOG"
  out="$(_boot Linux 0 --apply)"
  assert_contains "Plymouth not found" "$out" "install hint"
  assert_contains "rc=1" "$out" "exits 1"
  assert_equals "" "$(cat "$LOG")" "nothing touched"

  test_start "apply_with_plymouth"
  probe="$SANDBOX/fd-probe"
  (
    ulimit -Sn 3
    echo x >"$probe"
  ) 2>/dev/null
  if [[ -e "$probe" || -e "$THEME_DIR" ]]; then
    assert_true "true" "skipped: cannot guarantee the theme writes are blocked here"
  else
    : >"$LOG"
    out="$(_boot Linux 1 --apply)"
    log="$(cat "$LOG")"
    assert_contains "mkdir -p $THEME_DIR" "$log" "theme dir created (stub)"
    assert_contains "cp $LOGO $THEME_DIR/logo.png" "$log" "logo copied (stub)"
    assert_contains "Too many open files" "$out" "theme file writes refused"
    assert_contains "plymouth-set-default-theme -R dotfiles" "$log" "theme activated with initramfs rebuild"
    assert_contains "Boot logo installed via Plymouth." "$out" "success message"
    assert_false "[[ -e $THEME_DIR ]]" "no theme directory created"
  fi
fi

# The non-root refusal. Unprivileged hosts hit it above; as root it is
# reached by dropping to nobody with setpriv (Linux). The coverage
# trace descriptor is exported so the unprivileged child can still
# write its xtrace records to the already-open file.
if [[ $EUID -eq 0 ]]; then
  test_start "apply_refused_for_non_root"
  if command -v setpriv >/dev/null 2>&1 && id nobody >/dev/null 2>&1; then
    chmod 755 "$SANDBOX"
    [[ -n "${BASH_XTRACEFD:-}" ]] && export BASH_XTRACEFD
    out="$(DOTFILES_BOOT_LOGO="$LOGO" setpriv --reuid=nobody --regid="$(id -g nobody)" --clear-groups \
      bash "$SCRIPT" --apply 2>&1)"
    assert_equals "1" "$?" "exits 1 when not root"
    assert_contains "Please run with sudo for boot logo install." "$out" "asks for sudo"
  else
    assert_true "true" "skipped: setpriv unavailable"
  fi
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
