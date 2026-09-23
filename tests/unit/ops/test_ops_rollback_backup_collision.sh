#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Backup names have one-second resolution. Two backups in the same second
# (a rollback's own pre_rollback safety copy, say) must land in different
# directories, or the second overwrites the backup being restored.
#
# The collision is forced, not hoped for: a `date` stub pins the timestamp.
# Expected contents are fixed values written by this test, never read back
# from the backup directory under test.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

ROLLBACK="$REPO_ROOT/scripts/ops/rollback.sh"
WORK="$(mktemp -d -t rb-collide.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

REAL_DATE="$(command -v date)"
mkdir -p "$WORK/stubs" "$WORK/home" "$WORK/run"
cat >"$WORK/stubs/date" <<STUB
#!/bin/sh
case "\$*" in
  *%Y%m%d_%H%M%S*) echo 20260101_000000 ;;
  *) exec "$REAL_DATE" "\$@" ;;
esac
STUB
printf '#!/bin/sh\nexit 0\n' >"$WORK/stubs/chezmoi"
chmod +x "$WORK/stubs/date" "$WORK/stubs/chezmoi"

rb() {
  HOME="$WORK/home" XDG_DATA_HOME="$WORK/home/.local/share" \
    XDG_STATE_HOME="$WORK/home/.local/state" XDG_RUNTIME_DIR="$WORK/run" \
    PATH="$WORK/stubs:$PATH" bash "$ROLLBACK" "$@" </dev/null >"$WORK/out" 2>&1
}
backups() { find "$WORK/home/.local/share/dotfiles/backups" -maxdepth 1 -type d -name 'backup_*' | sort; }

test_start "rollback_same_second_backups_get_distinct_dirs"
printf 'v1\n' >"$WORK/home/.bashrc"
rb backup
printf 'v2\n' >"$WORK/home/.bashrc"
rb backup
assert_equals "2" "$(backups | wc -l | tr -d ' ')" "two backups in the same second are two directories"

test_start "rollback_first_backup_not_overwritten"
first="$(backups | head -n 1)"
assert_equals "v1" "$(cat "$first/.bashrc")" "the earlier backup still holds v1"

test_start "rollback_restores_the_chosen_backup_despite_collision"
# `rollback` restores the latest backup (v2) and, in the same second, writes
# a pre_rollback safety copy of the current state (v3). v2 must be restored.
printf 'v3\n' >"$WORK/home/.bashrc"
rb rollback --force
assert_equals "v2" "$(cat "$WORK/home/.bashrc")" "the latest backup, not the safety copy, is restored"

test_start "rollback_safety_copy_is_a_third_dir"
assert_equals "3" "$(backups | wc -l | tr -d ' ')" "the safety copy did not reuse an existing directory"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
