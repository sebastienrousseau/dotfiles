#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Behaviour tests for scripts/theme/install-grub-theme.sh.
#
# The script hard-codes /boot/grub/themes and /etc/default/grub and only
# writes after an EUID==0 check, so it is sourced in a subshell where
# every tool it touches is a recording shell function (uname, mkdir, cp,
# grep, sed, update-grub, grub-mkconfig) and PATH points at an empty
# directory — nothing real can run. The one write that is a shell
# redirection (`echo … >>/etc/default/grub`) is neutralised by the grep
# stub lowering the soft fd limit to 3 first: the open() then fails with
# EMFILE before the file can be created. A probe checks that guarantee
# before that case runs. Root-only cases are skipped when not root.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

SCRIPT="$REPO_ROOT/scripts/theme/install-grub-theme.sh"

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/grub-cov.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home"
EMPTY="$SANDBOX/empty-path"
THEME="$SANDBOX/theme"
LOG="$SANDBOX/calls.log"
mkdir -p "$HOME" "$EMPTY" "$THEME"
: >"$THEME/theme.txt"
unset DOTFILES_GRUB_THEME_NAME

# _grub <uname> <grep-rc> <sed-gnu:0|1> <update-grub|grub-mkconfig|none> [args…]
_grub() {
  local os="$1" grep_rc="$2" sed_gnu="$3" updater="$4"
  shift 4
  (
    uname() { echo "$os"; }
    mkdir() { echo "mkdir $*" >>"$LOG"; }
    cp() { echo "cp $*" >>"$LOG"; }
    grep() {
      echo "grep $*" >>"$LOG"
      # Before the append-redirect arm, make any new open() fail.
      [[ "$grep_rc" == 0 ]] || ulimit -Sn 3
      return "$grep_rc"
    }
    sed() {
      if [[ "${1:-}" == "--version" ]]; then
        [[ "$sed_gnu" == 1 ]]
        return
      fi
      echo "sed $*" >>"$LOG"
    }
    case "$updater" in
      update-grub) update-grub() { echo "update-grub" >>"$LOG"; } ;;
      grub-mkconfig) grub-mkconfig() { echo "grub-mkconfig $*" >>"$LOG"; } ;;
    esac
    PATH="$EMPTY"
    source "$SCRIPT" "$@"
  ) 2>&1
}

test_start "non_linux_is_a_no_op"
out="$(_grub Darwin 0 1 none --apply)"
assert_equals "0" "$?" "exits 0"
assert_contains "GRUB theming is Linux-only." "$out" "explains"

test_start "missing_theme_dir"
out="$(DOTFILES_GRUB_THEME_DIR="$SANDBOX/nope" _grub Linux 0 1 none --apply)"
assert_equals "1" "$?" "exits 1"
assert_contains "Theme directory not found: $SANDBOX/nope" "$out" "names dir"
assert_contains "set DOTFILES_GRUB_THEME_DIR" "$out" "override hint"

test_start "default_theme_dir_under_home"
out="$(unset DOTFILES_GRUB_THEME_DIR && _grub Linux 0 1 none)"
assert_contains "Theme directory not found: $HOME/.config/dotfiles/grub/theme" "$out" "HOME default"

export DOTFILES_GRUB_THEME_DIR="$THEME"

test_start "dry_run_by_default"
: >"$LOG"
out="$(_grub Linux 0 1 update-grub --other-flag)"
assert_equals "0" "$?" "exits 0"
assert_contains "Dry run. Use --apply" "$out" "dry run message"
assert_equals "" "$(cat "$LOG")" "nothing touched"

if [[ $EUID -ne 0 ]]; then
  test_start "apply_requires_root"
  : >"$LOG"
  out="$(_grub Linux 0 1 update-grub --apply)"
  assert_equals "1" "$?" "exits 1"
  assert_contains "Please run with sudo" "$out" "asks for sudo"
  assert_equals "" "$(cat "$LOG")" "nothing touched"
else
  test_start "apply_replaces_theme_line_gnu_sed_update_grub"
  : >"$LOG"
  out="$(DOTFILES_GRUB_THEME_NAME=covtheme _grub Linux 0 1 update-grub --apply)"
  assert_equals "0" "$?" "exits 0"
  log="$(cat "$LOG")"
  assert_contains "mkdir -p /boot/grub/themes/covtheme" "$log" "theme dir created (stub)"
  assert_contains "cp -R $THEME/. /boot/grub/themes/covtheme" "$log" "theme copied (stub)"
  assert_contains "sed -i s|^GRUB_THEME=.*|GRUB_THEME=\"/boot/grub/themes/covtheme/theme.txt\"| /etc/default/grub" "$log" "GNU in-place edit"
  assert_contains "update-grub" "$log" "update-grub preferred"
  assert_contains "GRUB theme installed: /boot/grub/themes/covtheme" "$out" "success message"

  test_start "apply_bsd_sed_and_grub_mkconfig"
  : >"$LOG"
  out="$(_grub Linux 0 0 grub-mkconfig --apply)"
  assert_equals "0" "$?" "exits 0"
  log="$(cat "$LOG")"
  assert_contains "sed -i  s|^GRUB_THEME=" "$log" "BSD in-place edit with empty suffix"
  assert_contains "grub-mkconfig -o /boot/grub/grub.cfg" "$log" "grub-mkconfig fallback"

  test_start "apply_appends_theme_line_without_writing"
  probe="$SANDBOX/fd-probe"
  (
    ulimit -Sn 3
    echo x >>"$probe"
  ) 2>/dev/null
  if [[ -e "$probe" || -e /etc/default/grub ]]; then
    assert_true "true" "skipped: cannot guarantee the append is blocked here"
  else
    : >"$LOG"
    out="$(_grub Linux 1 1 none --apply)"
    assert_equals "1" "$?" "append attempt fails under the fd limit"
    assert_contains "Too many open files" "$out" "redirect refused before open"
    assert_contains "grep -q ^GRUB_THEME= /etc/default/grub" "$(cat "$LOG")" "probed for an existing line"
    assert_false "[[ -e /etc/default/grub ]]" "/etc/default/grub was not created"
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
    out="$(DOTFILES_GRUB_THEME_DIR="$THEME" setpriv --reuid=nobody --regid="$(id -g nobody)" --clear-groups \
      bash "$SCRIPT" --apply 2>&1)"
    assert_equals "1" "$?" "exits 1 when not root"
    assert_contains "Please run with sudo for GRUB theme install." "$out" "asks for sudo"
  else
    assert_true "true" "skipped: setpriv unavailable"
  fi
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
