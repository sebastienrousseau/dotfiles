#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural tests for scripts/diagnostics/health.sh across the whole
# environment matrix it reports on: every tool present, every tool absent,
# JSON output, the --fix / --force remediation path, drifted chezmoi + git
# state, weak SSH key modes and the gum/colour renderer on a terminal.
#
# The script under test is never sourced — it is run as a script with a
# fully synthetic PATH, so each branch is chosen by what the sandbox does
# and does not contain. Nothing on the host is read or written.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/diagnostics/health.sh"
REAL_BASH="${BASH:-$(command -v bash)}"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox
WORK="$DOTFILES_COV_TMPDIR/work"
mkdir -p "$WORK"

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "scripts/diagnostics/health.sh must exist"

# ---------------------------------------------------------------------------
# Synthetic PATH. BASE_BIN holds only the utilities health.sh needs to run at
# all (coreutils + bash); it deliberately contains no chezmoi, git, zsh,
# node, … so every "not installed" branch fires. FULL_BIN adds a stub for
# each tool health.sh probes, so every "installed" branch fires instead.
# ---------------------------------------------------------------------------
BASE_BIN="$WORK/base-bin"
FULL_BIN="$WORK/full-bin"
mkdir -p "$BASE_BIN" "$FULL_BIN"

for util in awk sed grep wc tr cut head tail sort uniq date stat basename dirname \
  mkdir rm cp mv cat printf sleep locale env find true false; do
  p="$(command -v "$util" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$BASE_BIN/$util"
done
ln -sf "$REAL_BASH" "$BASE_BIN/bash"
ln -sf "$REAL_BASH" "$BASE_BIN/sh"

# stub <dir> <name> [body] — a recording stub that exits 0 by default.
stub() {
  local dir="$1" name="$2" body="${3:-:}"
  cat >"$dir/$name" <<EOF
#!/usr/bin/env bash
printf '%s %s\n' "$name" "\$*" >>"\${STUB_CALLS:-/dev/null}"
$body
exit 0
EOF
  chmod +x "$dir/$name"
}

for f in "$BASE_BIN"/*; do ln -sf "$f" "$FULL_BIN/$(basename "$f")"; done
# Tools whose mere presence flips a check to "pass".
for t in fnm rustc go fzf rg fd bat eza zoxide atuin delta jq yq sops just \
  zellij hyperfine ghostty starship age fc-list gpg; do
  stub "$FULL_BIN" "$t"
done
stub "$FULL_BIN" node 'echo v24.15.0'
stub "$FULL_BIN" python3 'echo "Python 3.13.2"'
stub "$FULL_BIN" mise 'echo "2026.5.7"'
stub "$FULL_BIN" nvim 'echo "NVIM v0.11.0"'
stub "$FULL_BIN" zsh
stub "$FULL_BIN" chezmoi 'case "${1:-}" in status) [[ -n "${FAKE_CHEZMOI_STATUS:-}" ]] && printf "%s\n" "$FAKE_CHEZMOI_STATUS" ;; esac'
stub "$FULL_BIN" git '
case "${1:-}" in
  config) [[ "${FAKE_GIT_CONFIG_FAIL:-0}" == "1" ]] && exit 1
          case "$*" in
            *gpg.format*) printf "%s\n" "${FAKE_GIT_SIGNING_FORMAT:-}" ;;
            *user.signingkey*) printf "%s\n" "${FAKE_GIT_SIGNING_KEY:-}" ;;
            *allowedSignersFile*) printf "%s\n" "${FAKE_GIT_ALLOWED_SIGNERS:-}" ;;
            *user.email*) printf "test@example.com\n" ;;
          esac ;;
  -C) [[ "${3:-}" == status ]] && [[ -n "${FAKE_GIT_STATUS:-}" ]] && printf "%s\n" "$FAKE_GIT_STATUS" ;;
esac'
# fc-list output decides the Nerd Font check.
stub "$FULL_BIN" fc-list 'printf "%s\n" "${FAKE_FC_LIST:-/usr/share/fonts/Hack Nerd Font Mono}"'
# `gpg --list-secret-keys | grep -q sec` decides the GPG-keys check.
stub "$FULL_BIN" gpg '[[ "${1:-}" == --list-secret-keys ]] && printf "%s\n" "${FAKE_GPG_KEYS-sec   ed25519 2026-01-01}"'
stub "$FULL_BIN" gum '[[ "${1:-}" == style ]] && { shift; while [[ "${1:-}" == --* ]]; do shift; done; printf "%s\n" "$*"; }'

export STUB_CALLS="$WORK/calls"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
_pass() {
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
}
_fail() {
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $1"
}

OUT="$WORK/out.txt"
# run_health <bin-dir> [args...] — run health.sh with the given synthetic
# PATH, capturing stdout+stderr in $OUT and returning its exit status.
run_health() {
  local bin="$1"
  shift
  PATH="$bin" HOME="$SANDBOX_HOME" \
    XDG_CONFIG_HOME="$SANDBOX_HOME/.config" \
    XDG_DATA_HOME="$SANDBOX_HOME/.local/share" \
    XDG_CACHE_HOME="$SANDBOX_HOME/.cache" \
    XDG_STATE_HOME="$SANDBOX_HOME/.local/state" \
    "$REAL_BASH" "$SCRIPT_FILE" "$@" >"$OUT"
}

# run_health_at <tree> <bin-dir> [args...] — same, for a copy of health.sh
# living in a synthetic tree (used by the --fix and default_shell cases).
run_health_at() {
  local tree="$1" bin="$2"
  shift 2
  PATH="$bin" HOME="$SANDBOX_HOME" \
    XDG_CONFIG_HOME="$SANDBOX_HOME/.config" \
    XDG_DATA_HOME="$SANDBOX_HOME/.local/share" \
    XDG_CACHE_HOME="$SANDBOX_HOME/.cache" \
    XDG_STATE_HOME="$SANDBOX_HOME/.local/state" \
    "$REAL_BASH" "$tree/scripts/diagnostics/health.sh" "$@" >"$OUT"
}

# A per-test HOME so one test's fixtures can't leak into the next.
new_home() {
  SANDBOX_HOME="$WORK/home-$1"
  rm -rf "$SANDBOX_HOME"
  mkdir -p "$SANDBOX_HOME"
}

# ===========================================================================
# 1. Nothing installed — every check takes its failure / warning branch.
# ===========================================================================
test_start "bare_environment_reports_failures_and_low_score"
new_home bare
run_health "$BASE_BIN"
rc=$?
assert_equals "0" "$rc" "health still exits 0 when the environment is bare"
assert_file_contains "$OUT" "Chezmoi installed" "chezmoi check reported"
assert_file_contains "$OUT" "Not installed" "missing tools reported as not installed"
assert_file_contains "$OUT" "None found" "no config directories found"
assert_file_contains "$OUT" "Needs attention" "score band for a bare environment"
# Regression: the WARNING / FAILED lines must name the check they refer to.
# Both printf calls used to omit the "$name" argument, so every failing row
# rendered as 35 blanks and the dashboard never said what was wrong.
assert_output_matches "Chezmoi installed +FAILED" "cat '$OUT'"
assert_output_matches "Starship prompt +WARNING" "cat '$OUT'"
assert_file_contains "$OUT" "dot health --fix" "remediation tip shown when there are warnings"

# ===========================================================================
# 2. Everything installed — the pass branches, including chezmoi/git present.
# ===========================================================================
test_start "fully_provisioned_environment_reports_passes"
new_home full
mkdir -p "$SANDBOX_HOME/.local/share/chezmoi" \
  "$SANDBOX_HOME/.local/share/zinit" \
  "$SANDBOX_HOME/.local/share/nvim/lazy" \
  "$SANDBOX_HOME/.config/shell" "$SANDBOX_HOME/.config/nvim" \
  "$SANDBOX_HOME/.config/git" "$SANDBOX_HOME/.config/chezmoi" \
  "$SANDBOX_HOME/.local/share/fonts" "$SANDBOX_HOME/.ssh"
touch "$SANDBOX_HOME/.config/chezmoi/key.txt" \
  "$SANDBOX_HOME/.local/share/fonts/HackNerdFont.ttf"
: >"$SANDBOX_HOME/.ssh/id_ed25519"
chmod 600 "$SANDBOX_HOME/.ssh/id_ed25519"
SHELL=/bin/zsh run_health "$FULL_BIN"
assert_file_contains "$OUT" "Chezmoi source directory" "source dir check reported"
assert_file_contains "$OUT" "Zinit plugin manager" "zinit check reported"
assert_file_contains "$OUT" "Neovim plugins (lazy.nvim)" "lazy.nvim detected"
assert_file_contains "$OUT" "Age key configured" "age key detected"
assert_file_contains "$OUT" "SSH keys present" "ssh key detected"
assert_file_contains "$OUT" "Config directories" "config dir roll-up reported"

test_start "fully_provisioned_environment_scores_high"
if grep -qE "Excellent|Good!" "$OUT"; then _pass; else _fail "expected a high score band"; fi

# ===========================================================================
# 3. Config-directory partial state (found > 0 but < total).
# ===========================================================================
test_start "partial_config_directories_warn"
new_home partial
mkdir -p "$SANDBOX_HOME/.config/shell"
run_health "$BASE_BIN"
assert_file_contains "$OUT" "1/3 present" "partial config directories reported as a fraction"

# ===========================================================================
# 4. Weak SSH key permissions.
# ===========================================================================
test_start "loose_ssh_key_mode_warns"
new_home sshperm
mkdir -p "$SANDBOX_HOME/.ssh"
: >"$SANDBOX_HOME/.ssh/id_rsa"
chmod 644 "$SANDBOX_HOME/.ssh/id_rsa"
run_health "$BASE_BIN"
assert_file_contains "$OUT" "SSH key perms (id_rsa)" "per-key permission check reported"
assert_file_contains "$OUT" "should be 600" "loose mode flagged"

# ===========================================================================
# 5. Git commit signing configured over SSH.
# ===========================================================================
test_start "ssh_git_signing_reports_pass"
new_home signing
mkdir -p "$SANDBOX_HOME/.config/git"
: >"$SANDBOX_HOME/.config/git/allowed_signers"
: >"$SANDBOX_HOME/signing_key.pub"
FAKE_GIT_SIGNING_FORMAT=ssh \
  FAKE_GIT_SIGNING_KEY="$SANDBOX_HOME/signing_key.pub" \
  FAKE_GIT_ALLOWED_SIGNERS="$SANDBOX_HOME/.config/git/allowed_signers" \
  run_health "$FULL_BIN"
assert_file_contains "$OUT" "Git signing" "ssh signing branch reported"

test_start "gpg_without_secret_keys_warns"
new_home nogpgkeys
FAKE_GPG_KEYS="" run_health "$FULL_BIN"
assert_file_contains "$OUT" "No secret keys" "empty gpg keyring warns"

test_start "git_without_user_email_warns"
new_home noemail
FAKE_GIT_CONFIG_FAIL=1 run_health "$FULL_BIN"
assert_file_contains "$OUT" "Email not set" "unconfigured git identity warns"

# ===========================================================================
# 6. Drift: chezmoi status and a dirty git working tree.
# ===========================================================================
test_start "chezmoi_apply_drift_warns"
new_home drift
mkdir -p "$SANDBOX_HOME/.dotfiles/.git"
FAKE_CHEZMOI_STATUS=" M .zshrc" \
  FAKE_GIT_STATUS=" M scripts/x.sh" \
  run_health "$FULL_BIN"
assert_file_contains "$OUT" "out of sync" "column-2 drift is reported as out of sync"
FAKE_CHEZMOI_STATUS=" M .zshrc" \
  FAKE_GIT_STATUS=" M scripts/x.sh" \
  run_health "$FULL_BIN" --json
assert_file_contains "$OUT" "local change(s)" "dirty git tree counted in the JSON report"

test_start "chezmoi_source_only_drift_passes"
new_home srcdrift
FAKE_CHEZMOI_STATUS="M  scripts/x.sh" run_health "$FULL_BIN" --json
assert_file_contains "$OUT" "source-only edit(s)" "column-1-only drift passes with a note"
assert_file_contains "$OUT" '"check":"Chezmoi sync","status":"pass"' "source-only drift is not a sync failure"

test_start "clean_git_tree_passes"
new_home cleangit
mkdir -p "$SANDBOX_HOME/.dotfiles/.git"
run_health "$FULL_BIN"
assert_file_contains "$OUT" "Git working tree" "git working tree check reported"

# ===========================================================================
# 7. JSON output.
# ===========================================================================
test_start "json_output_is_machine_readable"
new_home json
run_health "$BASE_BIN" --json
assert_file_contains "$OUT" '"results": [' "results array emitted"
assert_file_contains "$OUT" '"check":' "each result carries a check name"
if command -v python3 >/dev/null 2>&1; then
  if python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d["total"]==d["passed"]+d["warnings"]+d["failures"] and 0<=d["score"]<=100 else 1)' "$OUT"; then
    _pass
  else
    _fail "JSON did not parse, or totals/score were inconsistent"
  fi
else
  _pass
fi

test_start "json_output_suppresses_human_sections"
assert_output_not_contains "Health Dashboard" "cat '$OUT'"

test_start "json_short_flag_matches_long_flag"
new_home jsonshort
run_health "$BASE_BIN" -j
assert_file_contains "$OUT" '"score":' "-j emits the same JSON document"

# ===========================================================================
# 8. Flags: --verbose / -v and the unknown-argument arm.
# ===========================================================================
test_start "verbose_and_unknown_flags_are_accepted"
new_home flags
run_health "$BASE_BIN" --verbose --definitely-not-a-flag
rc=$?
assert_equals "0" "$rc" "unknown flags are skipped rather than fatal"
assert_file_contains "$OUT" "Health Score" "the report still renders"

test_start "short_verbose_flag_accepted"
new_home flagsv
run_health "$BASE_BIN" -v
assert_file_contains "$OUT" "Health Score" "-v renders the report"

# ===========================================================================
# 9. Auto-remediation: --fix runs heal.sh, --force forwards the flag, and a
#    missing heal.sh degrades gracefully. heal.sh is resolved relative to the
#    script, so run a copy of health.sh from a synthetic tree.
# ===========================================================================
# health.sh resolves heal.sh relative to its own location, so the script has
# to run from the repo to keep its own path (and therefore its coverage
# attribution) intact. Intercept the hand-off instead: health.sh shells out
# with `bash <script-dir>/../ops/heal.sh`, and `bash` comes from PATH, so a
# shim can answer for any heal.sh and exec the real interpreter for
# everything else. The real heal.sh is never executed.
# `ln -sf` above left a symlink here; writing through it would target the
# real interpreter, so replace the link rather than follow it.
rm -f "$BASE_BIN/bash" "$FULL_BIN/bash"
cat >"$BASE_BIN/bash" <<EOF
#!$REAL_BASH
case "\${1:-}" in
  *heal.sh)
    printf 'heal-invoked %s\n' "\${*:2}"
    [[ -n "\${HEAL_STUB_RC:-}" ]] && exit "\$HEAL_STUB_RC"
    exit 0
    ;;
esac
exec "$REAL_BASH" "\$@"
EOF
chmod +x "$BASE_BIN/bash"
ln -sf "$BASE_BIN/bash" "$FULL_BIN/bash"

# A second PATH whose bash shim reports heal.sh as missing, for the
# "heal.sh not found" branch: health.sh checks `[[ -f "$heal_script" ]]`
# before shelling out, so that branch needs the script itself to be absent.
# It is exercised through a tree of symlinks (behaviour only — the copy's
# own path is not part of the measured file set).
NOHEAL_TREE="$WORK/noheal"
mkdir -p "$NOHEAL_TREE/scripts/diagnostics" "$NOHEAL_TREE/scripts/ops" "$NOHEAL_TREE/lib/dot"
ln -sf "$SCRIPT_FILE" "$NOHEAL_TREE/scripts/diagnostics/health.sh"
ln -sf "$REPO_ROOT/lib/dot/ui.sh" "$NOHEAL_TREE/lib/dot/ui.sh"
ln -sf "$REPO_ROOT/lib/dot/log.sh" "$NOHEAL_TREE/lib/dot/log.sh"

test_start "fix_flag_invokes_heal_and_recounts"
new_home fix
run_health "$BASE_BIN" --fix
assert_file_contains "$OUT" "Auto-Remediation" "remediation section printed"
assert_file_contains "$OUT" "heal-invoked" "heal.sh was executed"
if [[ "$(grep -c "Dotfiles Core" "$OUT")" == "2" ]]; then
  _pass
else
  _fail "checks should be re-run after healing (expected two passes)"
fi

test_start "force_flag_is_forwarded_to_heal"
new_home force
run_health "$BASE_BIN" --fix --force
assert_file_contains "$OUT" "heal-invoked --force" "--force forwarded to heal.sh"

test_start "short_fix_and_force_flags_are_forwarded"
new_home shortfix
run_health "$BASE_BIN" -f -F
assert_file_contains "$OUT" "heal-invoked --force" "-f -F behave like --fix --force"

test_start "a_failing_heal_does_not_abort_the_report"
new_home healfail
HEAL_STUB_RC=1 run_health "$BASE_BIN" --fix
assert_file_contains "$OUT" "Health Score" "the summary is still printed when heal exits non-zero"

test_start "fix_without_heal_script_warns"
new_home noheal
run_health_at "$NOHEAL_TREE" "$BASE_BIN" --fix
assert_file_contains "$OUT" "heal.sh not found" "missing heal.sh is reported, not fatal"

test_start "fix_with_json_suppresses_the_remediation_header"
new_home fixjson
run_health "$BASE_BIN" --fix --json
assert_output_not_contains "Auto-Remediation" "cat '$OUT'"
assert_file_contains "$OUT" '"score":' "JSON is still emitted after healing"

# ===========================================================================
# 10. Default-shell resolution reads .chezmoidata.toml.
# ===========================================================================
test_start "zinit_not_required_for_a_non_zsh_default_shell"
new_home defshell
# The repo ships default_shell = "fish", so a fish login shell must not be
# told to install zinit.
SHELL=/usr/bin/fish run_health "$FULL_BIN" --json
assert_file_contains "$OUT" "Not required for fish" "default_shell is read from defaults/.chezmoidata.toml"

test_start "zinit_missing_warns_when_zsh_is_the_default_shell"
new_home zshdefault
mkdir -p "$NOHEAL_TREE/defaults"
printf 'default_shell = "zsh"\n' >"$NOHEAL_TREE/defaults/.chezmoidata.toml"
SHELL=/bin/zsh run_health_at "$NOHEAL_TREE" "$FULL_BIN" --json
assert_file_contains "$OUT" '"check":"Zinit plugin manager","status":"warn"' "missing zinit warns when zsh is the default shell"

test_start "unrecognised_login_shell_warns"
new_home oddshell
SHELL=/usr/bin/tcsh run_health "$FULL_BIN" --json
assert_file_contains "$OUT" "Current: /usr/bin/tcsh" "an unknown login shell is reported verbatim"

# ===========================================================================
# 11. Nerd Font discovered through fc-list and through ~/Library/Fonts.
# ===========================================================================
test_start "nerd_font_detected_via_fc_list"
new_home fonts
run_health "$FULL_BIN"
assert_file_contains "$OUT" "Nerd Font available" "font check reported"

test_start "nerd_font_missing_warns"
new_home nofonts
FAKE_FC_LIST="/usr/share/fonts/DejaVuSans.ttf" run_health "$FULL_BIN"
assert_file_contains "$OUT" "Not installed" "no Nerd Font found warns"

test_start "nerd_font_detected_from_the_xdg_font_directory"
# fc-list finds nothing, so detection has to fall through to the on-disk
# font directories.
new_home xdgfonts
mkdir -p "$SANDBOX_HOME/.local/share/fonts"
: >"$SANDBOX_HOME/.local/share/fonts/JetBrainsMonoNerdFont.ttf"
FAKE_FC_LIST="/usr/share/fonts/DejaVuSans.ttf" run_health "$FULL_BIN" --json
assert_file_contains "$OUT" '"check":"Nerd Font available","status":"pass"' "the XDG font directory is searched when fc-list finds nothing"

test_start "nerd_font_detected_from_the_macos_font_directory"
new_home macfonts
mkdir -p "$SANDBOX_HOME/Library/Fonts"
: >"$SANDBOX_HOME/Library/Fonts/HackNerdFont.ttf"
FAKE_FC_LIST="/usr/share/fonts/DejaVuSans.ttf" run_health "$FULL_BIN" --json
assert_file_contains "$OUT" '"check":"Nerd Font available","status":"pass"' "the macOS font directory is searched when fc-list finds nothing"

test_start "unmeasurable_shell_startup_warns"
# TIMEFORMAT is inherited by the `time` keyword health.sh uses, so a format
# without a "real" row makes the timing unparsable — the branch a broken
# interactive zsh config would take.
new_home slowshell
TIMEFORMAT='elapsed %3R' run_health "$FULL_BIN" --json
assert_file_contains "$OUT" '"check":"Shell startup time","status":"warn"' "unparsable timing warns instead of aborting"

# ===========================================================================
# 12. Terminal rendering: colours plus the gum-backed renderer.
# ===========================================================================
# tty_health <bin-dir> — run health.sh with stdout and stderr on a
# pseudo-terminal, so its colour and gum branches fire. No `exec {fd}>` or
# BASH_XTRACEFD: both are bash 4.1+ and macOS ships 3.2 as /bin/bash, which
# is what the macOS CI runner resolves. Under the coverage runner the inner
# shell's xtrace therefore lands on the pty with the report, so the records
# are split back out — replayed on fd 2 for the aggregator, and kept out of
# the text the assertions read.
tty_health() {
  local bin="$1" inner
  inner="$WORK/tty_inner.sh"
  cat >"$inner" <<EOF
export PATH='$bin'
export HOME='$SANDBOX_HOME'
export XDG_CONFIG_HOME='$SANDBOX_HOME/.config'
export XDG_DATA_HOME='$SANDBOX_HOME/.local/share'
export XDG_STATE_HOME='$SANDBOX_HOME/.local/state'
export TERM=xterm
'$REAL_BASH' '$SCRIPT_FILE'
echo "health-rc=\$?" >'$WORK/tty.rc'
EOF
  rm -f "$WORK/tty.rc"
  {
    local _i=0
    while [[ ! -f "$WORK/tty.rc" && $_i -lt 400 ]]; do
      sleep 0.05
      _i=$((_i + 1))
    done
  } | if [[ "$(uname -s)" == Darwin ]]; then
    script -q "$WORK/tty.raw" "$REAL_BASH" "$inner" >/dev/null 2>&1
  else
    script -qec "$REAL_BASH '$inner'" "$WORK/tty.raw" >/dev/null 2>&1
  fi
  tr -d '\r' <"$WORK/tty.raw" >"$WORK/tty.all" 2>/dev/null || true
  grep -E '^\++@COV@:' "$WORK/tty.all" >&2
  grep -vE '^\++@COV@:' "$WORK/tty.all" >"$OUT"
}

test_start "tty_run_uses_colour_and_gum"
new_home tty
if command -v script >/dev/null 2>&1; then
  tty_health "$FULL_BIN"
  assert_file_contains "$WORK/tty.rc" "health-rc=0" "health exits 0 on a terminal"
  assert_file_contains "$OUT" "Health Score" "the score bar renders on a terminal"
else
  _fail "script(1) not found — the TTY renderer cannot be exercised"
fi

test_start "tty_score_bar_is_green_when_the_environment_is_healthy"
if command -v script >/dev/null 2>&1; then
  new_home ttyfull
  mkdir -p "$SANDBOX_HOME/.local/share/chezmoi" "$SANDBOX_HOME/.local/share/zinit" \
    "$SANDBOX_HOME/.local/share/nvim/lazy" "$SANDBOX_HOME/.config/shell" \
    "$SANDBOX_HOME/.config/nvim" "$SANDBOX_HOME/.config/git" \
    "$SANDBOX_HOME/.config/chezmoi" "$SANDBOX_HOME/.ssh"
  touch "$SANDBOX_HOME/.config/chezmoi/key.txt"
  : >"$SANDBOX_HOME/.ssh/id_ed25519"
  chmod 600 "$SANDBOX_HOME/.ssh/id_ed25519"
  tty_health "$FULL_BIN"
  assert_file_contains "$WORK/tty.rc" "health-rc=0" "a healthy environment exits 0 on a terminal"
  assert_file_contains "$OUT" "Health Score" "the gum score bar renders"
else
  _fail "script(1) not found"
fi

test_start "tty_score_bar_is_red_when_the_environment_is_bare"
if command -v script >/dev/null 2>&1; then
  new_home ttybare
  # gum, but nothing else: the renderer takes its rich path while the score
  # lands in the lowest band.
  GUM_ONLY_BIN="$WORK/gum-only-bin"
  mkdir -p "$GUM_ONLY_BIN"
  for f in "$BASE_BIN"/*; do ln -sf "$f" "$GUM_ONLY_BIN/$(basename "$f")"; done
  ln -sf "$FULL_BIN/gum" "$GUM_ONLY_BIN/gum"
  tty_health "$GUM_ONLY_BIN"
  assert_file_contains "$OUT" "Needs attention" "a bare environment renders the low-score band"
else
  _fail "script(1) not found"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
