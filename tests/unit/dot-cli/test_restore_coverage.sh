#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC2034
# Behavioural coverage for scripts/dot/commands/restore.sh branches the
# other suites skip: the chezmoi-source fallback (no $DOTFILES_DIR/.git),
# the missing-repo error of --diff, a restore without chezmoi on PATH, and
# the BSD `stat -f %m` mtime fallback. Everything runs in a mktemp sandbox
# with PATH-shadowed git/chezmoi/stat stubs; nothing outside it is touched.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
# shellcheck source=../../framework/assertions.sh
source "$REPO_ROOT/tests/framework/assertions.sh"

RESTORE="$REPO_ROOT/scripts/dot/commands/restore.sh"
REAL_BASH="${BASH:-$(command -v bash)}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/restore-cov.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
BIN="$WORK/bin"
NOCZ_BIN="$WORK/bin-nochezmoi"
STAT_BIN="$WORK/bin-bsdstat"
mkdir -p "$BIN" "$NOCZ_BIN" "$STAT_BIN"
CALLS="$WORK/calls"
OUT="$WORK/out"

cat >"$BIN/git" <<EOF
#!$REAL_BASH
printf 'git %s\n' "\$*" >>"$CALLS"
case "\$*" in
  *log*) printf 'def5678 chezmoi-source commit\n' ;;
esac
exit 0
EOF
cat >"$BIN/chezmoi" <<EOF
#!$REAL_BASH
printf 'chezmoi %s\n' "\$*" >>"$CALLS"
exit 0
EOF
cp "$BIN/git" "$NOCZ_BIN/git"
# BSD-style stat: GNU `-c` is rejected so restore.sh must fall back to -f %m.
cat >"$STAT_BIN/stat" <<EOF
#!$REAL_BASH
[[ "\$1" == "-c" ]] && exit 1
printf 'stat %s\n' "\$*" >>"$CALLS"
case "\$3" in
  *backup-old) echo 100 ;;
  *) echo 200 ;;
esac
EOF
chmod +x "$BIN"/* "$NOCZ_BIN"/* "$STAT_BIN"/*

# run_restore <home> <path-prefix> <args...> — prints rc.
run_restore() {
  local home="$1" pre="$2" rc=0
  shift 2
  PATH="$pre:/usr/bin:/bin" HOME="$home" \
    XDG_DATA_HOME="$home/.local/share" XDG_STATE_HOME="$home/.local/state" \
    DOTFILES_DIR="$home/.dotfiles" \
    "$REAL_BASH" "$RESTORE" "$@" </dev/null >"$OUT" 2>&1 || rc=$?
  printf '%s' "$rc"
}

new_home() {
  local h="$WORK/home-$1"
  mkdir -p "$h/.local/share" "$h/.local/state"
  printf '%s' "$h"
}

test_start "list_falls_back_to_chezmoi_source_git_history"
H="$(new_home list)"
mkdir -p "$H/.local/share/dotfiles/backups/backup-1" "$H/.local/share/chezmoi/.git"
: >"$CALLS"
rc="$(run_restore "$H" "$BIN" --list)"
assert_equals "0" "$rc" "--list exits 0"
assert_file_contains "$OUT" "def5678 chezmoi-source commit" "git history comes from chezmoi source"
assert_file_contains "$CALLS" "git -C $H/.local/share/chezmoi log --oneline -10" "log runs in chezmoi source"

test_start "git_restore_uses_chezmoi_source_without_chezmoi_binary"
H="$(new_home gitsrc)"
mkdir -p "$H/.local/share/chezmoi/.git" "$H/.config/git"
printf 'x\n' >"$H/.zshrc"
printf 'y\n' >"$H/.config/git/config"
: >"$CALLS"
rc="$(run_restore "$H" "$NOCZ_BIN" --git v1)"
assert_equals "0" "$rc" "--git exits 0"
assert_file_contains "$CALLS" "git -C $H/.local/share/chezmoi checkout v1 -- ." "checkout runs in chezmoi source"
assert_output_not_contains "Re-applying chezmoi" "cat '$OUT'"
bk="$(find "$H/.local/share/dotfiles/backups" -name .zshrc | head -1)"
assert_not_empty "$bk" "existing .zshrc is backed up"
bk="$(find "$H/.local/share/dotfiles/backups" -path '*/.config/git/config' | head -1)"
assert_not_empty "$bk" "nested config directory is backed up"

test_start "diff_uses_chezmoi_source"
H="$(new_home diffsrc)"
mkdir -p "$H/.local/share/chezmoi/.git"
: >"$CALLS"
rc="$(run_restore "$H" "$BIN" -d HEAD)"
assert_equals "0" "$rc" "-d exits 0"
assert_file_contains "$CALLS" "git -C $H/.local/share/chezmoi diff HEAD" "diff runs in chezmoi source"

test_start "diff_without_repository_fails"
H="$(new_home diffnone)"
rc="$(run_restore "$H" "$BIN" --diff HEAD)"
assert_equals "1" "$rc" "--diff with no repo exits 1"
assert_file_contains "$OUT" "No git repository found" "error names the cause"

test_start "latest_without_backup_dir_fails"
H="$(new_home nobackups)"
rc="$(run_restore "$H" "$BIN" --latest)"
assert_equals "1" "$rc" "--latest with no backup dir exits 1"
assert_file_contains "$OUT" "No backups found" "empty state reported"

test_start "latest_orders_backups_via_bsd_stat_fallback"
H="$(new_home bsdstat)"
B="$H/.local/share/dotfiles/backups"
mkdir -p "$B/backup-old" "$B/backup-new"
printf 'new\n' >"$B/backup-new/.zshrc"
printf 'old\n' >"$B/backup-old/.zshrc"
: >"$CALLS"
rc="$(run_restore "$H" "$STAT_BIN:$BIN" --latest)"
assert_equals "0" "$rc" "--latest exits 0"
assert_file_contains "$CALLS" "stat -f %m" "BSD stat form is used"
assert_file_contains "$OUT" "Restoring from: backup-new" "newest mtime wins"
assert_file_contains "$H/.zshrc" "new" "newest backup content restored"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
