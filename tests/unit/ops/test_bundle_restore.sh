#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# `dot config import <bundle>` (plugins/config/dot-config, then
# scripts/ops/bundle-restore.sh) restores a bundle `dot config export`
# wrote: it asks first (--yes skips the question), and it refuses a file
# that is not such a bundle, or one with a member outside the paths export
# writes for this home. Each case builds real bundles in a sandbox HOME.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

BUNDLE_SH="$REPO_ROOT/scripts/ops/bundle.sh"
ENTRY="$REPO_ROOT/plugins/config/dot-config"
# The sandbox path with symlinks resolved: restore extracts without -P, and
# bsdtar refuses to extract through a symlink, which macOS's TMPDIR under
# /var (-> /private/var) would put in every member's path.
WORK="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/dot-bundle-restore.XXXXXX")" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT

if ! command -v zstd >/dev/null 2>&1 || ! tar --zstd --version >/dev/null 2>&1; then
  echo "  tar --zstd unavailable: skipped"
  echo "RESULTS:0:0:0"
  exit 0
fi

TOOLS_PATH="$(dirname "$(command -v zstd)"):$(dirname "$(command -v tar)"):/usr/bin:/bin"
H="$WORK/home"

# in_sandbox CMD...: run CMD with an emptied environment and HOME=$H; sets
# OUT and RC. stdin is not a terminal, so nothing can be asked.
in_sandbox() {
  RC=0
  OUT="$(cd "$WORK" && env -i ${BASH_ENV:+BASH_ENV="$BASH_ENV"} ${PS4:+PS4="$PS4"} \
    HOME="$H" XDG_RUNTIME_DIR="$WORK" XDG_STATE_HOME="$H/.local/state" \
    XDG_CONFIG_HOME="$H/.config" DOTFILES_SHOW_LOGO=0 \
    PATH="$TOOLS_PATH" TERM=dumb NO_COLOR=1 "$@" 2>&1 </dev/null)" || RC=$?
}

mkdir -p "$H/.dotfiles/defaults" "$H/.config/chezmoi" "$H/.local/share/mise/installs"
printf 'original\n' >"$H/.dotfiles/defaults/file"
printf 'sourceDir = "~/.dotfiles"\n' >"$H/.config/chezmoi/chezmoi.toml"
printf 'tool\n' >"$H/.local/share/mise/installs/tool"
in_sandbox bash "$BUNDLE_SH" "$WORK/out"
BUNDLE="$(ls "$WORK"/out/*.tar.zst)"

test_start "import_without_consent_changes_nothing"
printf 'edited\n' >"$H/.dotfiles/defaults/file"
in_sandbox bash "$ENTRY" import "$BUNDLE"
assert_equals "1" "$RC" "no terminal and no --yes: exits 1"
assert_contains "Overwrites: $H/.dotfiles" "$OUT" "the prompt names what it overwrites"
assert_equals "edited" "$(cat "$H/.dotfiles/defaults/file")" "the file is untouched"

test_start "import_yes_restores_the_bundle"
rm -f "$H/.local/share/mise/installs/tool"
in_sandbox bash "$ENTRY" import "$BUNDLE" --yes
assert_equals "0" "$RC" "import --yes exits 0"
assert_equals "original" "$(cat "$H/.dotfiles/defaults/file")" "the source file is restored"
assert_equals "tool" "$(cat "$H/.local/share/mise/installs/tool" 2>/dev/null)" "mise's data is restored"
assert_equals "0" "$(find "$WORK" -maxdepth 1 -name restore | wc -l | tr -d ' ')" "no ./restore bundle is built"

test_start "import_refuses_a_non_bundle"
printf 'not a bundle\n' >"$WORK/junk.tar.zst"
in_sandbox bash "$ENTRY" import "$WORK/junk.tar.zst" --yes
assert_equals "1" "$RC" "an unreadable archive is refused"
in_sandbox bash "$ENTRY" import "$WORK/missing.tar.zst" --yes
assert_equals "1" "$RC" "a missing file is refused"
in_sandbox bash "$ENTRY" import
assert_equals "2" "$RC" "no bundle is a usage error"

test_start "import_refuses_a_member_outside_export_paths"
mkdir -p "$H/.ssh"
printf 'planted\n' >"$H/.ssh/authorized_keys"
tar --zstd -cf "$WORK/evil.tar.zst" -P "$H/.dotfiles" "$H/.ssh/authorized_keys" 2>/dev/null
printf 'mine\n' >"$H/.ssh/authorized_keys"
in_sandbox bash "$ENTRY" import "$WORK/evil.tar.zst" --yes
assert_equals "1" "$RC" "a bundle reaching outside is refused"
assert_contains "$H/.ssh/authorized_keys" "$OUT" "the refusal names the member"
assert_equals "mine" "$(cat "$H/.ssh/authorized_keys")" "nothing outside is written"

test_start "import_refuses_another_homes_bundle"
H="$WORK/other"
mkdir -p "$H"
in_sandbox bash "$ENTRY" import "$BUNDLE" --yes
assert_equals "1" "$RC" "a bundle of another home is refused"
assert_equals "0" "$(find "$H" -mindepth 1 | wc -l | tr -d ' ')" "nothing is extracted"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
