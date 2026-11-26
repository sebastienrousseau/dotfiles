#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# The environment install.sh applies the dotfiles in. It runs under umask
# 077 for its own files (chezmoi config, keys,
# temp files), but applies the dotfiles under 022, the umask their shells
# set (defaults/dot_profile). chezmoi derives each target's mode from the
# umask, so an apply under 077 wrote every file 0600, and one under a
# caller's 002 (Ubuntu's per-user groups) wrote 0664: either way every
# later `chezmoi status` or `dot doctor` from a dotfiles shell (022) saw
# all of them drifted. Drill A1 found 551 such entries on a fresh Ubuntu.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$REPO_ROOT/tests/framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/install-umask-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# A caller umask unlike the dotfiles' own, then the installer as sourced.
umask 002
source "$REPO_ROOT/install.sh"

test_start "installer_keeps_077_for_its_own_files"
assert_equals "0077" "$(umask)" "install.sh itself runs under umask 077"

# Stubs: each chezmoi call logs "<umask> DOTFILES_AI=<value> <args>"; no
# git identity work.
chezmoi() { printf '%s DOTFILES_AI=%s %s\n' "$(umask)" "${DOTFILES_AI:-unset}" "$*" >>"$WORK/chezmoi.log"; }
seed_git_identity() { :; }
unset DOTFILES_AI

test_start "dotfiles_apply_under_the_dotfiles_umask"
apply_source 0
assert_equals "0022 DOTFILES_AI=1 apply" "$(cat "$WORK/chezmoi.log" 2>/dev/null)" \
  "chezmoi apply runs under 022 (not the caller's 002 or the installer's 077) and DOTFILES_AI=1"
assert_equals "0077" "$(umask)" "and the installer's own umask is unchanged afterwards"

# --provision installs tools that templates look for (go, for the Go
# builds): the dotfiles are applied again afterwards, so nothing is left
# pending for the next `dot doctor`.
mkdir -p "$WORK/src/install/lib"
printf 'run_provision() { echo provisioned >>"%s/chezmoi.log"; }\n' "$WORK" >"$WORK/src/install/lib/provision.sh"
SOURCE_DIR="$WORK/src"

test_start "provisioning_is_followed_by_an_apply"
: >"$WORK/chezmoi.log"
provision_toolchain 1 0 "" >/dev/null
# --force: since the first apply only provisioning ran, so a managed file
# changed since then was changed by a vendor installer (a PATH line in
# .bashrc), and chezmoi stopped to ask with no terminal ("could not open a
# new TTY"; drill A1). The dotfiles own those files.
assert_equals $'provisioned\n0022 DOTFILES_AI=1 apply --force' "$(cat "$WORK/chezmoi.log")" \
  "after provisioning, chezmoi applies once more, in the same environment, restoring managed files"

test_start "no_provisioning_no_second_apply"
: >"$WORK/chezmoi.log"
provision_toolchain 0 0 "" >/dev/null
assert_equals "" "$(cat "$WORK/chezmoi.log")" "without --provision nothing runs"

# The umask the deployed shells end up with: dot_profile, sourced in a
# clean subshell from the caller's 002.
test_start "the_apply_umask_is_the_one_dot_profile_sets"
mkdir -p "$WORK/home"
cat >"$WORK/probe.sh" <<'EOF'
umask 002
. "$1" >/dev/null 2>&1
umask
echo "DOTFILES_AI=${DOTFILES_AI:-unset}"
EOF
profile_umask="$(env -i HOME="$WORK/home" PATH="/usr/bin:/bin" bash --noprofile --norc \
  "$WORK/probe.sh" "$REPO_ROOT/defaults/dot_profile")"
assert_equals "$DOTFILES_APPLY_UMASK"$'\nDOTFILES_AI=1' "$profile_umask" \
  "defaults/dot_profile sets the umask and DOTFILES_AI install.sh applies under"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
