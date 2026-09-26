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
      env -u ZDOTDIR PATH="$path" \
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
assert_false '[[ "$DOC_OUT" == *"mise tool dirs"* ]]' "with no mise tool dirs the message has no mise breakdown"

# ── 91 entries: first value past the ceiling warns ─────────────────────
test_start "path_count_91_warns"
_run_doctor "$(_path_with_entries $((91 - DOCTOR_PREFIX_ENTRIES)))"
assert_contains "91 entries" "$DOC_OUT" "doctor counted exactly 91 entries"
assert_contains "[WARN] PATH length" "$DOC_OUT" "91 entries is [WARN]"
assert_contains "consider pruning" "$DOC_OUT" "91 entries carries the pruning advice"
assert_false '[[ "$DOC_OUT" == *"[OK] PATH length"* ]]' "91 entries is not [OK]"

# ── 120 entries still warns; 121 is the first [FAIL] ───────────────────
test_start "path_count_120_warns"
_run_doctor "$(_path_with_entries $((120 - DOCTOR_PREFIX_ENTRIES)))"
assert_contains "[WARN] PATH length 120 entries" "$DOC_OUT" "120 entries is still [WARN]"

test_start "path_count_121_fails"
_run_doctor "$(_path_with_entries $((121 - DOCTOR_PREFIX_ENTRIES)))"
assert_contains "[FAIL] PATH length 121 entries" "$DOC_OUT" "121 entries is [FAIL]"

# ── mise tool directories do not count towards the length verdict ──────
# 100 entries, 70 of them mise install dirs: 30 other, so [OK], and the
# message reports the mise share. It used to warn on every such machine.
test_start "path_mise_tool_dirs_are_not_counted"
mise_path="$S_BIN:$SYSBIN"
for ((i = 1; i <= 70; i++)); do mise_path="$mise_path:$S_HOME/.local/share/mise/installs/tool$i/1.0/bin"; done
for ((i = 3; i <= 28; i++)); do mise_path="$mise_path:$S_HOME/pathpad/$i"; done
_run_doctor "$mise_path"
assert_contains "[OK] PATH length 100 entries (70 mise tool dirs, 30 other)" "$DOC_OUT" \
  "a PATH that is long only because of mise tool dirs is [OK]"

# ── duplicates warn at any length ──────────────────────────────────────
test_start "path_duplicates_warn"
_run_doctor "$S_BIN:$SYSBIN:$S_HOME/pathpad/a:$S_HOME/pathpad/a:$S_HOME/pathpad/b"
assert_contains "[WARN] PATH length" "$DOC_OUT" "a PATH with a repeated entry warns"
assert_contains "1 duplicate(s)" "$DOC_OUT" "the warning counts the duplicates"

# ── doctor does not duplicate a directory the PATH already has ─────────
test_start "path_doctor_prefix_does_not_duplicate"
_run_doctor "$S_BIN:$SYSBIN:$S_HOME/.local/bin"
assert_contains "[OK] PATH length 4 entries" "$DOC_OUT" \
  "with ~/.local/bin already on PATH doctor adds only ~/.atuin/bin and reports no duplicate"

# ── zsh hooks: one-shot hooks are fired before counting ───────────────
# A zshrc with a persistent and a self-removing hook of each kind (the
# deferred-init hooks remove themselves on first run): doctor must report
# precmd=1 preexec=1, not the startup count of 2 and 2.
test_start "zsh_hooks_count_after_one_shot_hooks_fire"
ZSH_REAL="$(command -v zsh || true)"
if [[ -n "$ZSH_REAL" ]]; then
  ln -sf "$ZSH_REAL" "$S_BIN/zsh"
  cat >"$S_HOME/.zshrc" <<'ZRC'
persistent_precmd() { :; }
one_shot_precmd() { precmd_functions=(${precmd_functions:#one_shot_precmd}); }
persistent_preexec() { :; }
one_shot_preexec() { preexec_functions=(${preexec_functions:#one_shot_preexec}); }
precmd_functions=(persistent_precmd one_shot_precmd)
preexec_functions=(persistent_preexec one_shot_preexec)
ZRC
  _run_doctor "$S_BIN:$SYSBIN"
  rm -f "$S_BIN/zsh" "$S_HOME/.zshrc"
  assert_contains "zsh hooks precmd=1 preexec=1" "$DOC_OUT" "self-removing precmd and preexec hooks are not counted; persistent ones are"
else
  assert_true "true" "skipped: zsh not installed"
fi

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
