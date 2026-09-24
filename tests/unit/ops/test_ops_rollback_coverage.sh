#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# `rollback.sh status` when the backup directory disappears between the
# dispatcher's ensure_dirs and the listing (another process cleaning up,
# a user deleting it): the status report must say so and still exit 0.
#
# Sandbox HOME with no ~/.dotfiles at all (not cov_setup_sandbox, which
# links the real repo there). The only command stubbed is chezmoi, whose
# `status` call is the moment the directory is removed.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

ROLLBACK="$REPO_ROOT/scripts/ops/rollback.sh"
WORK="$(mktemp -d -t rb-cov.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

HOME_DIR="$WORK/home"
DATA="$HOME_DIR/.local/share"
mkdir -p "$HOME_DIR" "$WORK/bin" "$WORK/run"
cat >"$WORK/bin/chezmoi" <<EOF
#!/bin/sh
case "\$1" in
  --version) echo "chezmoi version v0.0.0-stub" ;;
  status) rm -rf "$DATA/dotfiles/backups" ;;
esac
exit 0
EOF
chmod +x "$WORK/bin/chezmoi"

test_start "rollback_status_reports_vanished_backup_directory"
RC=0
OUT="$(HOME="$HOME_DIR" XDG_DATA_HOME="$DATA" XDG_STATE_HOME="$HOME_DIR/.local/state" \
  XDG_CONFIG_HOME="$HOME_DIR/.config" XDG_CACHE_HOME="$HOME_DIR/.cache" \
  XDG_RUNTIME_DIR="$WORK/run" PATH="$WORK/bin:$PATH" NO_COLOR=1 \
  "${BASH:-bash}" "$ROLLBACK" status 2>&1 </dev/null)" || RC=$?
assert_equals 0 "$RC" "status still exits 0"
assert_contains "Chezmoi: All files in sync" "$OUT" "chezmoi section ran"
assert_contains "No backup directory found" "$OUT" "vanished directory reported"
assert_false "[[ -e '$HOME_DIR/.dotfiles' ]]" "no dotfiles source was created"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" == 0 ]]
