#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Boundary test for the PATH-length verdict in scripts/diagnostics/doctor.sh.
#
# Found by mutation testing (mutant D1): flipping the OK ceiling from
# `-le 90` to `-lt 90` survived every existing doctor scenario, because they
# all ran with a PATH far below or far above the ceiling. This file pins the
# documented contract exactly on the boundary:
#
#   path_count_90_is_ok    a PATH with exactly 90 entries is still [OK]
#   path_count_91_warns    91 entries is the first [WARN] ("consider pruning")
#
# doctor.sh prepends two entries of its own ($HOME/.atuin/bin and
# $HOME/.local/bin) before counting, so the fixture hands it N-2 entries and
# asserts the count doctor actually reports, which keeps the case honest if
# that prefix ever changes.
#
# Same sandbox as test_diagnostics_doctor_branches.sh: a private HOME, a
# "sysbin" of symlinked coreutils and a Linux uname shim, so nothing from the
# host leaks into the run.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

DOCTOR_FILE="$REPO_ROOT/scripts/diagnostics/doctor.sh"

TMP="$(mktemp -d -t dotfiles-doctor-path.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

# ── sysbin: the only host binaries doctor may see ──────────────────────
SYSBIN="$TMP/sysbin"
mkdir -p "$SYSBIN"
for tool in awk sed grep tr find date stat wc head tail basename dirname \
  readlink cut sort uniq cat mkdir mktemp printf hostname whoami rm touch ls env \
  python3 timeout locale tput; do
  p="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$SYSBIN/$tool"
done
ln -sf "$BASH" "$SYSBIN/bash"

# ── one bare Linux fixture: enough for doctor to reach the PATH probe ──
S_BIN="$TMP/bin"
S_HOME="$TMP/home"
mkdir -p "$S_BIN" "$S_HOME/.config" "$S_HOME/.local/bin" "$S_HOME/.local/share" \
  "$S_HOME/.cache" "$S_HOME/.local/state" "$S_HOME/proc" "$S_HOME/sys"
cat >"$S_BIN/uname" <<'SHIM'
#!/usr/bin/env bash
case "${1:-}" in
  -sr) echo "Linux 6.1.0" ;;
  -m | -p) echo "x86_64" ;;
  *) echo "Linux" ;;
esac
SHIM
cat >"$S_BIN/uptime" <<'SHIM'
#!/usr/bin/env bash
echo "up 2 minutes"
SHIM
chmod +x "$S_BIN/uname" "$S_BIN/uptime"
printf 'ID=fixturelinux\nPRETTY_NAME="Fixture Linux 2026"\n' >"$S_HOME/os-release"

# _path_with_entries <n>: a PATH string of exactly n entries, starting with
# the fixture bin + sysbin and padded with (non-existent) directories.
_path_with_entries() {
  local n="$1" path="$S_BIN:$SYSBIN" i
  for ((i = 3; i <= n; i++)); do
    path="$path:$S_HOME/pathpad/$i"
  done
  printf '%s' "$path"
}

# _run_doctor <path>: run doctor sandboxed with the given PATH. Sets DOC_OUT
# (ANSI stripped, runs of spaces collapsed).
DOC_OUT=""
_run_doctor() {
  local path="$1"
  DOC_OUT="$(
    cd "$S_HOME" &&
      env PATH="$path" \
        HOME="$S_HOME" \
        XDG_CONFIG_HOME="$S_HOME/.config" \
        XDG_DATA_HOME="$S_HOME/.local/share" \
        XDG_CACHE_HOME="$S_HOME/.cache" \
        XDG_STATE_HOME="$S_HOME/.local/state" \
        SHELL="$S_BIN/zsh" \
        DOTFILES_ACCESSIBILITY=1 \
        DOT_DOCTOR_OS_RELEASE="$S_HOME/os-release" \
        DOT_DOCTOR_PROC_ROOT="$S_HOME/proc" \
        DOT_DOCTOR_SYS_ROOT="$S_HOME/sys" \
        PIPX_HOME= TERM_PROGRAM= \
        "$BASH" "$DOCTOR_FILE" 2>&1 |
      sed -e 's/\x1b\[[0-9;]*m//g' -e 's/  */ /g'
  )" || true
}

# doctor adds 2 entries of its own, so N-2 supplied entries -> N counted.
DOCTOR_PREFIX_ENTRIES=2

# ── 90 entries: the ceiling itself is still OK ─────────────────────────
test_start "path_count_90_is_ok"
_run_doctor "$(_path_with_entries $((90 - DOCTOR_PREFIX_ENTRIES)))"
assert_contains "PATH length" "$DOC_OUT" "doctor reached the PATH probe"
assert_contains "90 entries" "$DOC_OUT" "doctor counted exactly 90 entries"
assert_contains "[OK] PATH length" "$DOC_OUT" "90 entries is [OK]"
assert_false '[[ "$DOC_OUT" == *"[WARN] PATH length"* ]]' "90 entries does not warn"
assert_false '[[ "$DOC_OUT" == *"consider pruning"* ]]' "90 entries carries no pruning advice"

# ── 91 entries: first value past the ceiling warns ─────────────────────
test_start "path_count_91_warns"
_run_doctor "$(_path_with_entries $((91 - DOCTOR_PREFIX_ENTRIES)))"
assert_contains "91 entries" "$DOC_OUT" "doctor counted exactly 91 entries"
assert_contains "[WARN] PATH length" "$DOC_OUT" "91 entries is [WARN]"
assert_contains "consider pruning" "$DOC_OUT" "91 entries carries the pruning advice"
assert_false '[[ "$DOC_OUT" == *"[OK] PATH length"* ]]' "91 entries is not [OK]"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
