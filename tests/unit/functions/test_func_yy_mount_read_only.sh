#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# yy (cd to where yazi was left) and mount_read_only (attach a disk image
# with a private shadow file), run with stubbed yazi and hdiutil.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

FUNCS="$REPO_ROOT/defaults/.chezmoitemplates/functions"
WORK="$(mktemp -d -t dot-yy-mount.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/target"

# yazi stub: writes the directory it "was left in" to --cwd-file.
cat >"$WORK/bin/yazi" <<'STUB'
#!/usr/bin/env bash
for a in "$@"; do
  case "$a" in --cwd-file=*) printf '%s' "${YAZI_LEFT_IN:-}" >"${a#--cwd-file=}" ;; esac
done
STUB
# hdiutil stub: records its arguments and whether the shadow file exists.
cat >"$WORK/bin/hdiutil" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >"$WORK/hdiutil.args"
shadow="\${4:-}"
ls -l "\$shadow" 2>/dev/null | cut -c1-10 >"$WORK/shadow.mode"
STUB
chmod +x "$WORK/bin/yazi" "$WORK/bin/hdiutil"

test_start "yy_changes_to_where_yazi_was_left"
out="$(cd "$WORK" && PATH="$WORK/bin:$PATH" YAZI_LEFT_IN="$WORK/target" \
  bash -c 'source "$1"; yy; pwd' _ "$FUNCS/utils/yazi.sh")"
assert_equals "$(cd "$WORK/target" && pwd)" "$out" "the shell ends up in yazi's directory"

test_start "yy_stays_put_when_yazi_reports_nothing"
out="$(cd "$WORK" && PATH="$WORK/bin:$PATH" YAZI_LEFT_IN="" \
  bash -c 'source "$1"; yy; pwd' _ "$FUNCS/utils/yazi.sh")"
assert_equals "$(cd "$WORK" && pwd)" "$out" "no directory reported, no change"

mro() {
  RC=0
  OUT="$(PATH="$WORK/bin:$PATH" bash -c 'source "$1"; shift; mount_read_only "$@"' _ \
    "$FUNCS/security/mount_read_only.sh" "$@" 2>&1)" || RC=$?
}

test_start "mount_read_only_requires_an_image"
mro
assert_equals "1" "$RC" "no image exits 1"
assert_contains "No disk image specified" "$OUT" "and says so"

test_start "mount_read_only_refuses_a_missing_image"
mro "$WORK/absent.dmg"
assert_equals "1" "$RC" "a missing image exits 1"
assert_contains "Disk image not found: $WORK/absent.dmg" "$OUT" "and names it"

test_start "mount_read_only_attaches_with_a_private_shadow"
: >"$WORK/disk.dmg"
mro "$WORK/disk.dmg"
assert_equals "0" "$RC" "an existing image is attached"
assert_contains "attach $WORK/disk.dmg -shadow " "$(cat "$WORK/hdiutil.args")" "through hdiutil with a shadow file"
assert_contains "-noverify" "$(cat "$WORK/hdiutil.args")" "without re-verifying"
assert_equals "-rw-------" "$(cat "$WORK/shadow.mode" 2>/dev/null)" "the shadow file is private (0600)"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
