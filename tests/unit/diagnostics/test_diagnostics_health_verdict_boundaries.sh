#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Verdict-boundary tests for print_summary in scripts/diagnostics/health.sh.
#
# Found by mutation testing. Two mutants on the summary survived because
# every existing health scenario is either near-perfect (score 100) or bare
# (score < 50) and always has warnings AND failures at once:
#
#   H2  `score -ge 90` -> `-ge 9`        (top band boundary)
#       score_90_is_excellent   score exactly 90 -> "Excellent!"
#       score_89_is_good        score exactly 89 -> "Good!", not "Excellent!"
#
#   H3  `WARNINGS -gt 0 || FAILURES -gt 0` -> `&&`   (--fix tip)
#       fix_tip_on_warnings_only   1 warning, 0 failures -> tip printed
#       fix_tip_on_failures_only   0 warnings, 1 failure -> tip printed
#       no_fix_tip_when_clean      0 / 0 -> no tip (pins the other side)
#
# The score is integer PASSED*100/TOTAL. With every stub installed health
# runs 43 checks plus one "SSH key perms" check per private key in
# ~/.ssh, so the key count is the knob that sets TOTAL: with 5 checks held
# at "warn", 7 keys give 45/50 = 90 and 6 keys give 44/49 = 89. Each case
# first runs --json to prove the fixture produced exactly that score and
# those counters, then runs the text summary and asserts the verdict.
#
# health.sh is never sourced: it runs as a script under a fully synthetic
# PATH and HOME, so nothing on the host is read or written.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

HEALTH_FILE="$REPO_ROOT/scripts/diagnostics/health.sh"
REAL_BASH="${BASH:-$(command -v bash)}"

TMP="$(mktemp -d -t dotfiles-health-verdict.XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

# ── FULL_BIN: coreutils + a stub for every tool health.sh probes ───────
FULL_BIN="$TMP/full-bin"
mkdir -p "$FULL_BIN"
for util in awk sed grep wc tr cut head tail sort uniq date stat basename dirname \
  mkdir rm cp mv cat printf sleep locale env find true false; do
  p="$(command -v "$util" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$FULL_BIN/$util"
done
ln -sf "$REAL_BASH" "$FULL_BIN/bash"
ln -sf "$REAL_BASH" "$FULL_BIN/sh"

# stub <name> [body]: an executable that runs body (default: nothing) and exits 0.
stub() {
  printf '#!/usr/bin/env bash\n%s\nexit 0\n' "${2:-:}" >"$FULL_BIN/$1"
  chmod +x "$FULL_BIN/$1"
}
# Presence alone flips these checks to pass; git/chezmoi/jq printing nothing
# satisfies every probe health.sh makes of them (email set, no drift, no
# custom age identity).
for t in chezmoi git zsh starship fnm rustc go fzf rg fd bat eza zoxide atuin \
  delta jq yq sops mise just zellij hyperfine ghostty age; do
  stub "$t"
done
stub node 'echo v24.0.0'
stub python3 'echo "Python 3.13.0"'
stub nvim 'echo "NVIM v0.11.0"'
stub fc-list 'echo "/fonts/Hack Nerd Font Mono"'
stub gpg 'echo "sec   ed25519 2026-01-01"'

# _bin <name> [omit...]: a copy of FULL_BIN without the named tools.
_bin() {
  local name="$1" dir="$TMP/bin-$1" f t
  shift
  mkdir -p "$dir"
  for f in "$FULL_BIN"/*; do
    ln -sf "$f" "$dir/$(basename "$f")"
  done
  for t in "$@"; do
    rm -f "$dir/$t"
  done
  printf '%s' "$dir"
}

# _home <name> <keys>: a HOME where every filesystem check passes, holding
# <keys> private SSH keys in mode 600 (the 3 well-known names first, then
# extra pairs discovered through their .pub files).
_home() {
  local name="$1" keys="$2" home="$TMP/home-$1" i
  mkdir -p "$home/.local/share/chezmoi" "$home/.local/share/zinit" \
    "$home/.local/share/nvim/lazy" "$home/.config/shell" "$home/.config/nvim" \
    "$home/.config/git" "$home/.config/chezmoi" "$home/.dotfiles/.git" "$home/.ssh"
  touch "$home/.config/chezmoi/key.txt"
  local -a names=(id_ed25519 id_rsa id_ed25519_sk)
  for ((i = 0; i < keys; i++)); do
    if ((i < 3)); then
      : >"$home/.ssh/${names[i]}"
      chmod 600 "$home/.ssh/${names[i]}"
    else
      : >"$home/.ssh/extra_$i"
      : >"$home/.ssh/extra_$i.pub"
      chmod 600 "$home/.ssh/extra_$i"
    fi
  done
  printf '%s' "$home"
}

# _run_health <bin> <home> [args...]: run health.sh sandboxed. Sets OUT.
OUT=""
_run_health() {
  local bin="$1" home="$2"
  shift 2
  OUT="$(
    env -u ZINIT_HOME -u NO_COLOR PATH="$bin" HOME="$home" \
      XDG_CONFIG_HOME="$home/.config" \
      XDG_DATA_HOME="$home/.local/share" \
      XDG_CACHE_HOME="$home/.cache" \
      XDG_STATE_HOME="$home/.local/state" \
      SHELL="$bin/zsh" \
      DOTFILES_ACCESSIBILITY=1 \
      "$REAL_BASH" "$HEALTH_FILE" "$@" 2>&1 |
      sed -e 's/\x1b\[[0-9;]*m//g'
  )" || true
}

# _json_field <name>: the integer value of a top-level field in the --json OUT.
_json_field() {
  printf '%s\n' "$OUT" | sed -n "s/^  \"$1\": \([0-9]*\),\{0,1\}$/\1/p" | head -n 1
}

EXCELLENT="Excellent! Your dotfiles are in great shape."
GOOD="Good! Minor improvements possible."
FIX_TIP="Run 'dot health --fix' to auto-repair common issues."

# ── H2: score exactly 90 is the bottom of the "Excellent" band ─────────
test_start "score_90_is_excellent"
BIN="$(_bin score90 rustc go fzf fd bat)"
HOME_DIR="$(_home score90 7)"
_run_health "$BIN" "$HOME_DIR" --json
assert_equals 50 "$(_json_field total)" "fixture runs 50 checks"
assert_equals 45 "$(_json_field passed)" "fixture passes 45 checks"
assert_equals 90 "$(_json_field score)" "fixture scores exactly 90"
_run_health "$BIN" "$HOME_DIR"
assert_contains "$EXCELLENT" "$OUT" "score 90 reads Excellent"
assert_false '[[ "$OUT" == *"$GOOD"* ]]' "score 90 does not read Good"

# ── H2: score exactly 89 is the top of the "Good" band ─────────────────
test_start "score_89_is_good"
BIN="$(_bin score89 rustc go fzf fd bat)"
HOME_DIR="$(_home score89 6)"
_run_health "$BIN" "$HOME_DIR" --json
assert_equals 49 "$(_json_field total)" "fixture runs 49 checks"
assert_equals 44 "$(_json_field passed)" "fixture passes 44 checks"
assert_equals 89 "$(_json_field score)" "fixture scores exactly 89"
_run_health "$BIN" "$HOME_DIR"
assert_contains "$GOOD" "$OUT" "score 89 reads Good"
assert_false '[[ "$OUT" == *"$EXCELLENT"* ]]' "score 89 does not read Excellent"

# ── H3: warnings alone are enough for the --fix tip ────────────────────
test_start "fix_tip_on_warnings_only"
BIN="$(_bin warnonly rustc)"
HOME_DIR="$(_home warnonly 3)"
_run_health "$BIN" "$HOME_DIR" --json
assert_equals 1 "$(_json_field warnings)" "fixture has exactly one warning"
assert_equals 0 "$(_json_field failures)" "fixture has no failures"
_run_health "$BIN" "$HOME_DIR"
assert_contains "$FIX_TIP" "$OUT" "a warnings-only run prints the --fix tip"

# ── H3: failures alone are enough for the --fix tip ────────────────────
test_start "fix_tip_on_failures_only"
BIN="$(_bin failonly git)"
HOME_DIR="$(_home failonly 3)"
_run_health "$BIN" "$HOME_DIR" --json
assert_equals 0 "$(_json_field warnings)" "fixture has no warnings"
assert_equals 1 "$(_json_field failures)" "fixture has exactly one failure"
_run_health "$BIN" "$HOME_DIR"
assert_contains "$FIX_TIP" "$OUT" "a failures-only run prints the --fix tip"

# ── H3 (other side): a clean run has nothing to fix ────────────────────
test_start "no_fix_tip_when_clean"
BIN="$(_bin clean)"
HOME_DIR="$(_home clean 3)"
_run_health "$BIN" "$HOME_DIR" --json
assert_equals 0 "$(_json_field warnings)" "fixture has no warnings"
assert_equals 0 "$(_json_field failures)" "fixture has no failures"
assert_equals 100 "$(_json_field score)" "fixture scores 100"
_run_health "$BIN" "$HOME_DIR"
assert_contains "$EXCELLENT" "$OUT" "score 100 reads Excellent"
assert_false '[[ "$OUT" == *"$FIX_TIP"* ]]' "a clean run prints no --fix tip"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
